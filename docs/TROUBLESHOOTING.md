# Troubleshooting & FAQ

Common friction points and how to fix them.

---

## Install & setup

### The plugin doesn't show up in `/plugin`

- Confirm the marketplace was added: re-run `claude plugin marketplace add vasuag09/harness-claude`.
- If you added a **local path**, make sure it points at the repo root (the dir containing
  `.claude-plugin/`), not a parent or subfolder.
- Restart Claude Code, then open `/plugin` again.

### Skills/commands aren't available after enabling

- In `/plugin`, confirm the plugin is **enabled** (not just installed).
- Some hosts need a restart for newly registered skills to appear. Reload and check again.

---

## Hooks

### Hooks don't seem to run

1. **Node.js missing or not on PATH** — every hook is `node "..."`. Run `node --version`.
   No Node → no hooks (the rest of the harness still works).
2. **Plugin disabled** — hooks only run while the plugin is enabled in `/plugin`.
3. **Tool-specific hooks** — e.g. the prettier/tsc hooks only fire on `.ts/.tsx` edits and
   skip silently if the project lacks those tools. That's expected, not a bug.

See [HOOKS.md](./HOOKS.md) for each hook's exact trigger and requirements.

### The edit loop feels slow

The `post:edit:tsc` hook runs project-wide `tsc --noEmit` on every TypeScript edit. On big
repos, disable it — see [HOOKS.md → Disabling a hook](./HOOKS.md#disabling-a-hook).

### A hook printed a warning — did it block my work?

No. Hooks are **non-blocking** nudges/gates. They print guidance; they never fail a tool
call or change code outside the normal edit flow.

---

## MCP servers

### `/mcp` shows servers that won't start

The three MCP servers (`memory`, `sequential-thinking`, `magic`) launch via `npx` and need
network access on first run to fetch the package. They're **optional** — enable only the
ones you need, and keep your total enabled plugins/MCPs under ~10 to protect your context
window.

---

## Git boundary

### Why didn't `/ship` commit or push?

By design. The harness **never** runs `git commit`/`push`/`branch` unless you explicitly
ask. `/ship` syncs docs and prepares a clean commit/PR summary, then stops. Run the git
command yourself, or tell Claude to.

---

## Status line

### The status line looks broken or shows nothing

- It's opt-in — you have to merge `settings.snippet.json` into your `~/.claude/settings.json`
  and fix the absolute path to `scripts/statusline.sh`.
- It needs `bash`; `jq` is recommended (it degrades without it but shows less).

---

## Phases & workflow

### Can I run `/harness` unattended end-to-end?

No. The orchestrators **pause at each phase gate** for your input (approve the plan, review
findings, etc.). That's intentional — the gates are where you steer.

### A skill says it can't proceed because a prior phase isn't done

Phases have exit criteria (spec before code, review + security + ≥80% coverage before ship).
Either complete the missing step, or for genuinely trivial changes, use the atomic skills
directly (`/implement`, `/review`) instead of the orchestrators.

---

## Rules

### How do I apply the rules to my *other* projects?

The rules are active inside this repo via `CLAUDE.md`. To apply them globally, add the
`@`-imports to your `~/.claude/CLAUDE.md` — see the
[README](../README.md#make-the-rules-global-opt-in).

---

## Still stuck?

Open an issue: https://github.com/vasuag09/harness-claude/issues — include your Claude Code
version (`claude --version`), Node version, OS, and the exact command/output.
