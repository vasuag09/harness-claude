#!/usr/bin/env bash
# Dependency-free tests for the checkpoint-eval slice (Phase 2 / v0.4.0).
# Drives checkpoint.js (parse + --list + run + PASS/FAIL/MANUAL gate) with markdown
# spec fixtures, checking output and exit codes. Mirrors test-trace.sh.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CP="$ROOT/scripts/eval/checkpoint.js"

pass=0
fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# run checkpoint.js; capture combined output + exit code into globals OUT / EC
run() { OUT="$(node "$CP" "$@" 2>&1)"; EC=$?; }

echo "Phase 1 — parser + --list (AC-1)"

# A spec with: passing check, failing check, manual (no fence), and an [x] manual.
MIXED="$TMP/mixed.md"
cat > "$MIXED" <<'EOF'
# Spec: fixture

## Acceptance criteria

- [ ] **AC-1 (passing):** a check that exits 0.
  ```eval
  exit 0
  ```
- [ ] **AC-2 (failing):** a check that exits non-zero and prints lots.
  ```eval
  for i in $(seq 1 30); do echo "L$i"; done
  exit 1
  ```
- [ ] **AC-3 (manual):** prose only, no fence — must be MANUAL.
- [x] **AC-4 (checked-manual):** author ticked it but there is still no fence.
EOF

run --list "$MIXED"
if [ "$EC" = "0" ]; then ok "--list exits 0"; else bad "--list exits 0 (got $EC)"; fi
for id in AC-1 AC-2 AC-3 AC-4; do
  if printf '%s' "$OUT" | grep -q "$id"; then ok "--list finds $id"; else bad "--list finds $id"; fi
done
if printf '%s' "$OUT" | grep -q 'AC-1.*CHECK'; then ok "AC-1 tagged CHECK"; else bad "AC-1 tagged CHECK"; fi
if printf '%s' "$OUT" | grep -q 'AC-3.*MANUAL'; then ok "AC-3 tagged MANUAL"; else bad "AC-3 tagged MANUAL"; fi
if printf '%s' "$OUT" | grep -q 'AC-2.*CHECK'; then ok "AC-2 tagged CHECK"; else bad "AC-2 tagged CHECK"; fi

# Parser edge cases (regression for review findings).
EDGE="$TMP/edge.md"
cat > "$EDGE" <<'EOF'
## Acceptance criteria
- [ ] **AC-1 (label (with nested parens)):** must still parse; check passes.
  ```eval
  true
  ```
