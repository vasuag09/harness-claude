# Workflow — the SDLC pipeline

This harness runs a four-phase pipeline. Each phase has a skill; each skill can
delegate to an agent. Move forward only when the current phase's exit criteria are met.

```
PLAN ─────────────► IMPLEMENT ─────► VERIFY ─────────────► MAINTAIN
/spec  /research          /implement     /review   /test          /refactor-clean
/plan                     /build-fix     /security-review         /onboard
/architect* /design*                     /design-review*  /verify
                                         /ship
        └────────── memory: /save-session · /resume-session (cross-cutting) ──────────┘
```

`*` conditional — the **design gate**. `/architect` (system design) fires for load-bearing
architecture; `/design` (product/UX) and its VERIFY counterpart `/design-review` fire for
user-facing surfaces. A change can need one, both, or neither; internal/CLI work skips them.

## Phase exit criteria

| Phase | Done when |
|-------|-----------|
| **Plan** | A written spec with acceptance criteria, a reuse decision, a phased task list, and — *when warranted* — an architecture note (`/architect`) and/or a product/UX design brief (`/design`) exist. |
| **Implement** | Code matches the plan, builds clean, types/lint pass, tests written first and green. |
| **Verify** | Code review + security review pass, coverage ≥ 80%, the app/feature observably works, **any user-facing surface passes `/design-review` (craft + a11y/UX floor)**, docs synced. |
| **Maintain** | Dead code/debt removed; the change is documented and reversible. |

## Tooling defaults

- **Search:** use **mgrep**, not `grep`/`rg`/`Glob`. `mgrep "query"` for code, `mgrep --web "query"` for the web. (A hook nudges you if you reach for grep.)
- **Long-running commands:** run dev servers, test watchers, builds, and `docker` inside **tmux** so they survive and stream. (A hook reminds you.)
- **Docs/API questions:** use **context7** for live library docs before answering from memory.
- **Context hygiene:** disable unused MCPs/plugins (<10 enabled, <80 tools). Compact at logical phase boundaries, not mid-task (a hook suggests `/compact` ~every 50 tool calls).

## Reuse-first (mandatory before writing new code)

In the Plan phase, `/research` searches existing libraries, registries, and code
(GitHub, context7, package registries) for something that already solves ≥80% of the
problem. Adopt/port proven code over hand-rolling. Document the decision in the spec.

## Long-running runs (opt-in)

For unattended, many-iteration or scheduled work, `/operate` supervises a run on the
platform's `/loop` + `/schedule` (a thin discipline layer — no new runtime). It enforces
**halting guardrails** (drift > budget > iteration-cap) and keeps **durable state** in
`.claude/runs/<id>.json` — the source of truth across firings, since each firing may be a
fresh context. Each checkpoint reuses `/health` + `/eval` so a run **can't silently drift**:
N consecutive failing checkpoints halt it and surface the criterion. Opt-in; the git
boundary still holds — a run never commits/pushes/branches unless explicitly armed.

## Multi-agent fan-out (opt-in)

For a task that spans 3+ **independent** files (disjoint write-sets, no dependency between
subtasks), `/orchestrate` decomposes it and runs the pieces in parallel. It is the lead: it
assigns one writer per file, **verifies the write-sets are disjoint before fanning out**, drives
the fan-out on the platform Workflow tool, and reconciles the workers' structured summaries into
one result. The one-writer-per-file guarantee holds by construction (assignment-by-plan, not
isolation). Opt-in; the git boundary still holds — no worker commits/pushes/branches unless
explicitly armed. See `rules/agents.md` for the orchestration-mode decision rule.

## Don'ts

- Don't skip phases. Don't start coding before a spec + plan exist for non-trivial work.
- Don't run git commit/push/branch operations unless the user explicitly asks.
- Don't write extracted/learned skills automatically — stage them for approval.
- Don't let a long `/operate` run continue past a drift halt — stop, surface the failing
  criterion, and fix the cause; never bump the run id to dodge a guardrail.
