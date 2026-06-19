#!/usr/bin/env bash
# Dependency-free tests for the benchmark harness (Phase 2 / v0.6.0, AC-E3).
# Drives benchmark.js with INJECTED deterministic fake task commands (zero model cost) in a
# throwaway git repo, then asserts the pass@k / pass^k / verdict math, worktree isolation +
# cleanup, the result artifact, and the exit contract. Mirrors test-extract.sh.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BM="$ROOT/scripts/eval/benchmark.js"

pass=0
fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# An isolated git repo with one commit so `git worktree add ... HEAD` has a ref to fork.
REPO="$TMP/repo"
mkdir -p "$REPO"
( cd "$REPO" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'seed\n' > seed.txt && git add seed.txt && git commit -qm init )

# Fake task: passes ALWAYS when the component is enabled; when disabled, passes only on the
# first trial. -> with: k/k (pass^k); without: 1/k (pass@k but not pass^k).
TASK_TOGGLE="$TMP/task-toggle.sh"
cat > "$TASK_TOGGLE" <<'EOF'
#!/usr/bin/env bash
if [ "$HARNESS_COMPONENT_ENABLED" = "1" ]; then exit 0; fi
[ "$HARNESS_TRIAL" = "0" ] && exit 0 || exit 1
EOF
chmod +x "$TASK_TOGGLE"

run() { OUT="$(cd "$REPO" && node "$BM" "$@" 2>&1)"; EC=$?; }

echo "Phase 1 — pass@k / pass^k math + verdict (AC-B2, AC-B3, AC-B4)"

run --component plan --task "bash '$TASK_TOGGLE'" --k 3
if [ "$EC" = "0" ]; then ok "helpful component -> exit 0 (pass verdict)"; else bad "helpful component -> exit 0 (got $EC: $OUT)"; fi
if printf '%s' "$OUT" | grep -q 'with .*pass@k=true pass\^k=true'; then ok "with cohort: pass@k & pass^k true (3/3)"; else bad "with cohort pass^k true ($OUT)"; fi
if printf '%s' "$OUT" | grep -q 'without .*pass@k=true pass\^k=false'; then ok "without cohort: pass@k true, pass^k false (1/3)"; else bad "without cohort metrics ($OUT)"; fi
if printf '%s' "$OUT" | grep -q 'verdict: PASS'; then ok "verdict PASS reported"; else bad "verdict PASS reported ($OUT)"; fi

# Result artifact: written, valid JSON, carries both cohorts + pass=true.
ART="$REPO/.claude/eval/benchmarks/plan.json"
if [ -f "$ART" ]; then ok "artifact written to .claude/eval/benchmarks/<slug>.json"; else bad "artifact written (missing)"; fi
node -e '
  const a=require(process.argv[1]);
  const okShape = a.pass===true && a.with.passCaret===true && a.without.passCaret===false
    && a.with.successes===3 && a.without.successes===1 && a.k===3;
  process.exit(okShape?0:1);
' "$ART" 2>/dev/null && ok "artifact JSON shape correct (pass + cohorts + counts)" || bad "artifact JSON shape correct"

echo "Phase 2 — no-gain component, score command, exit contract"

# Task ignores the toggle, passes only on trial 0 -> both cohorts 1/k, equal rate, neither
# pass^k -> no reliability gain -> verdict FAIL -> exit 1.
TASK_FLAT="$TMP/task-flat.sh"
cat > "$TASK_FLAT" <<'EOF'
#!/usr/bin/env bash
[ "$HARNESS_TRIAL" = "0" ] && exit 0 || exit 1
EOF
chmod +x "$TASK_FLAT"
run --component noop --task "bash '$TASK_FLAT'" --k 3
if [ "$EC" = "1" ]; then ok "no-gain component -> exit 1 (fail verdict)"; else bad "no-gain -> exit 1 (got $EC: $OUT)"; fi
if printf '%s' "$OUT" | grep -q 'verdict: FAIL'; then ok "verdict FAIL on no gain"; else bad "verdict FAIL on no gain ($OUT)"; fi

# Separate score command drives pass/fail: task always exits 0, score honors the toggle.
TASK_OK="$TMP/task-ok.sh"; printf '#!/usr/bin/env bash\nexit 0\n' > "$TASK_OK"; chmod +x "$TASK_OK"
SCORE="$TMP/score.sh"
cat > "$SCORE" <<'EOF'
#!/usr/bin/env bash
[ "$HARNESS_COMPONENT_ENABLED" = "1" ] && exit 0 || exit 1
EOF
chmod +x "$SCORE"
run --component scored --task "bash '$TASK_OK'" --score "bash '$SCORE'" --k 2
if [ "$EC" = "0" ] && printf '%s' "$OUT" | grep -q 'with .*pass\^k=true' && printf '%s' "$OUT" | grep -q 'without .*pass@k=false'; then
  ok "score command governs pass/fail independent of task exit"
