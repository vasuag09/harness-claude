#!/usr/bin/env bash
# Dependency-free tests for the long-running-agent run-state + guardrails module (Phase 4 /
# v0.10.0, Phase 1). Drives guardrails.js (pure) and state.js (.claude/runs/<id>.json I/O) with
# INJECTED deterministic state objects (zero model cost) in throwaway git repos, then asserts:
#   - guardrail halts + haltReason for iteration-cap / budget / drift, and their priority (AC-1/2/3)
#   - state round-trips: iteration / budget-spent / consecutive-fails restored, not zeroed (AC-5)
#   - immutable merge; id sanitisation can't escape .claude/runs (trust boundary)
#   - summary shape: iterations / budget spent / last verdict / halt reason (AC-6)
#   - secret-free state (no output/stdout fields), git boundary, self-containment, opt-in (AC-7/8)
# Mirrors test-continuous.sh.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$ROOT/scripts/operate/guardrails.js"
STATE="$ROOT/scripts/operate/state.js"

pass=0
fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A clean git work tree per case so stateDir() resolves to the repo's .claude (a run is meant
# to live inside the target repo) and artifacts don't bleed between tests.
newrepo() {
  local d; d="$TMP/$1"; mkdir -p "$d"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t )
  printf '%s' "$d"
}

# Evaluate guardrails against a JS state literal; exit 0 iff {halt,reason} matches expected.
guard() { # $1 = state JSON literal, $2 = expected halt (true/false), $3 = expected reason (or "")
  node -e '
    const { evaluateGuardrails } = require(process.argv[1]);
    const state = JSON.parse(process.argv[2]);
    const want = { halt: process.argv[3] === "true", reason: process.argv[4] || null };
    const got = evaluateGuardrails(state);
    process.exit(got.halt === want.halt && got.reason === want.reason ? 0 : 1);
  ' "$GUARD" "$1" "$2" "$3"
}

echo "Phase 1 — guardrail halts + reason + priority (AC-1, AC-2, AC-3)"

if guard '{"iteration":3,"maxIterations":20,"consecutiveFails":0,"maxConsecutiveFails":2,"budget":{"maxWallClockMs":1000,"spentWallClockMs":100}}' false ""; then
  ok "under all caps -> no halt"; else bad "under-caps should not halt"; fi

if guard '{"iteration":20,"maxIterations":20,"consecutiveFails":0,"maxConsecutiveFails":2,"budget":{"maxWallClockMs":1000,"spentWallClockMs":0}}' true "iteration-cap"; then
  ok "iteration >= maxIterations -> halt iteration-cap (AC-1)"; else bad "iteration-cap halt (AC-1)"; fi

if guard '{"iteration":1,"maxIterations":20,"consecutiveFails":0,"maxConsecutiveFails":2,"budget":{"maxWallClockMs":1000,"spentWallClockMs":1000}}' true "budget"; then
  ok "wall-clock spent >= budget -> halt budget (AC-2)"; else bad "budget halt (AC-2)"; fi

if guard '{"iteration":1,"maxIterations":20,"consecutiveFails":2,"maxConsecutiveFails":2,"budget":{"maxWallClockMs":1000,"spentWallClockMs":0}}' true "drift"; then
  ok "consecutiveFails >= max -> halt drift (AC-3)"; else bad "drift halt (AC-3)"; fi

# One failure must NOT trip drift at N=2 (a single fail may be transient).
if guard '{"iteration":1,"maxIterations":20,"consecutiveFails":1,"maxConsecutiveFails":2,"budget":{"maxWallClockMs":1000,"spentWallClockMs":0}}' false ""; then
  ok "one fail (< N) does not halt"; else bad "single fail should not halt"; fi

# Priority: drift (safety) wins over a coincident iteration-cap.
if guard '{"iteration":20,"maxIterations":20,"consecutiveFails":2,"maxConsecutiveFails":2,"budget":{"maxWallClockMs":1000,"spentWallClockMs":0}}' true "drift"; then
  ok "drift outranks coincident iteration-cap (safety first)"; else bad "drift priority"; fi

# Optional caps absent (null) must never spuriously halt.
if guard '{"iteration":99,"maxIterations":null,"consecutiveFails":9,"maxConsecutiveFails":null,"budget":{"maxWallClockMs":null,"spentWallClockMs":99999}}' false ""; then
  ok "null caps are inert (no spurious halt)"; else bad "null caps must be inert"; fi

