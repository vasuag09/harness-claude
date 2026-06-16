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
  (plus two opt-in eval skills: `/eval` checkpoints a change against its spec's acceptance
  criteria, and `/extract` turns a repeatable workflow into a staged skill proposal — both
  off by default)
- **agents/** — 7 scoped subagents the skills delegate to
- **hooks/** + **scripts/hooks/** — runtime automations (tmux, format, typecheck, quality/design gates, strategic compact, build analysis, memory persistence)
- **.mcp.json** — memory · sequential-thinking · magic (load only when the plugin is enabled)

## Operating principles

- **Token optimization:** delegate to the cheapest sufficient model; subagents return
  summaries, not raw dumps. Benchmarking measures value; it is not the runtime strategy.
- **Orchestration:** sequential phases by default; iterative retrieval (≤3 cycles) when
  a subagent's return is insufficient. See rules/agents.md.
- **Modular & lean:** files <800 lines, immutable patterns, validated inputs.
- **Search with mgrep, not grep.** Run long commands in tmux. Use context7 for live docs.
- **Git boundary:** never commit/push/branch unless the user explicitly asks.

## Imported rules

@rules/workflow.md
@rules/agents.md
@rules/engineering.md
@rules/security.md
@rules/testing.md
@rules/typescript.md
@rules/python.md
