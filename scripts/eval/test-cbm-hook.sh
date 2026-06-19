#!/usr/bin/env bash
# Dependency-free, OFFLINE tests for the always-on orientation hook pre-search-cbm-orient.js
# (Phase 3 · Layer 2 integration). No network, no model cost, no real binary — a FAKE cbm responds to
# `cli index_status` / `cli search_graph`; the hook is driven with canned PreToolUse stdin payloads.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/scripts/hooks/pre-search-cbm-orient.js"

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ARGLOG="$TMP/cbm-args.log"

# Fake cbm: logs argv (to prove it NEVER runs `serve`), answers index_status ready + search_graph hits.
FAKECBM="$TMP/cbm"
cat > "$FAKECBM" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$ARGLOG"
if [ "\$1" = "cli" ] && [ "\$2" = "index_status" ]; then echo '{"project":"p","nodes":1477,"status":"ready"}'; exit 0; fi
if [ "\$1" = "cli" ] && [ "\$2" = "search_graph" ]; then echo '{"total":1,"results":[{"name":"stateDir","file_path":"scripts/hooks/_lib.js","signature":"(cwd, sub)","in_degree":9}]}'; exit 0; fi
exit 0
EOF
chmod +x "$FAKECBM"

# Drive the hook with a JSON payload on stdin. cwd = the real repo root so `git rev-parse` resolves.
drive() { printf '%s' "$1" | env "${@:2}" node "$HOOK" 2>/dev/null; }
GREP_PAYLOAD="{\"tool_name\":\"Grep\",\"tool_input\":{\"pattern\":\"stateDir\"},\"cwd\":\"$ROOT\"}"

echo "Phase 1 — static hygiene + SAFETY invariant (CLI-path only, never the MCP server)"
node -c "$HOOK" 2>/dev/null && ok "hook syntax-valid (node -c)" || bad "hook syntax"
# Check NON-COMMENT lines only — the safety comment legitimately names what the hook avoids.
if grep -vE '^[[:space:]]*//' "$HOOK" | grep -qE 'serve|--mcp|api\.github|initialize'; then bad "hook code must NOT invoke the MCP server / serve / github (CLI-path only)"; else ok "no serve/--mcp/github in code (CLI-path only — TRUST flag contained)"; fi
if grep -aqE 'git (commit|push|branch)' "$HOOK"; then bad "hook must not commit/push/branch"; else ok "no git mutations (read-only rev-parse only)"; fi

echo "Phase 2 — happy path: Grep + ready index + a matching symbol -> additionalContext"
OUT="$(drive "$GREP_PAYLOAD" CBM_BIN="$FAKECBM")"
printf '%s' "$OUT" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{const o=JSON.parse(d);process.exit(o.hookSpecificOutput&&o.hookSpecificOutput.hookEventName==="PreToolUse"&&typeof o.hookSpecificOutput.additionalContext==="string"?0:1)}catch{process.exit(1)}})' \
  && ok "emits hookSpecificOutput.additionalContext (PreToolUse contract)" || bad "additionalContext shape"
printf '%s' "$OUT" | grep -q 'stateDir' && printf '%s' "$OUT" | grep -q '_lib.js' && ok "additionalContext carries the structural hit (name + file)" || bad "hit content"
# SAFETY: the fake was only ever asked for `cli ...`, never `serve`.
grep -q 'serve' "$ARGLOG" 2>/dev/null && bad "hook invoked 'serve' (MCP server) — must be CLI-path only" || ok "hook only ran 'cli' subcommands (no MCP server spawned)"

echo "Phase 3 — graceful no-op (never block/slow a tool call)"
EDIT_PAYLOAD="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"x\"},\"cwd\":\"$ROOT\"}"
O_EDIT="$(drive "$EDIT_PAYLOAD" CBM_BIN="$FAKECBM")"
[ -z "$O_EDIT" ] && ok "non-Grep tool -> no output" || bad "non-Grep should no-op"
[ -z "$(drive "$GREP_PAYLOAD" CBM_BIN="$FAKECBM" CBM_DISABLE=1)" ] && ok "CBM_DISABLE=1 -> no output (reversible escape hatch)" || bad "CBM_DISABLE should no-op"
[ -z "$(drive "$GREP_PAYLOAD" CBM_BIN="$TMP/nonexistent")" ] && ok "missing binary -> no output (\$0, no install required)" || bad "missing-binary should no-op"

# index not ready: a fake whose index_status reports 0 nodes.
NOIDX="$TMP/cbm-noidx"; printf '#!/usr/bin/env bash\n[ "$2" = "index_status" ] && echo '\''{"nodes":0,"status":"indexing"}'\''\nexit 0\n' > "$NOIDX"; chmod +x "$NOIDX"
[ -z "$(drive "$GREP_PAYLOAD" CBM_BIN="$NOIDX")" ] && ok "index not ready -> no output (hook never indexes synchronously)" || bad "unindexed should no-op"

# empty search results -> no injection.
EMPTY="$TMP/cbm-empty"; printf '#!/usr/bin/env bash\n[ "$2" = "index_status" ] && echo '\''{"nodes":5}'\''\n[ "$2" = "search_graph" ] && echo '\''{"total":0,"results":[]}'\''\nexit 0\n' > "$EMPTY"; chmod +x "$EMPTY"
[ -z "$(drive "$GREP_PAYLOAD" CBM_BIN="$EMPTY")" ] && ok "no matching symbols -> no output (no empty hint)" || bad "empty results should no-op"

# failure isolation: a binary that errors must not break the call (exit 0, no output).
ERRBIN="$TMP/cbm-err"; printf '#!/usr/bin/env bash\nexit 3\n' > "$ERRBIN"; chmod +x "$ERRBIN"
drive "$GREP_PAYLOAD" CBM_BIN="$ERRBIN" >/dev/null 2>&1; [ "$?" = "0" ] && ok "binary error -> hook still exits 0 (failure-isolated)" || bad "hook must exit 0 on binary error"
NOPAT_PAYLOAD="{\"tool_name\":\"Grep\",\"tool_input\":{},\"cwd\":\"$ROOT\"}"
O_NOPAT="$(drive "$NOPAT_PAYLOAD" CBM_BIN="$FAKECBM")"
[ -z "$O_NOPAT" ] && ok "missing pattern -> no output" || bad "missing pattern should no-op"

echo
echo "cbm-hook tests: $pass passed, $fail failed"
[ "$fail" = "0" ]
