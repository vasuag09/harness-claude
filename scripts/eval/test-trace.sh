#!/usr/bin/env bash
# Dependency-free tests for the run-tracing slice (Phase 2 / v0.3.0).
# Drives pre-tool-trace.js (capture) and trace-report.js (summary + AC-6 assert)
# with fixtures, checking output and exit codes. Mirrors check-reference-integrity.sh.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/scripts/hooks/pre-tool-trace.js"
REPORT="$ROOT/scripts/eval/trace-report.js"

pass=0
fail=0
ok()   { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

# Isolated git repo so stateDir() writes to <tmp>/.claude/traces (not $HOME).
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
DATE="$(date -u +%F)"
TRACE="$TMP/.claude/traces/$DATE.jsonl"

# feed JSON on stdin to the hook with cwd set to the temp repo
feed() { printf '%s' "$1" | node "$HOOK" >/dev/null 2>&1; }

echo "Phase 1 — trace hook"

# 1. Task spawn -> one line, kind=subagent, carries subagent_type
feed '{"cwd":"'"$TMP"'","tool_name":"Task","tool_input":{"subagent_type":"harness-claude:planner"}}'
if [ -f "$TRACE" ] && [ "$(wc -l < "$TRACE" | tr -d ' ')" = "1" ]; then ok "Task writes exactly one line"; else bad "Task writes exactly one line"; fi
if grep -q '"kind":"subagent"' "$TRACE" && grep -q '"subagent_type":"harness-claude:planner"' "$TRACE"; then ok "subagent line has kind + subagent_type"; else bad "subagent line has kind + subagent_type"; fi

# 1b. REGRESSION: the spawn tool is named "Agent" in some runtimes (not "Task").
# Detection must key on subagent_type in the payload, not the tool name.
feed '{"cwd":"'"$TMP"'","tool_name":"Agent","tool_input":{"subagent_type":"harness-claude:code-reviewer","prompt":"x"}}'
if grep -q '"tool_name":"Agent","kind":"subagent","subagent_type":"harness-claude:code-reviewer"' "$TRACE"; then ok "Agent tool detected as subagent via payload"; else bad "Agent tool detected as subagent via payload"; fi

# 2. MCP tool -> kind=mcp
feed '{"cwd":"'"$TMP"'","tool_name":"mcp__memory__create_entities","tool_input":{"entities":[]}}'
if grep -q '"tool_name":"mcp__memory__create_entities","kind":"mcp"' "$TRACE"; then ok "mcp classified as mcp"; else bad "mcp classified as mcp"; fi

# 3. Builtin tool -> kind=tool, NO subagent_type field
feed '{"cwd":"'"$TMP"'","tool_name":"Bash","tool_input":{"command":"npm test"}}'
if grep -q '"tool_name":"Bash","kind":"tool"' "$TRACE"; then ok "Bash classified as tool"; else bad "Bash classified as tool"; fi

# 3b. Namespaced skill (":" in name) -> kind=skill
feed '{"cwd":"'"$TMP"'","tool_name":"harness-claude:plan","tool_input":{}}'
if grep -q '"tool_name":"harness-claude:plan","kind":"skill"' "$TRACE"; then ok "namespaced skill classified as skill"; else bad "namespaced skill classified as skill"; fi

# 4. No secret/arg capture: a command containing a secret must never reach the trace
feed '{"cwd":"'"$TMP"'","tool_name":"Bash","tool_input":{"command":"export API_KEY=sk-SUPERSECRET123"}}'
if grep -q 'SUPERSECRET' "$TRACE"; then bad "must NOT capture command/secret"; else ok "never captures command/secret"; fi

# 5. Empty / malformed stdin -> no crash, no spurious line
before="$(wc -l < "$TRACE" | tr -d ' ')"
printf '' | node "$HOOK" >/dev/null 2>&1; ec1=$?
printf 'not json' | node "$HOOK" >/dev/null 2>&1; ec2=$?
after="$(wc -l < "$TRACE" | tr -d ' ')"
if [ "$ec1" = "0" ] && [ "$ec2" = "0" ]; then ok "empty/garbage stdin exits 0"; else bad "empty/garbage stdin exits 0 (got $ec1/$ec2)"; fi
if [ "$before" = "$after" ]; then ok "no trace line for empty/garbage stdin"; else bad "no trace line for empty/garbage stdin"; fi

echo "Phase 2 — reader / asserter"

GOOD="$TMP/good.jsonl"
BADF="$TMP/bad.jsonl"
cat > "$GOOD" <<EOF
{"ts":"t","tool_name":"harness-claude:plan","kind":"skill"}
{"ts":"t","tool_name":"Task","kind":"subagent","subagent_type":"harness-claude:planner"}
{"ts":"t","tool_name":"mcp__memory__x","kind":"mcp"}
{"ts":"t","tool_name":"Bash","kind":"tool"}
EOF
cat > "$BADF" <<EOF
{"ts":"t","tool_name":"Task","kind":"subagent","subagent_type":"harness-claude:planner"}
{"ts":"t","tool_name":"Task","kind":"subagent","subagent_type":"planner"}
EOF

# 6. Summary prints and exits 0
out="$(node "$REPORT" "$GOOD" 2>&1)"; ec=$?
if [ "$ec" = "0" ] && printf '%s' "$out" | grep -qi 'subagent'; then ok "summary runs (exit 0, mentions subagent)"; else bad "summary runs (exit 0, mentions subagent)"; fi

# 7. --assert-namespace: all-good -> exit 0
node "$REPORT" --assert-namespace "$GOOD" >/dev/null 2>&1
if [ "$?" = "0" ]; then ok "assert passes on namespaced trace"; else bad "assert passes on namespaced trace"; fi

# 8. --assert-namespace: a bare subagent_type -> exit 1, names the offender
out="$(node "$REPORT" --assert-namespace "$BADF" 2>&1)"; ec=$?
if [ "$ec" = "1" ]; then ok "assert fails (exit 1) on bare subagent_type"; else bad "assert fails (exit 1) on bare subagent_type (got $ec)"; fi
if printf '%s' "$out" | grep -q 'planner'; then ok "assert names the offending agent"; else bad "assert names the offending agent"; fi

# 9. Summary actually lists skill and mcp names (not just counts) — AC-3
out="$(node "$REPORT" "$GOOD" 2>&1)"
if printf '%s' "$out" | grep -q 'harness-claude:plan' && printf '%s' "$out" | grep -q 'mcp__memory__x'; then ok "summary lists skill + mcp names"; else bad "summary lists skill + mcp names"; fi

# 10. --assert-namespace on a trace with no subagents -> exit 2 (nothing to verify)
NOSUB="$TMP/nosub.jsonl"
printf '%s\n' '{"ts":"t","tool_name":"Bash","kind":"tool"}' > "$NOSUB"
node "$REPORT" --assert-namespace "$NOSUB" >/dev/null 2>&1
if [ "$?" = "2" ]; then ok "assert exits 2 when no subagents to verify"; else bad "assert exits 2 when no subagents to verify"; fi

# 11. Missing file: summary exits 0, assert exits 2
node "$REPORT" "$TMP/does-not-exist.jsonl" >/dev/null 2>&1; s_ec=$?
node "$REPORT" --assert-namespace "$TMP/does-not-exist.jsonl" >/dev/null 2>&1; a_ec=$?
if [ "$s_ec" = "0" ] && [ "$a_ec" = "2" ]; then ok "missing file: summary=0, assert=2"; else bad "missing file: summary=0 assert=2 (got $s_ec/$a_ec)"; fi

# 12. No-arg default resolves the latest trace in <cwd>/.claude/traces (AC-3 default path)
out="$(cd "$TMP" && node "$REPORT" 2>&1)"; ec=$?
if [ "$ec" = "0" ] && printf '%s' "$out" | grep -qi 'tool calls'; then ok "no-arg uses latest .claude/traces file"; else bad "no-arg uses latest .claude/traces file (got $ec)"; fi

echo
echo "passed: $pass   failed: $fail"
[ "$fail" = "0" ]
