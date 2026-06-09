#!/usr/bin/env bash
#
# statusline.sh — custom Claude Code status line for harness-claude.
#
# Renders:  user  dir  ⎇ branch✱  ctx:NN%  model  HH:MM  ☑ todos
#
# Claude Code pipes a JSON object on stdin (model, cwd, transcript_path,
# session_id, ...). Everything here degrades gracefully: missing jq, missing
# fields, or non-git dirs never produce an error line.
#
set -uo pipefail

input="$(cat 2>/dev/null || true)"

# --- tiny JSON helper (jq if present, else python3, else empty) ---------------
json() { # $1 = jq filter
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c "import sys,json;
try:
    d=json.load(sys.stdin)
    p='$1'.lstrip('.').replace('.', \"','\")
    cur=d
    for k in [x for x in p.split(\"','\") if x]:
        cur=cur.get(k) if isinstance(cur,dict) else None
    print(cur if cur is not None else '')
except Exception:
    print('')" 2>/dev/null
  fi
}

CWD="$(json '.workspace.current_dir')";   [ -z "$CWD" ] && CWD="$(json '.cwd')";   [ -z "$CWD" ] && CWD="$PWD"
MODEL="$(json '.model.display_name')";     [ -z "$MODEL" ] && MODEL="Claude"
SESSION="$(json '.session_id')"
TRANSCRIPT="$(json '.transcript_path')"

DIR="$(basename "$CWD")"
USERNAME="${USER:-$(whoami 2>/dev/null)}"
NOW="$(date +%H:%M)"

# --- git branch + dirty flag --------------------------------------------------
GIT=""
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git -C "$CWD" branch --show-current 2>/dev/null)"
  [ -z "$BRANCH" ] && BRANCH="$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)"
  DIRTY=""
  [ -n "$(git -C "$CWD" status --porcelain 2>/dev/null)" ] && DIRTY="✱"
  [ -n "$BRANCH" ] && GIT="⎇ ${BRANCH}${DIRTY}"
fi

# --- context % used (estimated from last cumulative usage in transcript) ------
# Window default 200k; this harness runs on a 1M-context model, override via env.
CTX=""
CTX_WINDOW="${HARNESS_CTX_WINDOW:-200000}"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && command -v jq >/dev/null 2>&1; then
  USED="$(grep -o '"usage":{[^}]*}' "$TRANSCRIPT" 2>/dev/null | tail -1 \
    | jq -r '(.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.output_tokens // 0)' 2>/dev/null)"
  if [ -n "$USED" ] && [ "$USED" -gt 0 ] 2>/dev/null; then
    PCT=$(( USED * 100 / CTX_WINDOW ))
    [ "$PCT" -gt 100 ] && PCT=100
    CTX="ctx:${PCT}%"
  fi
fi

# --- todo count (from ~/.claude/todos/<session>*.json if present) -------------
TODOS=""
if [ -n "$SESSION" ]; then
  TODO_FILE="$(ls -1 "$HOME/.claude/todos/"*"$SESSION"*.json 2>/dev/null | head -1)"
  if [ -n "${TODO_FILE:-}" ] && [ -f "$TODO_FILE" ] && command -v jq >/dev/null 2>&1; then
    OPEN="$(jq '[.[] | select(.status != "completed")] | length' "$TODO_FILE" 2>/dev/null)"
    TOTAL="$(jq 'length' "$TODO_FILE" 2>/dev/null)"
    [ -n "$TOTAL" ] && [ "$TOTAL" -gt 0 ] 2>/dev/null && TODOS="☑ ${OPEN:-0}/${TOTAL}"
  fi
fi

# --- assemble -----------------------------------------------------------------
parts=("${USERNAME}:${DIR}")
[ -n "$GIT" ]   && parts+=("$GIT")
[ -n "$CTX" ]   && parts+=("$CTX")
parts+=("$MODEL" "$NOW")
[ -n "$TODOS" ] && parts+=("$TODOS")

printf '%s' "${parts[0]}"
for p in "${parts[@]:1}"; do printf '  %s' "$p"; done
