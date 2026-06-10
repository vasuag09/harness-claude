# Contributing to harness-claude

Thanks for your interest. This is a lean, opinionated Claude Code harness — contributions
that keep it lean and sharpen the pipeline are very welcome.

## Ground rules

- **Stay lean.** Many small, focused files beat few large ones. Target 200–400 lines per
  file; **800 is a hard ceiling**. One responsibility per module.
- **Match the existing voice.** Skills and rules are terse and imperative. Read a few
  existing `skills/*/SKILL.md` and `rules/*.md` before adding new ones.
- **Don't bloat the surface.** A new skill/agent/hook must earn its place. If an existing
  one can be extended, extend it.
- **Follow the harness's own rules.** The `rules/` in this repo apply to changes here too:
  immutability, explicit error handling, validated inputs, no hardcoded secrets/paths.

## Repo layout

| Dir | What lives here |
|-----|-----------------|
| `rules/` | Always-on guidance imported by `CLAUDE.md` |
| `skills/<name>/SKILL.md` | The slash-command drivers |
| `agents/*.md` | Scoped subagents the skills delegate to |
| `scripts/hooks/` | Node hook scripts (invoked via `${CLAUDE_PLUGIN_ROOT}`) |
| `hooks/hooks.json` | Hook wiring |
| `docs/` | User-facing documentation |

## Adding a skill

1. Create `skills/<name>/SKILL.md` with frontmatter (`name`, `description`). The
   description is what Claude uses to decide when to invoke it — make it specific.
2. State the phase it belongs to and which agent (if any) it delegates to.
3. Add it to [`docs/SKILLS.md`](./docs/SKILLS.md) and, if it's a phase orchestrator, to the
   README pipeline table.

## Adding or changing a hook

1. Hook scripts go in `scripts/hooks/`, are **Node.js**, and must be **non-blocking** (never
   fail a tool call) and **dependency-free** beyond Node's stdlib.
2. Reference them via `${CLAUDE_PLUGIN_ROOT}` in `hooks/hooks.json` — never hardcode paths.
3. Skip silently if a required project tool is absent.
4. Document the new hook in [`docs/HOOKS.md`](./docs/HOOKS.md) — users audit that table.

## Portability checklist

Before opening a PR:

- [ ] No hardcoded absolute paths (no `/Users/...`, no machine-specific paths)
- [ ] No secrets, tokens, or personal data
- [ ] Hooks use `${CLAUDE_PLUGIN_ROOT}` and degrade gracefully
- [ ] New commands/hooks documented in `docs/`
- [ ] Files under 800 lines

## Commit messages

Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.

## Reporting bugs / requesting features

Use the issue templates at
[github.com/vasuag09/harness-claude/issues](https://github.com/vasuag09/harness-claude/issues).
Include your Claude Code version, Node version, and OS.

## License

By contributing, you agree your contributions are licensed under the repo's [MIT License](./LICENSE).
