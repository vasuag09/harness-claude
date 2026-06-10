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

# Marketplace SOURCES. `claude plugin marketplace add` accepts a URL, a local
# path, or a GitHub `owner/repo` — NOT a bare alias. After adding, each marketplace
# is referenced by the alias its marketplace.json declares (shown in parentheses),
# which is what the `plugin@alias` entries below use.
MARKETPLACES=(
  "anthropics/claude-plugins-official"   # alias: claude-plugins-official
  "mixedbread-ai/mgrep"                  # alias: Mixedbread-Grep
)

PLUGINS=(
  # plugin@alias                                 # purpose
  "ralph-loop@claude-plugins-official"           # loop automation
  "frontend-design@claude-plugins-official"      # UI/UX patterns
  "security-guidance@claude-plugins-official"    # security checks
  "feature-dev@claude-plugins-official"          # feature scaffolding
  "explanatory-output-style@claude-plugins-official" # explanatory style
  "code-review@claude-plugins-official"          # PR review
  "typescript-lsp@claude-plugins-official"       # TS intelligence
  "pyright-lsp@claude-plugins-official"          # Python types
  "code-simplifier@claude-plugins-official"      # simplification
  "context7@claude-plugins-official"             # live documentation
  "mgrep@Mixedbread-Grep"                        # better search than grep
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

# Note: errors are shown (not swallowed) so a failure is visible instead of silent.
# "already added / already installed" is a normal, non-fatal outcome.
for mp in "${MARKETPLACES[@]}"; do
  echo ">> Ensuring marketplace: $mp"
  claude plugin marketplace add "$mp" || echo "   (already added, or add failed above — check the error)"
done

for p in "${PLUGINS[@]}"; do
  echo ">> Installing plugin: $p"
  claude plugin install "$p" || echo "   (already installed, or install failed above — check the error)"
done

echo
echo "Done. Open Claude Code and run /plugin to verify, then enable what you want."
echo "Remember: keep <10 plugins/MCPs ENABLED at a time to protect your context window."
