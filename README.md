# harness-claude

**Turn Claude Code into a disciplined engineering system — a full Plan → Implement → Verify → Maintain pipeline whose gates actually fire, and whose features had to beat a measured baseline or get killed.**

```
PLAN ─────────────► IMPLEMENT ─────► VERIFY ─────────────► MAINTAIN
/spec  /research          /implement     /review  /security-review   /refactor-clean
/plan  /architect         /build-fix     /test    /verify  /ship      /onboard
```

## Quick start

```bash
claude plugin marketplace add vasuag09/harness-claude
/plugin            # find "harness-claude", enable it
/harness           # run the full pipeline on a real task
```

Or start with a single gate: `/spec` a feature, `/fix` a bug, `/review` a diff.

**Not on Claude Code?** The 34 skills are standard `SKILL.md` files (YAML `name` +
`description` frontmatter) — install them into Cursor, Codex, Copilot, Gemini CLI, and
70+ other agents with the open [skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add vasuag09/harness-claude          # install skills into your agent
npx skills add vasuag09/harness-claude --list   # browse first
```

That gets you the **portable tier** — the workflow skills. The **enforcement tier**
(runtime hooks, scoped subagents, orchestrators, durable state) is Claude Code–native.

## Why this instead of a prompt pack

Most agent-workflow repos are markdown the agent *reads*. This is a system that *runs*:

- **Gates that fire** — format/typecheck/quality/design hooks run on every edit, and a
  routing hook re-anchors every prompt to the pipeline. Prompts suggest; hooks enforce.
- **Scoped subagents with model routing** — 8 agents on cheapest-sufficient models, three
  orchestration modes, parallel fan-out with a one-writer-per-file guarantee.
- **Work that survives sessions** — a durable `STATE.md` spine + per-phase planning
  artifacts, so a fresh context resumes from files, not chat scrollback.
- **Measured, not vibes** — every cost optimization had to beat a baseline on
  cost-per-successful-task at held pass^k, or die. Four experiments; two killed.
  [The receipts →](./docs/BENCHMARKS.md)
- **Past the repo edge** — `/deploy` (arm-to-fire) and `/observe` (prod signal → repro →
  `/fix`) close the pipeline into a loop.

Evaluating against **agent-skills**, **Superpowers**, or **Matt Pocock's skills**?
[Honest comparison →](./docs/COMPARISON.md)

Stack focus: **TypeScript/JS (React, Next, Vercel)** and **Python**. MIT-licensed,
plugin-installable, ~0-dependency hooks (plain Node).

---

## What got killed (and why that matters)

I built this privately to v0.8.0 before sharing it. The part I'm most proud of isn't a
feature — it's the gate behind them: **beat a bare baseline on cost-per-successful-task
at held consistency (pass^k), or get killed and documented.** Two of four didn't clear it —
an input-compression proxy (broke cache economics) and a popular ~51k★ code-graph MCP
(fixed context tax exceeded the whole task cost). What shipped: `/lazy` generation
reduction (**−35% output tokens, −23% LOC at held accuracy**, honest caveat: ~−3% dollars
on cache-dominated tasks) and a zero-tax structural-orientation hook.

Full method, raw trial numbers, and the retained kill apparatus:
**[docs/BENCHMARKS.md](./docs/BENCHMARKS.md)**.

---

## Documentation

| Guide | Read it for |
|-------|-------------|
| [docs/USAGE.md](./docs/USAGE.md) | Install → full pipeline → reuse-an-existing-codebase → common scenarios |
| [docs/SKILLS.md](./docs/SKILLS.md) | Every command + agent, what each does, what it delegates to |
| [docs/HOOKS.md](./docs/HOOKS.md) | Exactly what runs on your machine, and how to disable any hook |
| [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) | Hooks not firing, slow `tsc`, MCP, git boundary — fixes |
| [docs/COMPARISON.md](./docs/COMPARISON.md) | How this differs from agent-skills, Superpowers, Matt Pocock's skills |
| [docs/BENCHMARKS.md](./docs/BENCHMARKS.md) | The benchmark gate: what shipped, what got killed, raw numbers |
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
| Rules | `rules/` | 8 | always-on guidance incl. git conventions (cited by skills; imported by `CLAUDE.md`) |
| Skills | `skills/<name>/SKILL.md` | 34 | 19 atomic `/discover … /ship` drivers (incl. the `/discover` vague-intent discovery entry above `/spec`, the `/plan-check` adversarial plan gate between `/plan` and `/implement`, and the `/design` + `/design-review` design altitude) + 5 phase orchestrators + 4 opt-in eval (`/eval` `/extract` `/benchmark` `/health`) + `/lazy` (generation reduction) + `/operate` (guarded long-running runs) + `/orchestrate` (multi-agent parallel fan-out) + `/fix` (bug-fix fast lane) + `/deploy` + `/observe` (release & feedback loop) |
| Agents | `agents/*.md` | 8 | scoped subagents the skills delegate to |
| Hooks | `hooks/hooks.json` + `scripts/hooks/` | — | tmux, format, typecheck, quality/design gates, strategic compact, build analysis, memory persistence, structural orientation, generation reduction, pipeline routing |
| MCPs | `.mcp.json` | 3 | memory · sequential-thinking · magic (load only when enabled) |

### The pipeline

```
DISCOVER† ─► PLAN ───────────► IMPLEMENT ─────► VERIFY ─────────────────► MAINTAIN
/discover    /spec  /research        /implement     /review  /security-review    /refactor-clean
             /plan  /architect* /design*  /build-fix  /design-review*  /test       /onboard
                                                      /verify  /ship
                  memory: /save-session · /resume-session (cross-cutting)
```

`†` conditional **discovery entry** — `/discover` fires *above* `/spec` only when intent is vague
(you want *something* but can't yet state *what*); an already-clear request skips it.
`*` conditional **design gate** — `/architect` (system design) for load-bearing architecture;
`/design` + `/design-review` (product/UX) for user-facing surfaces. A change needs one, both, or neither.

**Phase orchestrators** run a whole phase in one command — thin wrappers that sequence
the atomic skills, delegate to subagents, and pause for your input at each gate:

| Command | Runs |
|---------|------|
| `/harness-plan` | spec → research → plan → architect* / design* |
| `/harness-implement` | implement (TDD) → build-fix |
| `/harness-verify` | review → security-review → design-review* → test → verify → ship |
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
| 8 agents (`harness-claude:*`) | **Bundled** | — (always present) |
| 34 skills (`/harness-claude:*`) | **Bundled** | — (always present) |
| design rubrics (`skills/design/references/`) | **Bundled** — self-contained, no external plugin | — (always present) |
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
@/path/to/harness-claude/rules/git.md
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

Phases 1–5 are complete: subagents, eval loops, benchmark-gated cost/token optimization
(generation reduction + structural orientation shipped; input-compression and a heavyweight
code-graph were evaluated and killed on evidence), guarded long-running agent runs
(`/operate` — a thin discipline layer over the platform's `/loop` + `/schedule`), and
multi-agent parallel fan-out (`/orchestrate` — a discipline layer over the platform Workflow
tool). Next: computer-use. See [ROADMAP.md](./ROADMAP.md).

## License

MIT.
