# harness-claude

A lean, **full-SDLC Claude Code harness** — personal, isolated, and testable. It runs a
four-phase pipeline (**Plan → Implement → Verify → Maintain**) backed by scoped
subagents, runtime hooks, and cross-session memory. Built to evolve toward eval loops,
retrieval, long-running agents, multi-agent orchestration, and computer-use (see
[ROADMAP.md](./ROADMAP.md)).

Stack focus: **TypeScript/JS (React, Next, Vercel)** and **Python**.

---

## Why it's structured as a plugin

It lives in its own repo and installs as a Claude Code **plugin/marketplace**, so you can:

- **Test in isolation** — enable it via `/plugin`, run a real task, judge the result.
  Toggle it off to fall back. It never overwrites your existing `~/.claude`.
- **Promote when proven** — once it gives production-grade results, make it your default.
- **Share later** — a plugin repo is already the shareable format; push to GitHub.

---

## What's inside

| Layer | Where | Count | Role |
|-------|-------|-------|------|
| Rules | `rules/` | 7 | always-on guidance (cited by skills; imported by `CLAUDE.md`) |
| Skills | `skills/<name>/SKILL.md` | 20 | 15 atomic `/spec … /ship` drivers + 5 phase orchestrators |
| Agents | `agents/*.md` | 7 | scoped subagents the skills delegate to |
| Hooks | `hooks/hooks.json` + `scripts/hooks/` | — | tmux, format, typecheck, quality/design gates, strategic compact, build analysis, memory persistence |
| MCPs | `.mcp.json` | 3 | memory · sequential-thinking · magic (load only when enabled) |

### The pipeline

```
PLAN ─────────────► IMPLEMENT ─────► VERIFY ─────────────► MAINTAIN
/spec  /research          /implement     /review  /security-review   /refactor-clean
/plan  /architect         /build-fix     /test    /verify  /ship      /onboard
                  memory: /save-session · /resume-session (cross-cutting)
```

**Phase orchestrators** run a whole phase in one command — thin wrappers that sequence
the atomic skills, delegate to subagents, and pause for your input at each gate:

| Command | Runs |
|---------|------|
| `/harness-plan` | spec → research → plan → architect* |
| `/harness-implement` | implement (TDD) → build-fix |
| `/harness-verify` | review → security-review → test → verify → ship |
| `/harness-maintain` | onboard* → refactor-clean |
| `/harness` | the full pipeline, with a checkpoint between phases |

`*` conditional. Use the atomic skills (`/plan`, `/review`, …) when you only want one step.

---

## Install & test (isolated)

```bash
# 1) Add this repo as a marketplace — from GitHub, or via a local clone path
claude plugin marketplace add vasuag09/harness-claude        # straight from GitHub
# …or, if you've cloned it locally:
claude plugin marketplace add /path/to/harness-claude

# 2) In Claude Code, enable the plugin
/plugin            # find "harness-claude", enable it

# 3) Verify the pieces loaded
/plugin            # confirm skills/agents/hooks registered
/mcp               # confirm the 3 MCP servers (enable only what you need)
```

Then run a real task through the pipeline:

```
/spec    describe the feature you want
/research  /plan  /architect
/implement
/review  /security-review  /test  /verify  /ship
```

Toggle the plugin off in `/plugin` to return to your previous setup at any time.

---

## Opt-in extras (global — not auto-applied)

These can't live inside an isolated plugin, so they're shipped as configs you apply
when ready. Your real `~/.claude` stays untouched until you do.

### Companion plugins
```bash
./install-companions.sh          # prints the plan, asks before changing anything
./install-companions.sh --yes    # non-interactive
```
Installs (if missing): ralph-wiggum, frontend-design, security-guidance, feature-dev,
explanatory-output-style, code-review, typescript-lsp, pyright-lsp, code-simplifier,
context7, mgrep. Keep **<10 plugins/MCPs enabled** at once to protect your context window.

### Status line + output style + permissions
Merge the keys from [`settings.snippet.json`](./settings.snippet.json) into your
`~/.claude/settings.json` (adjust the absolute path). The status line shows:
`user dir ⎇branch✱ ctx:NN% model HH:MM ☑todos`.

### Make the rules global (opt-in)
The rules are active inside this repo via `CLAUDE.md` imports. To apply them on **other**
projects, add to your `~/.claude/CLAUDE.md`:
```
@/path/to/harness-claude/rules/workflow.md
@/path/to/harness-claude/rules/agents.md
@/path/to/harness-claude/rules/engineering.md
@/path/to/harness-claude/rules/security.md
@/path/to/harness-claude/rules/testing.md
```

---

## Memory persistence

- `/save-session` writes an evidence-based summary to `.claude/sessions/<date>.md`
  (project) or `~/.claude/harness-claude/sessions/` (outside a repo).
- `/resume-session` loads the latest and re-establishes context.
- Hooks back this up automatically: **SessionStart** surfaces the last session,
  **PreCompact** and **Stop** snapshot mechanical state so nothing is lost.

---

## Tuning the hooks

Hooks are non-blocking nudges/gates — they never fail a tool call. To disable one,
remove its block from `hooks/hooks.json` (match by `id`):

- `post:edit:tsc` — runs `tsc --noEmit` on `.ts/.tsx` edits. **Project-wide tsc can be
  slow**; disable this if your edit loop feels sluggish.
- `post:edit:prettier`, `post:edit:quality-gate` — need the project's local
  prettier/eslint/ruff; they skip silently if absent.
- `post:edit:design-quality` — heuristic frontend "template drift" warnings.
- `post:edit:strategic-compact` — suggests `/compact` ~every 50 edits.
- `pre:bash:tmux-reminder`, `pre:search:mgrep-nudge` — reminders only.

Requirements: **Node.js** (hook scripts) and, for the status line, `bash` + ideally `jq`.

---

## Roadmap

Phase 1 (subagents) is this release. Next: eval loops → retrieval → long-running agents
→ multi-agent orchestration → computer-use. See [ROADMAP.md](./ROADMAP.md).

## License

MIT.
