# harness-claude

A lean, full-SDLC Claude Code harness. The pipeline is **Plan → Implement → Verify →
Maintain**, with memory persistence cross-cutting and subagent orchestration underneath.

This file is the harness's own project context. The rules below are imported so they
are active when working inside this repo. To make them active **globally** (on your
other projects), see README → "Make the rules global (opt-in)".

## The pipeline

```
DISCOVER† ─► PLAN ───────────► IMPLEMENT ─────► VERIFY ─────────────────► MAINTAIN
/discover    /spec  /research        /implement     /review  /security-review    /refactor-clean
             /plan  /architect* /design*  /build-fix  /design-review*  /test       /onboard
                                                      /verify  /ship
                  memory: /save-session · /resume-session (cross-cutting)
```

`†` = the conditional **discovery entry**: `/discover` fires *above* `/spec` only when intent is vague
(you want *something* but can't yet state *what*) — it frames the problem and converges to one direction
for `/spec`; an already-clear request skips it. `*` = the conditional **design gate**: `/architect` (system design) for load-bearing
architecture, `/design` + `/design-review` (product/UX) for user-facing surfaces. A change
needs one, both, or neither — internal/CLI work (like this harness) skips them.

Move forward only when a phase's exit criteria are met (see rules/workflow.md).

**Phase orchestrators** run a whole phase in one command (thin wrappers that sequence the
atomic skills, delegate to subagents, and halt for your input at each gate):
`/harness-plan` · `/harness-implement` · `/harness-verify` · `/harness-maintain`, and
`/harness` for the full pipeline with a checkpoint between phases. Use atomic skills
(`/plan`, `/review`, ...) when you only want one step.

## What's here

- **rules/** — always-on guidance (engineering, security, testing, typescript, python, workflow, agents)
- **skills/** — the 18 pipeline drivers you invoke as `/discover`, `/spec`, `/plan`, `/review`, ...
  (incl. the **discovery entry**: `/discover` is the step *above* `/spec` — when intent is vague it
  turns it into a framed problem + one chosen direction, then hands off to `/spec`; conditional/opt-in,
  an already-clear request skips it; and the **design altitude**: `/design` produces a product/UX/UI
  brief in PLAN and `/design-review` gates craft + a11y in VERIFY — both conditional on a user-facing
  surface, driven by the harness's own self-contained design rubrics under `skills/design/references/`;
  plus four opt-in eval skills: `/eval` checkpoints a change against its spec's acceptance
  criteria, `/extract` turns a repeatable workflow into a staged skill proposal,
  `/benchmark` measures whether a component earns its keep via pass@k/pass^k, and `/health`
  takes the repo's test/lint pass-fail pulse on demand — all off by default), plus `/lazy`
  (Phase 3 · L3 generation reduction — the "build the minimum that works" reflex, active by
  default via a hook, intensity `lite|full|ultra`), plus `/operate` (Phase 4 · long-running
  agents — supervises an unattended `/loop`/`/schedule` run with halting guardrails +
  durable `.claude/runs/<id>.json` state, self-checkpointing against `/health` + `/eval`;
  opt-in, off by default), plus `/orchestrate` (Phase 5 · multi-agent orchestration — the
  third orchestration mode: decomposes a task across 3+ independent files, fans out to
  parallel workers on the platform Workflow tool with one-writer-per-file by assignment, and
  reconciles their summaries; opt-in, off by default), plus `/fix` (bug-fix fast lane — the
  parallel entry for fixing something already broken: reproduce-as-a-failing-test first, name the
  root cause, write a minimal fix-plan, then hand off to `/implement` → verify → ship; reuses
  existing agents, no new agent/dep; opt-in), plus `/deploy` + `/observe` (release & feedback
  loop — the step *past* `/ship` and the step that brings prod *back in*, closing the pipeline into
  a loop: `/deploy` orchestrates the project's own deploy mechanism with an **arm-to-fire** HALT
  before any outward action + smoke-tests the deployed artifact + guards a rollback; `/observe`
  takes a brought signal — stack trace/log/error/issue URL — locates the failing area, shapes a
  repro seed, and routes to `/fix`; both opt-in, no new agent/dep)
- **agents/** — 8 scoped subagents the skills delegate to
- **hooks/** + **scripts/hooks/** — runtime automations (tmux, format, typecheck, quality/design gates, strategic compact, build analysis, memory persistence, structural orientation, generation reduction)
- **.mcp.json** — memory · sequential-thinking · magic (load only when the plugin is enabled)

## Operating principles

- **Token optimization:** delegate to the cheapest sufficient model; subagents return
  summaries, not raw dumps. Benchmarking measures value; it is not the runtime strategy.
- **Orchestration:** sequential phases by default; iterative retrieval (≤3 cycles) when
  a subagent's return is insufficient; parallel fan-out across independent files via
  `/orchestrate` (opt-in). See rules/agents.md.
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
