#!/usr/bin/env bash
# Dependency-free tests for the extract-and-evaluate slice (Phase 2 / v0.5.0, AC-E4).
# Two units:
#   (1) extract-rubric.js — gate a proposed skill draft (PASS/FAIL/MANUAL, exit 0/1/2).
#   (2) stop-pattern-extraction.js — trace-driven n-gram candidate detection.
# Mirrors test-checkpoint.sh / test-trace.sh: drives the scripts as subprocesses with
# fixtures, checks output + exit codes. No network, no deps beyond Node + _lib.js.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RB="$ROOT/scripts/eval/extract-rubric.js"
HOOK="$ROOT/scripts/hooks/stop-pattern-extraction.js"

pass=0
fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# run extract-rubric.js from the repo root; capture combined output + exit into OUT/EC.
run() { OUT="$(cd "$ROOT" && node "$RB" "$@" 2>&1)"; EC=$?; }

echo "Phase 1 — extract-rubric.js gate (AC-X4, AC-X5)"

# A valid draft: frontmatter (name+description) + numbered steps, unique name.
# Deterministic checks PASS; 'reusable?' + benchmark seam stay MANUAL -> exit 2.
VALID="$TMP/valid-skill.md"
cat > "$VALID" <<'EOF'
---
name: tidy-imports
description: Sort and dedupe import statements across a changed module set.
---

# /tidy-imports

## Do this
1. Collect the changed files.
2. Sort imports and drop duplicates.
3. Write the result back.
EOF

run "$VALID"
if [ "$EC" = "2" ]; then ok "valid draft -> exit 2 (MANUAL remains; no auto-approve)"; else bad "valid draft -> exit 2 (got $EC)"; fi
if printf '%s' "$OUT" | grep -q 'R1.*PASS'; then ok "R1 frontmatter PASS"; else bad "R1 frontmatter PASS"; fi
if printf '%s' "$OUT" | grep -q 'R2.*PASS'; then ok "R2 steps PASS"; else bad "R2 steps PASS"; fi
if printf '%s' "$OUT" | grep -q 'R3.*PASS'; then ok "R3 uniqueness PASS"; else bad "R3 uniqueness PASS"; fi
if printf '%s' "$OUT" | grep -qE 'R4.*MANUAL'; then ok "R4 reusable -> MANUAL"; else bad "R4 reusable -> MANUAL"; fi
if printf '%s' "$OUT" | grep -qE 'R5.*MANUAL'; then ok "R5 benchmark seam inert -> MANUAL"; else bad "R5 benchmark seam inert -> MANUAL"; fi

# Missing frontmatter -> R1 FAIL -> exit 1.
NOFM="$TMP/no-frontmatter.md"
cat > "$NOFM" <<'EOF'
# /thing
## Do this
1. Step one.
2. Step two.
EOF
run "$NOFM"
if [ "$EC" = "1" ]; then ok "missing frontmatter -> exit 1"; else bad "missing frontmatter -> exit 1 (got $EC)"; fi
if printf '%s' "$OUT" | grep -q 'R1.*FAIL'; then ok "R1 reports FAIL on no frontmatter"; else bad "R1 reports FAIL on no frontmatter"; fi

# Frontmatter present but no numbered steps -> R2 FAIL -> exit 1.
NOSTEPS="$TMP/no-steps.md"
cat > "$NOSTEPS" <<'EOF'
---
name: vague-thing
description: A skill with no actionable steps at all.
---
# /vague-thing
Just some prose, no numbered procedure.
EOF
run "$NOSTEPS"
if [ "$EC" = "1" ]; then ok "no steps -> exit 1"; else bad "no steps -> exit 1 (got $EC)"; fi
if printf '%s' "$OUT" | grep -q 'R2.*FAIL'; then ok "R2 reports FAIL on no steps"; else bad "R2 reports FAIL on no steps"; fi

# Exact-name duplicate of an existing skill (skills/eval) -> R3 FAIL -> exit 1.
DUP="$TMP/dup.md"
cat > "$DUP" <<'EOF'
---
name: eval
description: A proposal that collides with the existing eval skill name.
---
# /eval
## Do this
1. Do something.
2. Do something else.
EOF
run "$DUP"
if [ "$EC" = "1" ]; then ok "duplicate name -> exit 1"; else bad "duplicate name -> exit 1 (got $EC)"; fi
if printf '%s' "$OUT" | grep -q 'R3.*FAIL'; then ok "R3 reports FAIL on duplicate name"; else bad "R3 reports FAIL on duplicate name"; fi

