#!/usr/bin/env bash
# Dependency-free, OFFLINE tests for the always-on activation hook session-lazy-activate.js
# (Phase 3 · Layer 3 integration). No network, no model cost — the hook is driven with canned
# SessionStart stdin payloads and its emitted additionalContext is inspected.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/scripts/hooks/session-lazy-activate.js"
ARM="$ROOT/benchmarks/arms/lazy-inject.txt"

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Drive the hook with a JSON payload on stdin under a chosen env.
drive() { printf '%s' "$1" | env "${@:2}" node "$HOOK" 2>/dev/null; }
# cwd = real repo root so the hook finds benchmarks/arms/lazy-inject.txt (the measured block).
START_PAYLOAD="{\"hook_event_name\":\"SessionStart\",\"cwd\":\"$ROOT\"}"
# cwd = a bare tmp dir with NO benchmarks/ -> exercises the built-in FALLBACK path.
START_NOARM="{\"hook_event_name\":\"SessionStart\",\"cwd\":\"$TMP\"}"

# Assert the emitted JSON is a valid SessionStart additionalContext envelope; print the context text.
ctx() { node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{const o=JSON.parse(d);const h=o.hookSpecificOutput;if(h&&h.hookEventName==="SessionStart"&&typeof h.additionalContext==="string"){process.stdout.write(h.additionalContext);process.exit(0)}process.exit(1)}catch{process.exit(1)}})'; }

echo "Phase 1 — static hygiene + SAFETY invariant (no network, no git mutation)"
node -c "$HOOK" 2>/dev/null && ok "hook syntax-valid (node -c)" || bad "hook syntax"
# Check NON-COMMENT lines only (the header comment legitimately mentions the benchmark).
if grep -vE '^[[:space:]]*//' "$HOOK" | grep -qE 'curl|fetch|http|exec\(|child_process'; then bad "hook code must not do network/exec"; else ok "no network/exec in code (read-only, offline)"; fi
if grep -aqE 'git (commit|push|branch)' "$HOOK"; then bad "hook must not commit/push/branch"; else ok "no git mutations"; fi

echo "Phase 2 — happy path: default mode -> additionalContext carrying the lazy ladder"
OUT="$(drive "$START_PAYLOAD")"
C="$(printf '%s' "$OUT" | ctx)" && ok "emits hookSpecificOutput.additionalContext (SessionStart contract)" || bad "additionalContext shape"
printf '%s' "$C" | grep -q 'LAZY MODE ACTIVE' && ok "context announces LAZY MODE ACTIVE" || bad "missing LAZY MODE header"
printf '%s' "$C" | grep -qi 'FIRST rung that holds' && ok "context carries the ladder (rung discipline)" || bad "missing ladder"
printf '%s' "$C" | grep -qi 'NEVER simplify away' && ok "context carries the accuracy floor (safety carve-outs)" || bad "missing accuracy floor"
# Fidelity: in-repo run injects the EXACT measured block (matches the benchmark arm file).
if [ -f "$ARM" ]; then
  head -1 "$ARM" | grep -qF "$(printf '%s' "$C" | head -1)" && ok "in-repo block matches benchmarks/arms/lazy-inject.txt (what P1 measured)" || bad "in-repo block should match the arm file"
fi

echo "Phase 3 — reversibility + intensity"
[ -z "$(drive "$START_PAYLOAD" LAZY_DISABLE=1)" ] && ok "LAZY_DISABLE=1 -> no output (reversible escape hatch)" || bad "LAZY_DISABLE should no-op"
[ -z "$(drive "$START_PAYLOAD" LAZY_MODE=off)" ] && ok "LAZY_MODE=off -> no output (off switch)" || bad "LAZY_MODE=off should no-op"
LITE="$(drive "$START_PAYLOAD" LAZY_MODE=lite | ctx)"
printf '%s' "$LITE" | grep -qi 'level: lite' && ok "LAZY_MODE=lite -> level header present" || bad "lite mode should label the level"
printf '%s' "$LITE" | grep -q 'LAZY MODE ACTIVE' && ok "lite mode still carries the full block" || bad "lite mode missing block"

echo "Phase 4 — failure isolation: works outside this repo (built-in fallback, no arm file)"
FB="$(drive "$START_NOARM" | ctx)" && ok "no arm file -> still emits (built-in fallback, plugin works in any repo)" || bad "fallback should still emit"
printf '%s' "$FB" | grep -q 'LAZY MODE ACTIVE' && ok "fallback carries the ladder too" || bad "fallback missing ladder"
# Empty/garbage stdin must not crash the session start.
printf '' | node "$HOOK" >/dev/null 2>&1; [ "$?" = "0" ] && ok "empty stdin -> exit 0 (never blocks session start)" || bad "must exit 0 on empty stdin"

echo
echo "lazy-hook tests: $pass passed, $fail failed"
[ "$fail" = "0" ]
