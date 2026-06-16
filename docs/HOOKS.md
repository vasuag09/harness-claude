# Hooks — What Runs on Your Machine

Transparency matters for a tool you let run commands automatically. This page lists
**every** hook the plugin ships, what it does, what it needs, and how to turn it off.

## TL;DR

- Hooks activate **only while the plugin is enabled** in `/plugin`. Toggle it off → they stop.
- They are **not** written into your `~/.claude/settings.json`. They load from the plugin
  definition; removing the plugin removes them. Your personal config is never modified.
- Every hook is a **Node.js** script under `scripts/hooks/`, invoked via
  `${CLAUDE_PLUGIN_ROOT}` so paths work on any machine/username.
- Hooks are **non-blocking nudges and gates** — they print guidance; they do not fail your
  tool calls or modify code without going through the normal edit flow.
- The only hard dependency is **Node.js**. Hooks that call project tools (prettier, tsc,
  eslint, ruff) **skip silently** if those tools aren't installed.

You can read every script yourself in [`scripts/hooks/`](../scripts/hooks/) — they're short
and dependency-free.

---

## Every hook

| ID | Event | Trigger | What it does | Needs |
|----|-------|---------|--------------|-------|
| `pre:tool:trace` | PreToolUse | every tool call | Logs which skills/subagents/MCP tools fire to `.claude/traces/<date>.jsonl` (only `{ts, tool_name, kind, subagent_type?}` — never args/secrets) | — |
| `pre:bash:tmux-reminder` | PreToolUse | `Bash` | Reminds you to run long commands (npm/cargo/pytest/docker) inside tmux | — |
| `pre:search:mgrep-nudge` | PreToolUse | `Grep`, `Bash` | Nudges you toward `mgrep` instead of `grep`/`rg` | — |
| `post:edit:prettier` | PostToolUse | `Edit` | Auto-formats edited JS/TS files | Prettier in project (else skips) |
| `post:edit:tsc` | PostToolUse | `Edit` | Runs `tsc --noEmit` after `.ts/.tsx` edits | TypeScript in project (else skips) |
| `post:edit:quality-gate` | PostToolUse | `Edit`/`Write`/`MultiEdit` | Fast checks: lint, stray-debug scan, lightweight secret scan | eslint/ruff optional |
| `post:edit:design-quality` | PostToolUse | `Edit`/`Write`/`MultiEdit` | Warns when frontend edits drift toward generic template UI | — |
| `post:edit:strategic-compact` | PostToolUse | `Edit`/`Write`/`MultiEdit` | Suggests `/compact` at logical intervals (~every 50 edits) | — |
| `post:bash:build-analysis` | PostToolUse | `Bash` | Background, non-blocking analysis after build commands | — |
| `session-start:load-context` | SessionStart | session start | Surfaces the previous-session pointer; detects package manager | — |
| `pre-compact:save-state` | PreCompact | before compaction | Saves a state snapshot so context isn't lost | — |
| `stop:session-summary` | Stop | session end (tree changed) | Persists a session-end snapshot | git |
| `stop:pattern-extraction` | Stop | session end (substantial) | Reads the day's run-trace; stages a candidate note when a tool/skill sequence recurred (run `/extract` to act on it) | trace present |

---

## Performance note

`post:edit:tsc` runs a **project-wide** `tsc --noEmit` on every `.ts/.tsx` edit. On large
codebases this can make the edit loop feel sluggish. If so, disable just that hook (below).

---

## Disabling a hook

Hooks are defined in [`hooks/hooks.json`](../hooks/hooks.json). To disable one, remove its
block (match by `id`). Example — drop the slow tsc hook:

```jsonc
// delete this object from hooks.json → PostToolUse
{
  "matcher": "Edit",
  "hooks": [
    { "type": "command", "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/post-edit-tsc.js\"" }
  ],
  "description": "Run tsc --noEmit after editing .ts/.tsx files",
  "id": "post:edit:tsc"
}
```

To disable **all** hooks at once, just toggle the plugin off in `/plugin`.

---

## What hooks write to disk

Only the memory/session hooks write files, and only inside your project (or `~/.claude`
when outside a repo):

- `.claude/sessions/<date>.md` — session snapshots (`save-session`, Stop, PreCompact)
- `.claude/skills-staging/` — staged candidate patterns + `/extract` proposals (a draft
  `SKILL.md` + `eval.md` per `<slug>/`). Never auto-applied; promotion into `skills/` is
  always your explicit decision. Candidate notes carry only tool/skill names (from the
  trace), never session content.
- `.claude/traces/<date>.jsonl` — run-trace: one minimal line per tool call
  (`{ts, tool_name, kind, subagent_type?}`). No tool arguments, commands, or content are
  recorded, so secrets can't leak. Audit a run with
  `node scripts/eval/trace-report.js` (summary) or
  `node scripts/eval/trace-report.js --assert-namespace` (verify subagents are host-isolated).

All three paths are in `.gitignore` so they don't pollute your repo. No hook sends data off
your machine.