- [ ] **AC-2 (unclosed):** fence never closes before EOF — must degrade to MANUAL.
  ```eval
  exit 1
- [x] **AC-3 (multi-fence):** later fence overrides earlier; last one passes.
  ```eval
  exit 1
  ```
  ```eval
  true
  ```
EOF
run --list "$EDGE"
if printf '%s' "$OUT" | grep -q 'AC-1.*CHECK'; then ok "nested-paren label parses as CHECK"; else bad "nested-paren label parses as CHECK"; fi
# AC-2's fence is unclosed -> AC-3's bullet line is consumed as fence content until EOF,
# so the parser yields AC-1 (CHECK) + AC-2 (unclosed -> MANUAL). AC-2 must be MANUAL.
if printf '%s' "$OUT" | grep -q 'AC-2.*MANUAL'; then ok "unclosed fence degrades AC-2 to MANUAL"; else bad "unclosed fence degrades AC-2 to MANUAL"; fi

# Multi-fence last-wins, isolated so the unclosed AC-2 above can't swallow it.
MULTI="$TMP/multi.md"
cat > "$MULTI" <<'EOF'
## Acceptance criteria
- [ ] **AC-1 (multi):** later fence overrides earlier; last one passes -> exit 0.
  ```eval
  exit 1
  ```
  ```eval
  true
  ```
EOF
run "$MULTI"
if [ "$EC" = "0" ]; then ok "multi-fence: last fence wins (exit 0)"; else bad "multi-fence: last fence wins (got $EC)"; fi

# Real-spec parse: v0.3 spec has AC-E1..AC-E5, all prose (MANUAL).
run --list "$ROOT/docs/specs/v0.3-eval-loops.md"
allE=1
for id in AC-E1 AC-E2 AC-E3 AC-E4 AC-E5; do
  printf '%s' "$OUT" | grep -q "$id" || allE=0
done
if [ "$allE" = "1" ]; then ok "--list finds AC-E1..AC-E5 in real v0.3 spec"; else bad "--list finds AC-E1..AC-E5 in real v0.3 spec"; fi

echo "Phase 2 — run + gate exit contract (AC-2, AC-3)"

# Mixed (has a FAIL) -> exit 1
run "$MIXED"
if [ "$EC" = "1" ]; then ok "mixed spec with a FAIL exits 1"; else bad "mixed spec with a FAIL exits 1 (got $EC)"; fi
if printf '%s' "$OUT" | grep -q 'AC-1.*PASS'; then ok "AC-1 reported PASS"; else bad "AC-1 reported PASS"; fi
if printf '%s' "$OUT" | grep -q 'AC-2.*FAIL'; then ok "AC-2 reported FAIL"; else bad "AC-2 reported FAIL"; fi
if printf '%s' "$OUT" | grep -q 'AC-3.*MANUAL'; then ok "AC-3 reported MANUAL"; else bad "AC-3 reported MANUAL"; fi

# All-pass spec -> exit 0
ALLPASS="$TMP/allpass.md"
cat > "$ALLPASS" <<'EOF'
## Acceptance criteria
- [ ] **AC-1 (ok):** exits 0.
  ```eval
  true
  ```
- [ ] **AC-2 (ok2):** also exits 0.
  ```eval
  exit 0
  ```
EOF
run "$ALLPASS"
if [ "$EC" = "0" ]; then ok "all-pass spec exits 0"; else bad "all-pass spec exits 0 (got $EC)"; fi

# Manual-only spec -> exit 2 (nothing failed, but unresolved)
MANUAL="$TMP/manual.md"
cat > "$MANUAL" <<'EOF'
## Acceptance criteria
- [ ] **AC-1 (prose):** no fence here.
- [ ] **AC-2 (prose):** none here either.
EOF
run "$MANUAL"
if [ "$EC" = "2" ]; then ok "manual-only spec exits 2"; else bad "manual-only spec exits 2 (got $EC)"; fi

echo "Phase 3 — CLI ergonomics (AC-3)"

# Missing file -> graceful exit 2, no crash
run "$TMP/does-not-exist.md"
if [ "$EC" = "2" ]; then ok "missing spec exits 2"; else bad "missing spec exits 2 (got $EC)"; fi

# No-arg picks latest docs/specs/*.md from cwd. Build an isolated fake repo.
FAKE="$TMP/repo"; mkdir -p "$FAKE/docs/specs"
cat > "$FAKE/docs/specs/v0.1-old.md" <<'EOF'
## Acceptance criteria
- [ ] **AC-1 (old):** should NOT be picked.
  ```eval
  exit 1
  ```
EOF
cat > "$FAKE/docs/specs/v0.9-new.md" <<'EOF'
## Acceptance criteria
- [ ] **AC-1 (new):** latest spec, passes.
  ```eval
  true
  ```
EOF
OUT="$(cd "$FAKE" && node "$CP" --list 2>&1)"; EC=$?
if printf '%s' "$OUT" | grep -q 'new'; then ok "no-arg picks latest spec (v0.9)"; else bad "no-arg picks latest spec (v0.9)"; fi

echo "Phase 4 — secret safety: a check's output is NEVER printed (AC-5)"

# A PASSING check that echoes a secret: output must NOT be shown.
SECRET="$TMP/secret.md"
cat > "$SECRET" <<'EOF'
## Acceptance criteria
- [ ] **AC-1 (leaky-pass):** prints a secret but exits 0.
  ```eval
  echo sk-SUPERSECRET123 && exit 0
  ```
EOF
run "$SECRET"
if printf '%s' "$OUT" | grep -q 'SUPERSECRET'; then bad "PASS check must not print output/secret"; else ok "PASS check hides output (no secret leak)"; fi

# A FAILING check whose OUTPUT contains a secret (the command text itself is secret-free,
# pulling it from the env) must STILL not surface it — output is never printed.
LEAKYFAIL="$TMP/leakyfail.md"
cat > "$LEAKYFAIL" <<'EOF'
## Acceptance criteria
- [ ] **AC-1 (leaky-fail):** prints $LEAKVAR to output then fails.
  ```eval
  printf '%s\n' "$LEAKVAR"; exit 1
  ```
EOF
export LEAKVAR=sk-SUPERSECRET123
run "$LEAKYFAIL"
unset LEAKVAR
if printf '%s' "$OUT" | grep -q 'SUPERSECRET'; then bad "FAIL check must NOT print output/secret"; else ok "FAIL check hides output (no secret leak)"; fi
if printf '%s' "$OUT" | grep -q 'exit 1'; then ok "FAIL shows exit code"; else bad "FAIL shows exit code"; fi
if printf '%s' "$OUT" | grep -q 're-run:'; then ok "FAIL shows re-run command"; else bad "FAIL shows re-run command"; fi

# The MIXED failing check prints L1..L30 to stdout: none of it may surface.
run "$MIXED"
if printf '%s' "$OUT" | grep -qE 'L[0-9]'; then bad "FAIL check output must not be printed (no L# lines)"; else ok "FAIL check output never printed"; fi

# Self-contained: syntax-valid and requires nothing beyond _lib.js.
if node -c "$CP" 2>/dev/null; then ok "checkpoint.js syntax-valid (node -c)"; else bad "checkpoint.js syntax-valid (node -c)"; fi
# Every require() target must be _lib.js — no other deps.
reqs="$(grep -oE "require\(['\"][^'\"]+['\"]\)" "$CP" | sort -u)"
if [ -n "$reqs" ] && ! printf '%s\n' "$reqs" | grep -qv "_lib"; then
  ok "checkpoint.js only requires _lib.js"
else
  bad "checkpoint.js requires something other than _lib.js: $reqs"
fi

echo
echo "checkpoint tests: $pass passed, $fail failed"
[ "$fail" = "0" ]