echo "Phase 2 — state round-trip + immutable merge + id sanitisation (AC-5, trust boundary)"

R="$(newrepo s1)"
node -e '
  const st = require(process.argv[1]);
  const cwd = process.argv[2];
  let s = st.defaultState("run-a", { objective: "x", maxIterations: 10, maxConsecutiveFails: 2, budget: { maxWallClockMs: 1000 } });
  s = st.mergeState(s, { iteration: 5, consecutiveFails: 1, lastVerdict: "fail", budget: { spentWallClockMs: 400 } });
  st.saveState(cwd, s);
  const back = st.loadState(cwd, "run-a");
  const okRound = back.iteration === 5 && back.consecutiveFails === 1
    && back.budget.spentWallClockMs === 400 && back.budget.maxWallClockMs === 1000
    && back.lastVerdict === "fail";
  process.exit(okRound ? 0 : 1);
' "$STATE" "$R" && ok "save->load restores iteration/fails/budget (not zeroed) (AC-5)" || bad "state round-trip (AC-5)"

node -e '
  const st = require(process.argv[1]);
  const a = st.defaultState("r", { objective: "x" });
  const before = a.iteration;
  const b = st.mergeState(a, { iteration: 9, budget: { spentWallClockMs: 7 } });
  // prev untouched; patch applied; nested budget merged not replaced
  const okImm = a.iteration === before && b.iteration === 9
    && a.budget.spentWallClockMs === 0 && b.budget.spentWallClockMs === 7;
  process.exit(okImm ? 0 : 1);
' "$STATE" && ok "mergeState is immutable + deep-merges budget" || bad "immutable merge"

node -e '
  const st = require(process.argv[1]);
  const path = require("path");
  const cwd = process.argv[2];
  const runsDir = path.join(cwd, ".claude", "runs");
  const p = st.runPath(cwd, "../../evil");
  // sanitised id must keep the file strictly inside .claude/runs AND carry no ".." in the name
  const base = path.basename(p);
  process.exit(p.startsWith(runsDir + path.sep) && !base.includes("..") ? 0 : 1);
' "$STATE" "$R" && ok "runPath sanitises id -> inside .claude/runs, no '..' in filename" || bad "id sanitisation"

echo "Phase 3 — summary shape (AC-6)"

node -e '
  const st = require(process.argv[1]);
  let s = st.defaultState("run-b", { objective: "x", maxIterations: 3 });
  s = st.mergeState(s, { iteration: 3, halted: true, haltReason: "iteration-cap", lastVerdict: "pass", budget: { spentWallClockMs: 1234 } });
  const sum = st.summarize(s);
  const okSum = sum.iterations === 3 && sum.haltReason === "iteration-cap"
    && sum.lastVerdict === "pass" && sum.budgetSpentMs === 1234 && sum.halted === true;
  // human line must mention the halt reason
  const line = st.formatSummary(s);
  process.exit(okSum && typeof line === "string" && line.includes("iteration-cap") ? 0 : 1);
' "$STATE" && ok "summarize + formatSummary report iterations/budget/verdict/reason (AC-6)" || bad "summary shape (AC-6)"

echo "Phase 4 — secret-free state + git boundary + self-contained + opt-in (AC-7, AC-8)"

# AC-8 secret-safety: the persisted state must carry only metrics/verdicts/reasons — never check output.
R="$(newrepo s4)"
node -e '
  const st = require(process.argv[1]);
  st.saveState(process.argv[2], st.defaultState("run-c", { objective: "x" }));
' "$STATE" "$R"
ART="$(ls "$R/.claude/runs"/*.json 2>/dev/null | head -1)"
if [ -n "$ART" ]; then ok "state written under .claude/runs/"; else bad "state file written"; fi
if grep -qE '"(output|stdout|stderr)"' "$ART" 2>/dev/null; then
  bad "state must NOT contain output/stdout/stderr fields"; else ok "state carries no captured output (secret-safe)"; fi

# id sanitisation belt-and-braces: a traversal id never lands a file outside .claude/runs.
node -e 'require(process.argv[1]).saveState(process.argv[2], require(process.argv[1]).defaultState("../../evil", {}))' "$STATE" "$R" 2>/dev/null || true
if [ -f "$TMP/evil.json" ] || [ -f "$R/../evil.json" ]; then bad "traversal id escaped .claude/runs"; else ok "traversal id cannot escape .claude/runs"; fi

