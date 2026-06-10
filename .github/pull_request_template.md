## What & why

Brief description of the change and the problem it solves.

## Type

- [ ] New skill / command
- [ ] New or changed hook
- [ ] Rule / agent change
- [ ] Docs
- [ ] Fix
- [ ] Other

## Portability checklist

- [ ] No hardcoded absolute paths (no `/Users/...`)
- [ ] No secrets, tokens, or personal data
- [ ] Hooks use `${CLAUDE_PLUGIN_ROOT}` and degrade gracefully if a tool is absent
- [ ] New commands/hooks documented in `docs/`
- [ ] Files under 800 lines

## Tested

How you verified this works (which Claude Code version, what you ran).
