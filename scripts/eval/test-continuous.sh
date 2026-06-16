#!/usr/bin/env bash
# Dependency-free tests for the continuous-eval runner (Phase 2 / v0.7.0, AC-E2).
# Drives continuous.js with INJECTED deterministic fake checks (zero model cost) in throwaway
# dirs, then asserts per-check results, auto-detect + --cmd override + --list, the secret-free
# artifact (capture-nothing invariant), the 0/1/2 exit contract, timeout-as-FAIL isolation, and
# self-containment. Mirrors test-benchmark.sh.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CE="$ROOT/scripts/eval/continuous.js"

pass=0
fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A clean git work tree per case so artifacts don't bleed between tests and stateDir() resolves
# to the repo's .claude (continuous eval is meant to run inside the target repo).
newrepo() {
  local d; d="$TMP/$1"; mkdir -p "$d"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t )
  printf '%s' "$d"
}
run() { OUT="$(cd "$1" && shift && node "$CE" "$@" 2>&1)"; EC=$?; }

echo "Phase 1 — per-check result + exit contract (AC-C1, AC-C4)"

R="$(newrepo c1)"
run "$R" --cmd 'true' --cmd 'true'
if [ "$EC" = "0" ]; then ok "all checks pass -> exit 0"; else bad "all-pass -> exit 0 (got $EC: $OUT)"; fi
if printf '%s' "$OUT" | grep -q 'GATE: PASS (2 of 2 passed)'; then ok "summary: 2 of 2 passed"; else bad "summary 2/2 ($OUT)"; fi

R="$(newrepo c1b)"
run "$R" --cmd 'true' --cmd 'false'
if [ "$EC" = "1" ]; then ok "any check fails -> exit 1"; else bad "any-fail -> exit 1 (got $EC: $OUT)"; fi
if printf '%s' "$OUT" | grep -q 'FAIL .*cmd2'; then ok "failing check marked FAIL"; else bad "FAIL line ($OUT)"; fi
if printf '%s' "$OUT" | grep -q '→ re-run: false'; then ok "re-run hint shows the command"; else bad "re-run hint ($OUT)"; fi

R="$(newrepo c1c)"
run "$R"
if [ "$EC" = "2" ]; then ok "nothing to run (no --cmd, no detectable checks) -> exit 2"; else bad "nothing-to-run -> exit 2 (got $EC: $OUT)"; fi

echo "Phase 2 — discovery: auto-detect + --cmd override + --list (AC-C2)"

# package.json with test+lint+typecheck scripts -> detected as npm run <name>.
R="$(newrepo c2)"
cat > "$R/package.json" <<'EOF'
{ "name": "x", "scripts": { "test": "true", "lint": "true", "typecheck": "true", "build": "true" } }
EOF
run "$R" --list
if [ "$EC" = "0" ]; then ok "--list with detected checks -> exit 0"; else bad "--list exit 0 (got $EC: $OUT)"; fi
if printf '%s' "$OUT" | grep -q 'test .*npm run test' \
   && printf '%s' "$OUT" | grep -q 'lint .*npm run lint' \
   && printf '%s' "$OUT" | grep -q 'typecheck .*npm run typecheck'; then
  ok "detects test/lint/typecheck from package.json scripts"
else bad "package.json detection ($OUT)"; fi
if printf '%s' "$OUT" | grep -q 'build'; then bad "must NOT detect non-standard scripts (build)"; else ok "ignores non-standard scripts (build)"; fi

# pnpm lockfile -> pnpm run.
R="$(newrepo c2pm)"
printf '{ "scripts": { "test": "true" } }\n' > "$R/package.json"
: > "$R/pnpm-lock.yaml"
run "$R" --list
if printf '%s' "$OUT" | grep -q 'pnpm run test'; then ok "pnpm lockfile -> pnpm run test"; else bad "pnpm detection ($OUT)"; fi

# Makefile fallback when no package.json.
R="$(newrepo c2mk)"
printf 'test:\n\ttrue\nlint:\n\ttrue\n' > "$R/Makefile"
run "$R" --list
if printf '%s' "$OUT" | grep -q 'make test' && printf '%s' "$OUT" | grep -q 'make lint'; then
  ok "Makefile fallback detects test/lint targets"
else bad "Makefile detection ($OUT)"; fi

# --cmd REPLACES the detected set.
R="$(newrepo c2ovr)"
printf '{ "scripts": { "test": "true" } }\n' > "$R/package.json"
run "$R" --list --cmd 'echo hi'
if printf '%s' "$OUT" | grep -q 'cmd1 .*echo hi' && ! printf '%s' "$OUT" | grep -q 'npm run test'; then
  ok "--cmd replaces (not merges) the detected set"
else bad "--cmd override ($OUT)"; fi

# --list runs nothing: a side-effecting --cmd must not execute.
R="$(newrepo c2noex)"
run "$R" --list --cmd "touch '$R/ran.marker'"
if [ -f "$R/ran.marker" ]; then bad "--list must not execute checks"; else ok "--list resolves only, runs nothing"; fi