# Git boundary: neither module runs commit/push/branch.
if grep -aqE 'git (commit|push|branch|checkout -b)' "$GUARD" "$STATE"; then
  bad "operate module must not run commit/push/branch"; else ok "no commit/push/branch (git boundary)"; fi

# Self-contained: syntax-valid; only local _lib.js + node builtins.
if node -c "$GUARD" 2>/dev/null && node -c "$STATE" 2>/dev/null; then ok "guardrails.js + state.js syntax-valid (node -c)"; else bad "syntax-valid (node -c)"; fi
reqs="$(grep -haoE "require\(['\"][^'\"]+['\"]\)" "$GUARD" "$STATE" | sed -E "s/require\(['\"]([^'\"]+)['\"]\)/\1/" | sort -u)"
extra="$(printf '%s\n' "$reqs" | grep -vE '(_lib\.js|^child_process$|^$)' || true)"
if [ -z "$extra" ]; then ok "modules require only _lib.js + node builtins"; else bad "unexpected require(s): $extra"; fi

# Opt-in (AC-7): no hook references the operate module.
if grep -aqE 'operate/(guardrails|state|step)\.js' "$ROOT/hooks/hooks.json" 2>/dev/null; then
  bad "no hook may invoke the operate module (opt-in)"; else ok "opt-in: hooks.json does not invoke operate (AC-7)"; fi

echo "Phase 5 — step runner ties state+guardrails to the reused eval skills (AC-4, AC-3+AC-5, AC-6)"

STEP="$ROOT/scripts/operate/step.js"
step() { local d="$1"; shift; OUT="$(cd "$d" && node "$STEP" "$@" 2>&1)"; EC=$?; }

# AC-4: a failing /health check drives a 'fail' verdict — proves step.js shells continuous.js and
# keys off its exit code (no detector of its own). One fail < N so the run continues (exit 0).
R="$(newrepo p5fail)"
step "$R" --id r --cmd false --max-fails 5
if [ "$EC" = "0" ]; then ok "fail verdict, under drift cap -> continue (exit 0)"; else bad "continue exit 0 (got $EC: $OUT)"; fi
if printf '%s' "$OUT" | grep -q 'GATE: FAIL'; then ok "step actually ran /health (continuous.js) (AC-4)"; else bad "ran continuous.js (AC-4) ($OUT)"; fi
node -e '
  const st=require(process.argv[1]); const s=st.loadState(process.argv[2],"r");
  process.exit(s.iteration===1 && s.consecutiveFails===1 && s.lastVerdict==="fail" ? 0 : 1);
' "$STATE" "$R" && ok "state after 1 fail: iteration=1 fails=1 verdict=fail" || bad "post-fail state"

# AC-3 + AC-5: two invocations (fresh processes) loading prior state — the second fail trips drift.
# Cross-firing source-of-truth proof: counts accumulate, not reset.
R="$(newrepo p5drift)"
step "$R" --id r --cmd false --max-fails 2
if [ "$EC" = "0" ]; then ok "drift run: first fail continues"; else bad "first fail continue (got $EC: $OUT)"; fi
step "$R" --id r --cmd false --max-fails 2
if [ "$EC" = "1" ] && printf '%s' "$OUT" | grep -q 'halt=drift'; then ok "second consecutive fail -> halt drift across firings (AC-3, AC-5)"; else bad "drift halt across firings (got $EC: $OUT)"; fi
node -e '
  const st=require(process.argv[1]); const s=st.loadState(process.argv[2],"r");
  process.exit(s.iteration===2 && s.consecutiveFails===2 && s.halted===true && s.haltReason==="drift" ? 0 : 1);
' "$STATE" "$R" && ok "persisted state accumulated across firings (iteration=2, fails=2, halted)" || bad "cross-firing accumulation"

# Already-halted is idempotent: another firing reports + exits 1 without running a checkpoint.
step "$R" --id r --cmd true --max-fails 2
if [ "$EC" = "1" ] && ! printf '%s' "$OUT" | grep -q 'GATE:'; then ok "halted run is idempotent (no new checkpoint)"; else bad "idempotent halt (got $EC: $OUT)"; fi

# AC-1 integration: iteration cap halts.
R="$(newrepo p5iter)"
step "$R" --id r --cmd true --max-iterations 1
if [ "$EC" = "1" ] && printf '%s' "$OUT" | grep -q 'halt=iteration-cap'; then ok "iteration cap halts via step (AC-1)"; else bad "iteration-cap halt (got $EC: $OUT)"; fi

# AC-2 integration: budget halts (budget-ms 0 -> any elapsed >= 0 trips on the first step).
R="$(newrepo p5bud)"
step "$R" --id r --cmd true --budget-ms 0
if [ "$EC" = "1" ] && printf '%s' "$OUT" | grep -q 'halt=budget'; then ok "wall-clock budget halts via step (AC-2)"; else bad "budget halt (got $EC: $OUT)"; fi

# 'none' verdict: /health finds nothing to run (exit 2) -> not a drift signal, run continues.
R="$(newrepo p5none)"
step "$R" --id r --max-iterations 5
if [ "$EC" = "0" ]; then ok "no checks (exit 2) -> none verdict, continue"; else bad "none-verdict continue (got $EC: $OUT)"; fi
node -e '
  const st=require(process.argv[1]); const s=st.loadState(process.argv[2],"r");
  process.exit(s.consecutiveFails===0 && s.lastVerdict==="none" ? 0 : 1);
' "$STATE" "$R" && ok "none verdict does not increment drift counter" || bad "none verdict counter"

# AC-4 (eval half): with --spec, step also runs /eval (checkpoint.js); a failing AC fence -> fail.
R="$(newrepo p5eval)"
mkdir -p "$R/docs/specs"
cat > "$R/docs/specs/x.md" <<'SPEC'
## Acceptance criteria
- [ ] **AC-1 (demo):** this check always fails.
  ```eval
  false
  ```
SPEC
step "$R" --id r --spec docs/specs/x.md --cmd true --max-fails 5
if printf '%s' "$OUT" | grep -q 'checkpoint:'; then ok "step ran /eval (checkpoint.js) when --spec given (AC-4)"; else bad "ran checkpoint.js (AC-4) ($OUT)"; fi
node -e '
  const st=require(process.argv[1]); const s=st.loadState(process.argv[2],"r");
  process.exit(s.lastVerdict==="fail" ? 0 : 1);
' "$STATE" "$R" && ok "failing /eval fence -> fail verdict (health passed, eval failed)" || bad "eval drives verdict"

# Usage: missing --id -> exit 2.
R="$(newrepo p5usage)"
step "$R" --cmd true
if [ "$EC" = "2" ]; then ok "missing --id -> exit 2 (usage)"; else bad "missing --id exit 2 (got $EC)"; fi

# Usage: --cmd as the last token (no value) -> exit 2 (fail fast, mirrors numeric flags).
R="$(newrepo p5cmdval)"
step "$R" --id r --cmd
if [ "$EC" = "2" ]; then ok "--cmd with no value -> exit 2 (fail fast)"; else bad "--cmd no-value exit 2 (got $EC: $OUT)"; fi

# AC-5 hardening: a present-but-corrupt state file must NOT silently restart from zero.
R="$(newrepo p5corrupt)"
step "$R" --id r --cmd true --max-iterations 5   # iteration 1 persisted
printf 'not json at all {{{' > "$R/.claude/runs/r.json"
step "$R" --id r --cmd true --max-iterations 5
if [ "$EC" = "2" ] && printf '%s' "$OUT" | grep -q 'corrupt'; then ok "corrupt state -> exit 2, refuses to restart (AC-5)"; else bad "corrupt-state refusal (got $EC: $OUT)"; fi
# A foreign-but-valid-JSON file (wrong shape) is also refused, not treated as a run.
printf '{"hello":"world"}' > "$R/.claude/runs/r.json"
step "$R" --id r --cmd true --max-iterations 5
if [ "$EC" = "2" ]; then ok "wrong-shape state file -> exit 2 (not a run-state)"; else bad "wrong-shape refusal (got $EC: $OUT)"; fi

# AC-4 structural: step.js shells the reused runners and adds no detector of its own.
if grep -q 'eval.*continuous.js' "$STEP" && grep -q "eval.*checkpoint.js" "$STEP"; then
  ok "step.js wires to continuous.js + checkpoint.js (reuse, AC-4)"; else bad "step.js reuse wiring (AC-4)"; fi

# step.js self-contained + git boundary + opt-in.
if node -c "$STEP" 2>/dev/null; then ok "step.js syntax-valid (node -c)"; else bad "step.js syntax-valid"; fi
if grep -aqE 'git (commit|push|branch|checkout -b)' "$STEP"; then bad "step.js must not run commit/push/branch"; else ok "step.js: no commit/push/branch (git boundary)"; fi

echo
echo "operate tests: $pass passed, $fail failed"
[ "$fail" = "0" ]
