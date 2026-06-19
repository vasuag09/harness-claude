# harness-claude

A lean, full-SDLC Claude Code harness. The pipeline is **Plan → Implement → Verify →
Maintain**, with memory persistence cross-cutting and subagent orchestration underneath.

This file is the harness's own project context. The rules below are imported so they
are active when working inside this repo. To make them active **globally** (on your
other projects), see README → "Make the rules global (opt-in)".

## The pipeline

```
PLAN ─────────────► IMPLEMENT ─────► VERIFY ─────────────► MAINTAIN
/spec  /research          /implement     /review  /security-review   /refactor-clean
/plan  /architect         /build-fix     /test    /verify  /ship      /onboard
                  memory: /save-session · /resume-session (cross-cutting)
```

Move forward only when a phase's exit criteria are met (see rules/workflow.md).

**Phase orchestrators** run a whole phase in one command (thin wrappers that sequence the
atomic skills, delegate to subagents, and halt for your input at each gate):
`/harness-plan` · `/harness-implement` · `/harness-verify` · `/harness-maintain`, and
`/harness` for the full pipeline with a checkpoint between phases. Use atomic skills
(`/plan`, `/review`, ...) when you only want one step.

## What's here

- **rules/** — always-on guidance (engineering, security, testing, typescript, python, workflow, agents)
- **skills/** — the 15 pipeline drivers you invoke as `/spec`, `/plan`, `/review`, ...
  (plus four opt-in eval skills: `/eval` checkpoints a change against its spec's acceptance
  criteria, `/extract` turns a repeatable workflow into a staged skill proposal,
  `/benchmark` measures whether a component earns its keep via pass@k/pass^k, and `/health`
  takes the repo's test/lint pass-fail pulse on demand — all off by default), plus `/lazy`
  (Phase 3 · L3 generation reduction — the "build the minimum that works" reflex, active by
  default via a hook, intensity `lite|full|ultra`)
- **agents/** — 7 scoped subagents the skills delegate to
- **hooks/** + **scripts/hooks/** — runtime automations (tmux, format, typecheck, quality/design gates, strategic compact, build analysis, memory persistence, structural orientation, generation reduction)
- **.mcp.json** — memory · sequential-thinking · magic (load only when the plugin is enabled)

## Operating principles

- **Token optimization:** delegate to the cheapest sufficient model; subagents return
  summaries, not raw dumps. Benchmarking measures value; it is not the runtime strategy.
- **Orchestration:** sequential phases by default; iterative retrieval (≤3 cycles) when
  a subagent's return is insufficient. See rules/agents.md.
- **Modular & lean:** files <800 lines, immutable patterns, validated inputs.
- **Search with mgrep, not grep.** Run long commands in tmux. Use context7 for live docs.
- **Git boundary:** never commit/push/branch unless the user explicitly asks.

## Release docs sweep (this repo)

When `/ship`-ing a release here, reconcile these **before** committing (the `/ship` skill states
the general principle; these are the concrete files for this plugin):

- **README.md** — skill/agent counts and feature tables; the headline count must include any new
  skill. Reconcile to the actual `ls skills/` total, don't eyeball it.
- **`.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`** — bump `version`, and update
  the skill/agent count in the marketplace `description`.
- **ROADMAP.md** — phase status markers (🔄→✅), the per-version checklist line, and the "next"
  marker on the following phase.
- **CLAUDE.md** — skill lists / opt-in notes; **docs/HOOKS.md** — only if a hook changed.
- The shipped **spec** status, and the parent spec's acceptance-criteria checkboxes.

## Imported rules

@rules/workflow.md
@rules/agents.md
@rules/engineering.md
@rules/security.md
@rules/testing.md
@rules/typescript.md
@rules/python.md
