#!/usr/bin/env bash
#
# install-companions.sh — OPT-IN installer for harness-claude companion plugins.
#
# These are GLOBAL Claude Code plugins that cannot be shipped inside an isolated
# plugin. Run this ONLY when you are ready to wire them into your real setup.
# Nothing here touches your config until you run it. Re-running is safe.
#
# Usage:
#   ./install-companions.sh          # interactive: prints commands, asks to proceed
#   ./install-companions.sh --yes    # non-interactive: run all installs
#
set -euo pipefail

YES=0
[[ "${1:-}" == "--yes" ]] && YES=1

# marketplace => plugins to install from it
MARKETPLACES=(
  "claude-code-plugins"
  "claude-plugins-official"
  "Mixedbread-Grep"
)

PLUGINS=(
  # plugin@marketplace                        # purpose
  "ralph-wiggum@claude-code-plugins"          # loop automation
  "frontend-design@claude-code-plugins"       # UI/UX patterns
  "security-guidance@claude-code-plugins"     # security checks
  "feature-dev@claude-code-plugins"           # feature scaffolding
  "explanatory-output-style@claude-code-plugins" # explanatory style
  "code-review@claude-code-plugins"           # PR review
  "typescript-lsp@claude-plugins-official"    # TS intelligence
  "pyright-lsp@claude-plugins-official"       # Python types
  "code-simplifier@claude-plugins-official"   # simplification
  "context7@claude-plugins-official"          # live documentation
  "mgrep@Mixedbread-Grep"                     # better search than grep
)

echo "harness-claude — companion plugins"
echo "=================================="
echo
echo "Marketplaces to ensure are added:"
printf '  - %s\n' "${MARKETPLACES[@]}"
echo
echo "Plugins to install:"
printf '  - %s\n' "${PLUGINS[@]}"
echo
echo "NOTE: 'claude plugin install' may open an interactive picker. If a plugin is"
echo "already installed, the command is a no-op. mgrep/context7 you likely have."
echo

if [[ "$YES" -ne 1 ]]; then
  read -r -p "Proceed with installation? [y/N] " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || { echo "Aborted. No changes made."; exit 0; }
fi

for mp in "${MARKETPLACES[@]}"; do
  echo ">> Ensuring marketplace: $mp"
  claude plugin marketplace add "$mp" 2>/dev/null || echo "   (already added or add manually)"
done

for p in "${PLUGINS[@]}"; do
  echo ">> Installing plugin: $p"
  claude plugin install "$p" 2>/dev/null || echo "   (skipped — install manually via /plugin if needed)"
done

echo
echo "Done. Open Claude Code and run /plugin to verify, then enable what you want."
echo "Remember: keep <10 plugins/MCPs ENABLED at a time to protect your context window."
