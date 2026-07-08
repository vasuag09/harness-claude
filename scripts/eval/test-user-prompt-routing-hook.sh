#!/usr/bin/env bash
# Dependency-free, OFFLINE tests for the UserPromptSubmit routing hook
# user-prompt-routing.js (+ the session-start routing line). No network, no model cost —
# the hook is driven with canned stdin payloads and its stdout is inspected.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/scripts/hooks/user-prompt-routing.js"
SESSION="$ROOT/scripts/hooks/session-start.js"

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

# Drive the hook with a JSON payload on stdin under a chosen env.
drive() { printf '%s' "$1" | env "${@:2}" node "$HOOK" 2>/dev/null; }

echo "Phase 0 — every hook script is syntax-valid (node -c)"
for f in "$ROOT"/scripts/hooks/*.js; do
  node -c "$f" >/dev/null 2>&1 && ok "node -c $(basename "$f")" || bad "node -c $(basename "$f")"
done

echo "Phase 1 — static hygiene (no network/exec/git mutation in the new hook)"
if grep -vE '^[[:space:]]*//' "$HOOK" | grep -qE 'curl|fetch|http|exec\(|child_process'; then
  bad "hook code must not do network/exec"
else ok "no network/exec in code (offline)"; fi
if grep -aqE 'git (commit|push|branch|checkout)' "$HOOK"; then bad "hook must not mutate git"; else ok "no git mutations"; fi

echo "Phase 2 — happy path: non-slash prompt -> routing line"
OUT="$(drive '{"hook_event_name":"UserPromptSubmit","prompt":"please fix the login bug"}')"
printf '%s' "$OUT" | grep -q 'Route the request' && ok "emits the routing instruction" || bad "missing routing instruction"
printf '%s' "$OUT" | grep -q '/fix' && ok "routing names /fix" || bad "routing should name /fix"
printf '%s' "$OUT" | grep -q '/spec' && ok "routing names /spec" || bad "routing should name /spec"
LINES=$(printf '%s' "$OUT" | grep -c . || true)
[ "$LINES" -le 2 ] && ok "output is <=2 lines (per-prompt cost cap)" || bad "output too long ($LINES lines)"

echo "Phase 3 — no-ops: slash prompt, empty prompt, disable flag"
[ -z "$(drive '{"hook_event_name":"UserPromptSubmit","prompt":"/spec build a feature"}')" ] \
  && ok "slash prompt -> no output (skill already chosen)" || bad "slash prompt should no-op"
[ -z "$(drive '{"hook_event_name":"UserPromptSubmit","prompt":"  /fix thing"}')" ] \
  && ok "whitespace-then-slash -> no output" || bad "trimmed slash prompt should no-op"
[ -z "$(drive '{"hook_event_name":"UserPromptSubmit","prompt":""}')" ] \
  && ok "empty prompt -> no output" || bad "empty prompt should no-op"
[ -z "$(drive '{"hook_event_name":"UserPromptSubmit"}')" ] \
  && ok "missing prompt field -> no output" || bad "missing prompt should no-op"
[ -z "$(drive '{"hook_event_name":"UserPromptSubmit","prompt":"fix stuff"}' ROUTING_DISABLE=1)" ] \
  && ok "ROUTING_DISABLE=1 -> no output (reversible escape hatch)" || bad "ROUTING_DISABLE should no-op"

echo "Phase 4 — failure isolation: never blocks a prompt"
printf 'not json at all' | node "$HOOK" >/dev/null 2>&1; [ "$?" = "0" ] && ok "malformed JSON -> exit 0" || bad "must exit 0 on malformed JSON"
printf '' | node "$HOOK" >/dev/null 2>&1; [ "$?" = "0" ] && ok "empty stdin -> exit 0" || bad "must exit 0 on empty stdin"

echo "Phase 5 — session-start carries the routing instruction too (AC-4)"
SOUT="$(printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$ROOT" | node "$SESSION" 2>/dev/null)"
printf '%s' "$SOUT" | grep -q 'Route the request' && ok "session-start emits the routing instruction" || bad "session-start missing routing instruction"
printf '%s' "$SOUT" | grep -q 'pipeline order' && ok "session-start keeps the pipeline order line" || bad "session-start missing pipeline order"

echo
echo "user-prompt-routing tests: $pass passed, $fail failed"
[ "$fail" = "0" ]
