#!/usr/bin/env bash
#
# check-reference-integrity.sh — guard against host-collision regressions.
#
# The harness loads into a flat, shared namespace alongside every other plugin and
# personal config. Bare references (`planner` agent, `/plan`) resolve to whatever the
# host happens to have, not to harness-claude's own components. This check fails if any
# skill/agent body invokes one of the harness's own agents or skills by a *bare* name
# instead of the namespaced `<plugin>:<name>` form.
#
# It keys the expected namespace off plugin.json, so a fork/rename auto-updates the
# expectation (no hardcoded "harness-claude" here).
#
# Exit 0 = clean. Exit 1 = bare references found (printed with file:line).

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Namespace = this plugin's name, read from the manifest (AC-5).
NS="$(node -e 'process.stdout.write(require("./.claude-plugin/plugin.json").name)')"

# The harness's own components — bare references to these must be namespaced.
# Note: the match patterns below wrap each name as `/<name>` or <name> + " agent",
# so a name that is a substring of another (e.g. `fix` within `build-fix`) does not
# mis-match — the surrounding backtick / token boundary anchors each alternative.
AGENTS='planner|architect|code-reviewer|security-reviewer|tdd-guide|build-error-resolver|refactor-cleaner|loop-operator'
SKILLS='spec|research|plan|architect|design|implement|build-fix|fix|review|security-review|design-review|test|verify|ship|refactor-clean|onboard|operate|orchestrate|harness|harness-plan|harness-implement|harness-verify|harness-maintain|save-session|resume-session|deploy|observe'

scan_dirs=(skills agents)
fail=0

# 1) Bare agent delegate targets:  `<agent>` ... agent   (not preceded by "<ns>:")
agent_hits="$(grep -rnE "\`(${AGENTS})\`[[:space:]]*(\*\*)?[[:space:]]*(agent|sub-?agent)" "${scan_dirs[@]}" \
  | grep -v "${NS}:" || true)"

# 2) Bare skill invocations:  `/​<skill>`   (backticked; descriptions use un-backticked
#    slashes as position hints and are intentionally exempt).
skill_hits="$(grep -rnE "\`/(${SKILLS})\`" "${scan_dirs[@]}" \
  | grep -v "${NS}:" || true)"

if [ -n "${agent_hits}" ]; then
  echo "✗ Bare agent references (should be ${NS}:<agent>):"
  echo "${agent_hits}"
  fail=1
fi

if [ -n "${skill_hits}" ]; then
  echo "✗ Bare skill invocations (should be /${NS}:<skill>):"
  echo "${skill_hits}"
  fail=1
fi

if [ "${fail}" -eq 0 ]; then
  echo "✓ reference integrity: all internal agent/skill references namespaced to '${NS}:'"
fi

exit "${fail}"