# Missing file -> graceful exit 2, no crash.
run "$TMP/does-not-exist.md"
if [ "$EC" = "2" ]; then ok "missing draft -> exit 2"; else bad "missing draft -> exit 2 (got $EC)"; fi

# --list inspects without evaluating: prints name + description, exit 0.
OUT="$(cd "$ROOT" && node "$RB" --list "$VALID" 2>&1)"; EC=$?
if [ "$EC" = "0" ]; then ok "--list exits 0"; else bad "--list exits 0 (got $EC)"; fi
if printf '%s' "$OUT" | grep -q 'tidy-imports'; then ok "--list shows parsed name"; else bad "--list shows parsed name"; fi

# No-arg: pick the latest staged proposal from .claude/skills-staging/<slug>/SKILL.md.
# Run inside an isolated git repo so stateDir resolves there. Two slugs -> latest wins.
NOARG="$TMP/noarg"; mkdir -p "$NOARG/.claude/skills-staging/aaa-old" "$NOARG/.claude/skills-staging/zzz-new"
( cd "$NOARG" && git init -q && git config user.email t@t && git config user.name t )
printf -- '---\nname: aaa-old\ndescription: older staged proposal.\n---\n# h\n## Do this\n1. a\n2. b\n' > "$NOARG/.claude/skills-staging/aaa-old/SKILL.md"
printf -- '---\nname: zzz-new\ndescription: newer staged proposal.\n---\n# h\n## Do this\n1. a\n2. b\n' > "$NOARG/.claude/skills-staging/zzz-new/SKILL.md"
OUT="$(cd "$NOARG" && node "$RB" --list 2>&1)"; EC=$?
if [ "$EC" = "0" ] && printf '%s' "$OUT" | grep -q 'zzz-new'; then ok "no-arg picks latest staged draft (zzz-new)"; else bad "no-arg picks latest staged draft (got $EC: $OUT)"; fi

# No-arg with no staged drafts -> graceful exit 2.
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
( cd "$EMPTY" && git init -q && git config user.email t@t && git config user.name t )
OUT="$(cd "$EMPTY" && node "$RB" 2>&1)"; EC=$?
if [ "$EC" = "2" ]; then ok "no-arg + no staged drafts -> exit 2"; else bad "no-arg + no drafts -> exit 2 (got $EC)"; fi

# Secret-safety: the rubric must NEVER shell-exec the draft's body. A draft carrying an
# ```eval fence that would print a secret must not have it run.
LEAKY="$TMP/leaky.md"
cat > "$LEAKY" <<'EOF'
---
name: leaky-proposal
description: Contains an eval fence that would leak a secret if executed.
---
# /leaky-proposal
## Do this
1. Step.
2. Step.
   ```eval
   echo sk-RUBRICSECRET123
   ```
EOF
run "$LEAKY"
if printf '%s' "$OUT" | grep -q 'RUBRICSECRET'; then bad "rubric must NOT execute draft body (secret leaked)"; else ok "rubric never executes draft body (no secret leak)"; fi

