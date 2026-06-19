# harness-claude

A lean, **full-SDLC Claude Code harness** — personal, isolated, and testable. It runs a
four-phase pipeline (**Plan → Implement → Verify → Maintain**) backed by scoped
subagents, runtime hooks, and cross-session memory. Built to evolve toward eval loops,
retrieval, long-running agents, multi-agent orchestration, and computer-use (see
[ROADMAP.md](./ROADMAP.md)).

Stack focus: **TypeScript/JS (React, Next, Vercel)** and **Python**.

---

## Documentation

| Guide | Read it for |
|-------|-------------|
| [docs/USAGE.md](./docs/USAGE.md) | Install → full pipeline → reuse-an-existing-codebase → common scenarios |
| [docs/SKILLS.md](./docs/SKILLS.md) | Every command + agent, what each does, what it delegates to |
| [docs/HOOKS.md](./docs/HOOKS.md) | Exactly what runs on your machine, and how to disable any hook |
| [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) | Hooks not firing, slow `tsc`, MCP, git boundary — fixes |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | Adding skills/hooks, portability rules, PR checklist |
| [ROADMAP.md](./ROADMAP.md) | Where this is going (eval loops → retrieval → multi-agent → computer-use) |

**New here? Start with [docs/USAGE.md](./docs/USAGE.md).**

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
| Skills | `skills/<name>/SKILL.md` | 25 | 15 atomic `/spec … /ship` drivers + 5 phase orchestrators + 4 opt-in eval (`/eval` `/extract` `/benchmark` `/health`) + `/lazy` (generation reduction) |
| Agents | `agents/*.md` | 7 | scoped subagents the skills delegate to |
| Hooks | `hooks/hooks.json` + `scripts/hooks/` | — | tmux, format, typecheck, quality/design gates, strategic compact, build analysis, memory persistence, structural orientation, generation reduction |
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

## Prerequisites

| Requirement | Why | Without it |
|-------------|-----|------------|
| **Claude Code** ≥ 2.x | Host for the plugin | — |
| **Node.js** ≥ 18 | All runtime hooks are Node scripts | Hooks no-op; rest of the harness works |
| **git** | Phase gates, `/ship`, session snapshots | Most value is inside a repo |
| `bash` + `jq` *(optional)* | Status line only | Status line degrades gracefully |

Project tools (`prettier`, `eslint`, `tsc`, `ruff`, `pytest`) are **not** required — the
hooks that use them skip silently when absent. See [docs/HOOKS.md](./docs/HOOKS.md) for
exactly what runs on your machine.

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
Installs (if missing): ralph-loop, frontend-design, security-guidance, feature-dev,
explanatory-output-style, code-review, typescript-lsp, pyright-lsp, code-simplifier,
context7, mgrep. The script needs a **local clone** (it's a `.sh` file); for the no-clone
manual route and what each companion does, see [docs/USAGE.md](./docs/USAGE.md#7-installing-the-extras-companion-plugins--optional).
Keep **<10 plugins/MCPs enabled** at once to protect your context window.

### What's bundled vs. what's optional

The harness is **self-contained**: every skill and agent it ships references its own
components by their namespaced names (`harness-claude:planner`, `/harness-claude:plan`),
so they resolve deterministically no matter what else is installed in your `~/.claude`.
Companions are **enhancers, not requirements** — when one is absent the skills fall back
to built-in tools and say so.

| Item | Status | Fallback when absent |
|------|--------|----------------------|
| 7 agents (`harness-claude:*`) | **Bundled** | — (always present) |
| 25 skills (`/harness-claude:*`) | **Bundled** | — (always present) |
| 3 MCPs (memory · sequential-thinking · magic) | **Bundled**, load only when enabled | harness works without them |
| `mgrep` | Optional companion | `Grep` / `Glob` |
| `context7` | Optional companion | library's primary docs / web |
| knowledge graph | Optional companion | `Grep` / `Glob` |
| LSP / analyzer plugins (ts/pyright/knip/…) | Optional companion | hooks skip silently |

A reference-integrity check (`scripts/check-reference-integrity.sh`, run in CI) fails the
build if any skill/agent ever reintroduces a bare, collision-prone reference.

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

Phase 1 (subagents) and Phase 2 (eval loops) are complete. Phase 3 (cost & token
optimization) is in progress — generation reduction and structural orientation are
integrated; input-compression and a heavyweight code-graph were evaluated and killed on
evidence. Next: long-running agents → multi-agent orchestration → computer-use. See
[ROADMAP.md](./ROADMAP.md).

## License

MIT.