else
  bad "score command governs pass/fail (got $EC: $OUT)"
fi

echo "Phase 3 — worktree isolation + cleanup (AC-B1, AC-B6)"

# After a run, no benchmark worktrees may remain (only the main worktree).
WTN="$(cd "$REPO" && git worktree list --porcelain | grep -c '^worktree ')"
if [ "$WTN" = "1" ]; then ok "no leftover worktrees after run (git worktree list clean)"; else bad "leftover worktrees ($WTN)"; fi

# Cleanup must hold even when a trial's task FAILS hard (non-zero) on every trial.
TASK_FAIL="$TMP/task-fail.sh"; printf '#!/usr/bin/env bash\nexit 7\n' > "$TASK_FAIL"; chmod +x "$TASK_FAIL"
run --component alwaysfail --task "bash '$TASK_FAIL'" --k 2
WTN2="$(cd "$REPO" && git worktree list --porcelain | grep -c '^worktree ')"
if [ "$WTN2" = "1" ]; then ok "worktrees cleaned up even when every task fails"; else bad "worktrees cleaned on failure ($WTN2)"; fi
if [ "$EC" = "1" ]; then ok "all-fail run -> verdict FAIL exit 1"; else bad "all-fail -> exit 1 (got $EC)"; fi

# Trials are isolated: a task writing a file in its worktree must not leak into the repo or
# into sibling trials (each worktree is a fresh checkout of HEAD).
TASK_WRITE="$TMP/task-write.sh"
cat > "$TASK_WRITE" <<'EOF'
#!/usr/bin/env bash
# Fail if a sibling trial's marker is visible (it must not be); else drop our own marker.
[ -f trial-marker.txt ] && exit 1
echo "$HARNESS_TRIAL" > trial-marker.txt
exit 0
EOF
chmod +x "$TASK_WRITE"
run --component isolated --task "bash '$TASK_WRITE'" --k 3
if printf '%s' "$OUT" | grep -q 'with .*pass\^k=true'; then ok "each trial sees a clean worktree (no cross-trial leakage)"; else bad "trial isolation ($OUT)"; fi
if [ -f "$REPO/trial-marker.txt" ]; then bad "trial writes must not leak into the main repo"; else ok "trial writes stay in the worktree (repo untouched)"; fi

echo "Phase 4 — usage / setup errors (AC-B6) + self-contained"

# Missing --task -> usage error exit 2.
run --component x --k 2
if [ "$EC" = "2" ]; then ok "missing --task -> exit 2"; else bad "missing --task -> exit 2 (got $EC)"; fi

# Not a git repo -> exit 2 (no worktree to fork).
NOGIT="$TMP/nogit"; mkdir -p "$NOGIT"
OUT="$(cd "$NOGIT" && node "$BM" --component x --task 'true' --k 2 2>&1)"; EC=$?
if [ "$EC" = "2" ]; then ok "non-git dir -> exit 2"; else bad "non-git dir -> exit 2 (got $EC)"; fi

# Git boundary: the harness must never commit/push/branch the working tree.
if grep -aqE 'git (commit|push|branch|checkout -b)' "$BM"; then bad "benchmark.js must not run commit/push/branch"; else ok "no commit/push/branch in benchmark.js (git boundary)"; fi