# Self-contained: syntax-valid and requires nothing beyond _lib.js.
if node -c "$RB" 2>/dev/null; then ok "extract-rubric.js syntax-valid (node -c)"; else bad "extract-rubric.js syntax-valid (node -c)"; fi
reqs="$(grep -oE "require\(['\"][^'\"]+['\"]\)" "$RB" | sort -u)"
if [ -n "$reqs" ] && ! printf '%s\n' "$reqs" | grep -qv "_lib"; then
  ok "extract-rubric.js only requires _lib.js"
else
  bad "extract-rubric.js requires something other than _lib.js: $reqs"
fi

echo "Phase 2 — stop-pattern-extraction.js trace-driven detection (AC-X1, AC-X2, AC-X6)"

# Build an isolated git repo so _lib.stateDir resolves to <repo>/.claude (not $HOME).
FAKE="$TMP/repo"
mkdir -p "$FAKE"
( cd "$FAKE" && git init -q && git config user.email t@t && git config user.name t )
mkdir -p "$FAKE/.claude/traces"
DATE="$(date +%F)"
TRACE="$FAKE/.claude/traces/$DATE.jsonl"
CANDS="$FAKE/.claude/skills-staging/candidates.md"

# A trace where the subsequence [skill:plan -> skill:implement] recurs twice.
cat > "$TRACE" <<'EOF'
{"ts":"t","tool_name":"Read","kind":"tool"}
{"ts":"t","tool_name":"plan","kind":"skill"}
{"ts":"t","tool_name":"implement","kind":"skill"}
{"ts":"t","tool_name":"Edit","kind":"tool"}
{"ts":"t","tool_name":"plan","kind":"skill"}
{"ts":"t","tool_name":"implement","kind":"skill"}
{"ts":"t","tool_name":"code-reviewer","kind":"subagent","subagent_type":"harness-claude:code-reviewer"}
EOF

# A transcript with >=40 tool_use entries (substantial session) + a planted secret that
# must NOT end up in the candidate (the hook only COUNTS the transcript, never copies it).
TRANSCRIPT="$FAKE/transcript.jsonl"
: > "$TRANSCRIPT"
i=0; while [ "$i" -lt 45 ]; do printf '{"type":"tool_use","name":"x"}\n' >> "$TRANSCRIPT"; i=$((i+1)); done
printf '{"type":"text","text":"sk-TRANSCRIPTSECRET999"}\n' >> "$TRANSCRIPT"

# Snapshot the live skills/ tree to prove AC-X2 (the hook never writes under skills/).
skills_digest() { ( cd "$ROOT" && find skills -type f | sort | xargs shasum | shasum | cut -d' ' -f1 ); }
BEFORE="$(skills_digest)"

stop_run() {  # $1=cwd $2=transcript ; capture EC
  printf '{"cwd":"%s","transcript_path":"%s"}' "$1" "$2" | node "$HOOK"; EC=$?;
}

stop_run "$FAKE" "$TRANSCRIPT"
if [ "$EC" = "0" ]; then ok "hook exits 0 (best-effort)"; else bad "hook exits 0 (got $EC)"; fi
if [ -f "$CANDS" ]; then ok "candidate written on substantial session + recurrence"; else bad "candidate written (file missing)"; fi
if grep -q 'plan' "$CANDS" 2>/dev/null && grep -q 'implement' "$CANDS" 2>/dev/null; then
  ok "candidate names the recurring sequence (plan, implement)"; else bad "candidate names the recurring sequence"; fi
if grep -q '/extract' "$CANDS" 2>/dev/null; then ok "candidate points at /extract"; else bad "candidate points at /extract"; fi
if grep -q 'TRANSCRIPTSECRET' "$CANDS" 2>/dev/null; then bad "candidate must NOT copy transcript content (secret leaked)"; else ok "candidate carries no transcript content (no secret leak)"; fi

AFTER="$(skills_digest)"
if [ "$BEFORE" = "$AFTER" ]; then ok "AC-X2: skills/ tree byte-identical after hook"; else bad "AC-X2: skills/ tree changed"; fi

# Below-threshold session (<40 tool calls) -> no candidate even with a recurring trace.
FAKE2="$TMP/repo2"; mkdir -p "$FAKE2/.claude/traces"
( cd "$FAKE2" && git init -q && git config user.email t@t && git config user.name t )
cp "$TRACE" "$FAKE2/.claude/traces/$DATE.jsonl"
SMALL="$FAKE2/transcript.jsonl"; : > "$SMALL"
i=0; while [ "$i" -lt 5 ]; do printf '{"type":"tool_use","name":"x"}\n' >> "$SMALL"; i=$((i+1)); done
stop_run "$FAKE2" "$SMALL"
if [ -f "$FAKE2/.claude/skills-staging/candidates.md" ]; then bad "below-threshold must not write a candidate"; else ok "below-threshold session writes no candidate"; fi

# Substantial session but NO trace -> no candidate.
FAKE3="$TMP/repo3"; mkdir -p "$FAKE3"
( cd "$FAKE3" && git init -q && git config user.email t@t && git config user.name t )
BIG="$FAKE3/transcript.jsonl"; : > "$BIG"
i=0; while [ "$i" -lt 45 ]; do printf '{"type":"tool_use","name":"x"}\n' >> "$BIG"; i=$((i+1)); done
stop_run "$FAKE3" "$BIG"
if [ -f "$FAKE3/.claude/skills-staging/candidates.md" ]; then bad "no-trace must not write a candidate"; else ok "no-trace session writes no candidate"; fi

# Substantial session + trace with NO recurrence -> no candidate.
FAKE4="$TMP/repo4"; mkdir -p "$FAKE4/.claude/traces"
( cd "$FAKE4" && git init -q && git config user.email t@t && git config user.name t )
cat > "$FAKE4/.claude/traces/$DATE.jsonl" <<'EOF'
{"ts":"t","tool_name":"plan","kind":"skill"}
{"ts":"t","tool_name":"implement","kind":"skill"}
{"ts":"t","tool_name":"verify","kind":"skill"}
EOF
BIG4="$FAKE4/transcript.jsonl"; : > "$BIG4"
i=0; while [ "$i" -lt 45 ]; do printf '{"type":"tool_use","name":"x"}\n' >> "$BIG4"; i=$((i+1)); done
stop_run "$FAKE4" "$BIG4"
if [ -f "$FAKE4/.claude/skills-staging/candidates.md" ]; then bad "no-recurrence must not write a candidate"; else ok "no-recurrence session writes no candidate"; fi

# Selection precedence: a LONGER sequence wins over a shorter, more-frequent one.
# tokens tidy,imports x3 -> the 2-gram [tidy imports] recurs 3x, but the 4-gram
# [tidy imports tidy imports] recurs 2x and must win (it contains "imports -> tidy",
# which the bare 2-gram candidate never would).
FAKE5="$TMP/repo5"; mkdir -p "$FAKE5/.claude/traces"
( cd "$FAKE5" && git init -q && git config user.email t@t && git config user.name t )
cat > "$FAKE5/.claude/traces/$DATE.jsonl" <<'EOF'
{"ts":"t","tool_name":"tidy","kind":"skill"}
{"ts":"t","tool_name":"imports","kind":"skill"}
{"ts":"t","tool_name":"tidy","kind":"skill"}
{"ts":"t","tool_name":"imports","kind":"skill"}
{"ts":"t","tool_name":"tidy","kind":"skill"}
{"ts":"t","tool_name":"imports","kind":"skill"}
EOF
BIG5="$FAKE5/transcript.jsonl"; : > "$BIG5"
i=0; while [ "$i" -lt 45 ]; do printf '{"type":"tool_use","name":"x"}\n' >> "$BIG5"; i=$((i+1)); done
stop_run "$FAKE5" "$BIG5"
C5="$FAKE5/.claude/skills-staging/candidates.md"
if grep -aq 'imports → tidy' "$C5" 2>/dev/null; then ok "longer sequence wins over more-frequent shorter one"; else bad "longer sequence wins over more-frequent shorter one"; fi

# Security: a SYMLINKED trace (planted to redirect the read outside the project) is
# rejected -> no candidate, even with a recurring sequence + substantial session.
FAKE6="$TMP/repo6"; mkdir -p "$FAKE6/.claude/traces"
( cd "$FAKE6" && git init -q && git config user.email t@t && git config user.name t )
OUTSIDE="$TMP/outside-trace.jsonl"
cat > "$OUTSIDE" <<'EOF'
{"ts":"t","tool_name":"plan","kind":"skill"}
{"ts":"t","tool_name":"implement","kind":"skill"}
{"ts":"t","tool_name":"plan","kind":"skill"}
{"ts":"t","tool_name":"implement","kind":"skill"}
EOF
ln -s "$OUTSIDE" "$FAKE6/.claude/traces/$DATE.jsonl"
BIG6="$FAKE6/transcript.jsonl"; : > "$BIG6"
i=0; while [ "$i" -lt 45 ]; do printf '{"type":"tool_use","name":"x"}\n' >> "$BIG6"; i=$((i+1)); done
stop_run "$FAKE6" "$BIG6"
if [ -f "$FAKE6/.claude/skills-staging/candidates.md" ]; then bad "symlinked trace must be rejected (no candidate)"; else ok "symlinked trace rejected (no candidate written)"; fi

# Self-contained: syntax-valid and requires nothing beyond _lib.js.
if node -c "$HOOK" 2>/dev/null; then ok "stop-pattern-extraction.js syntax-valid (node -c)"; else bad "stop-pattern-extraction.js syntax-valid (node -c)"; fi
hreqs="$(grep -aoE "require\(['\"][^'\"]+['\"]\)" "$HOOK" | sort -u)"
if [ -n "$hreqs" ] && ! printf '%s\n' "$hreqs" | grep -qv "_lib"; then
  ok "stop-pattern-extraction.js only requires _lib.js"
else
  bad "stop-pattern-extraction.js requires something other than _lib.js: $hreqs"
fi

echo
echo "extract tests: $pass passed, $fail failed"
[ "$fail" = "0" ]