# --list with no detectable checks -> exit 2.
R="$(newrepo c2empty)"
run "$R" --list
if [ "$EC" = "2" ]; then ok "--list with no checks -> exit 2"; else bad "--list empty -> exit 2 (got $EC)"; fi

echo "Phase 3 — secret-free artifact, capture-nothing (AC-C3, AC-C5)"

# A check prints a secret to its OUTPUT (not in the command text). It must NOT appear in the
# artifact — output is never captured. The command itself is secret-free.
R="$(newrepo c3)"
SECRET="sk-LIVE-DONOTLEAK-9z9z9z"
LEAK="$R/leak.sh"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$LEAKVAR"\nexit 1\n' > "$LEAK"
chmod +x "$LEAK"
OUT="$(cd "$R" && LEAKVAR="$SECRET" node "$CE" --cmd "bash '$LEAK'" 2>/dev/null)"; EC=$?
ART="$R/.claude/eval/continuous/latest.json"
if [ -f "$ART" ]; then ok "artifact written to .claude/eval/continuous/latest.json"; else bad "artifact written (missing)"; fi
if grep -q "$SECRET" "$ART" 2>/dev/null; then bad "SECRET leaked into artifact"; else ok "secret in check output is NOT captured in artifact"; fi
node -e '
  const a=require(process.argv[1]);
  const c=a.checks[0];
  const okShape = Array.isArray(a.checks) && c && typeof c.name==="string"
    && typeof c.command==="string" && c.pass===false && typeof c.durationMs==="number"
    && !("output" in c) && !("stdout" in c) && a.gate==="fail" && a.exit===1;
  process.exit(okShape?0:1);
' "$ART" 2>/dev/null && ok "artifact shape = name/command/pass/durationMs only (+gate/exit)" || bad "artifact JSON shape"

# A timestamped artifact is also written alongside latest.json.
TS_COUNT="$(ls "$R/.claude/eval/continuous"/*.json 2>/dev/null | grep -vc 'latest.json')"
if [ "$TS_COUNT" -ge 1 ]; then ok "timestamped artifact written alongside latest.json"; else bad "timestamped artifact ($TS_COUNT)"; fi

echo "Phase 4 — failure isolation + timeout (AC-C6)"

# A failing check must not abort the run: a later check still executes and is recorded.
R="$(newrepo c4)"
run "$R" --cmd 'false' --cmd 'true'
if printf '%s' "$OUT" | grep -q 'PASS .*cmd2'; then ok "a failing check does not abort later checks"; else bad "failure isolation ($OUT)"; fi
ART="$R/.claude/eval/continuous/latest.json"
node -e 'process.exit(require(process.argv[1]).checks.length===2?0:1)' "$ART" 2>/dev/null \
  && ok "both checks recorded despite the first failing" || bad "both checks recorded"

# Invalid --timeout-ms is rejected (exit 2), not silently defaulted.
R="$(newrepo c4bad)"
run "$R" --timeout-ms abc --cmd 'true'
if [ "$EC" = "2" ] && printf '%s' "$OUT" | grep -q 'positive integer'; then
  ok "invalid --timeout-ms -> exit 2 with clear error"
else bad "invalid --timeout-ms rejected (got $EC: $OUT)"; fi

# Timeout -> FAIL, run continues.
R="$(newrepo c4to)"
run "$R" --timeout-ms 200 --cmd 'sleep 5' --cmd 'true'
if [ "$EC" = "1" ]; then ok "timed-out check -> FAIL (exit 1)"; else bad "timeout -> exit 1 (got $EC: $OUT)"; fi
if printf '%s' "$OUT" | grep -q 'FAIL .*cmd1' && printf '%s' "$OUT" | grep -q 'PASS .*cmd2'; then
  ok "timeout is FAIL and the next check still runs"
else bad "timeout isolation ($OUT)"; fi

echo "Phase 5 — opt-in + self-contained (AC-C6, AC-C7)"

# AC-C7: no hook references continuous.js.
if grep -aq 'continuous.js' "$ROOT/hooks/hooks.json"; then bad "no hook may reference continuous.js"; else ok "opt-in: hooks.json does not invoke continuous.js"; fi

# Git boundary: never commit/push/branch.
if grep -aqE 'git (commit|push|branch|checkout -b)' "$CE"; then bad "continuous.js must not run commit/push/branch"; else ok "no commit/push/branch in continuous.js (git boundary)"; fi

# Self-contained: syntax-valid; only local _lib.js + node builtins.
if node -c "$CE" 2>/dev/null; then ok "continuous.js syntax-valid (node -c)"; else bad "continuous.js syntax-valid (node -c)"; fi
reqs="$(grep -aoE "require\(['\"][^'\"]+['\"]\)" "$CE" | sed -E "s/require\(['\"]([^'\"]+)['\"]\)/\1/" | sort -u)"
extra="$(printf '%s\n' "$reqs" | grep -vE '(_lib\.js|^child_process$)' || true)"
if [ -z "$extra" ]; then ok "continuous.js requires only _lib.js + node builtins"; else bad "unexpected require(s): $extra"; fi

echo
echo "continuous tests: $pass passed, $fail failed"
[ "$fail" = "0" ]