# Self-contained: syntax-valid; only local _lib.js + node builtins.
if node -c "$BM" 2>/dev/null; then ok "benchmark.js syntax-valid (node -c)"; else bad "benchmark.js syntax-valid (node -c)"; fi
reqs="$(grep -aoE "require\(['\"][^'\"]+['\"]\)" "$BM" | sed -E "s/require\(['\"]([^'\"]+)['\"]\)/\1/" | sort -u)"
extra="$(printf '%s\n' "$reqs" | grep -vE '(_lib\.js|^child_process$|^os$)' || true)"
if [ -z "$extra" ]; then ok "benchmark.js requires only _lib.js + node builtins"; else bad "benchmark.js has unexpected require(s): $extra"; fi

echo "Phase 5 — cost capture + economics (v0.8, AC-V1/AC-V2)"

# A task that writes a cost sidecar (cost_usd + usage) to HARNESS_TRIAL_OUT, then passes.
# COST tunes the per-trial dollar figure; usage is fixed so token-summing is checkable.
TASK_COST="$TMP/task-cost.sh"
cat > "$TASK_COST" <<'EOF'
#!/usr/bin/env bash
[ -n "${HARNESS_TRIAL_OUT:-}" ] && printf '{"cost_usd":%s,"usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":10,"cache_creation_input_tokens":5}}\n' "${COST:-0.10}" > "$HARNESS_TRIAL_OUT"
exit 0
EOF
chmod +x "$TASK_COST"

# 1) cost captured -> totalCostUsd + costPerSuccess (2 trials @ $0.10, 2 successes -> total 0.20, cps 0.10).
COST=0.10 run --component costed --task "bash '$TASK_COST'" --k 2
node -e 'const c=require(process.argv[1]).with;process.exit(Math.abs(c.totalCostUsd-0.20)<1e-9&&Math.abs(c.costPerSuccess-0.10)<1e-9?0:1)' "$REPO/.claude/eval/benchmarks/costed.json" 2>/dev/null \
  && ok "cost sidecar captured -> totalCostUsd + cost-per-success" || bad "cost capture economics ($OUT)"

# 2) usage tokens summed across trials (2 × {in100,out50,cr10,cc5} -> in200,out100,cr20,cc10).
node -e 'const t=require(process.argv[1]).with.tokens;process.exit(t&&t.input===200&&t.output===100&&t.cacheRead===20&&t.cacheCreation===10?0:1)' "$REPO/.claude/eval/benchmarks/costed.json" 2>/dev/null \
  && ok "usage tokens summed per cohort (input/output/cacheRead/cacheCreation)" || bad "token summing"

# 3) no sidecar -> cost stays unknown (null), not a fake $0.
run --component nocost --task "bash '$TASK_OK'" --k 2
node -e 'const c=require(process.argv[1]).with;process.exit(c.totalCostUsd===null&&c.costPerSuccess===null&&c.tokens===null?0:1)' "$REPO/.claude/eval/benchmarks/nocost.json" 2>/dev/null \
  && ok "no sidecar -> cost null (unmeasured, not fake \$0)" || bad "missing-sidecar cost null"

# 4) partial coverage (sidecar on trial 0 only) -> refuse to partial-sum -> totalCostUsd null.
TASK_PARTIAL="$TMP/task-partial.sh"
cat > "$TASK_PARTIAL" <<'EOF'
#!/usr/bin/env bash
[ "$HARNESS_TRIAL" = "0" ] && [ -n "${HARNESS_TRIAL_OUT:-}" ] && printf '{"cost_usd":0.10,"usage":{"input_tokens":100,"output_tokens":50}}\n' > "$HARNESS_TRIAL_OUT"
exit 0
EOF
chmod +x "$TASK_PARTIAL"
run --component partial --task "bash '$TASK_PARTIAL'" --k 2
node -e 'const c=require(process.argv[1]).with;process.exit(c.totalCostUsd===null?0:1)' "$REPO/.claude/eval/benchmarks/partial.json" 2>/dev/null \
  && ok "any-trial-unmeasured -> totalCostUsd null (no misleading partial sum)" || bad "partial-sum refusal"

# 5) cost-per-success divides by SUCCESSES, not trials (cost every trial, pass trial 0 only).
TASK_COST_FLAKY="$TMP/task-cost-flaky.sh"
cat > "$TASK_COST_FLAKY" <<'EOF'
#!/usr/bin/env bash
[ -n "${HARNESS_TRIAL_OUT:-}" ] && printf '{"cost_usd":0.10,"usage":{"input_tokens":1,"output_tokens":1}}\n' > "$HARNESS_TRIAL_OUT"
[ "$HARNESS_TRIAL" = "0" ] && exit 0 || exit 1
EOF
chmod +x "$TASK_COST_FLAKY"
run --component cps --task "bash '$TASK_COST_FLAKY'" --k 2
node -e 'const c=require(process.argv[1]).with;process.exit(Math.abs(c.totalCostUsd-0.20)<1e-9&&c.successes===1&&Math.abs(c.costPerSuccess-0.20)<1e-9?0:1)' "$REPO/.claude/eval/benchmarks/cps.json" 2>/dev/null \
  && ok "cost-per-success = total / successes (counts paid-but-failed trials)" || bad "cost-per-success denominator"

echo
echo "benchmark tests: $pass passed, $fail failed"
[ "$fail" = "0" ]
