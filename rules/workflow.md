# Workflow — the SDLC pipeline

This harness runs a four-phase pipeline. Each phase has a skill; each skill can
delegate to an agent. Move forward only when the current phase's exit criteria are met.

```
PLAN ─────────────► IMPLEMENT ─────► VERIFY ─────────► MAINTAIN
/spec  /research          /implement     /review            /refactor-clean
/plan  /architect         /build-fix     /security-review   /onboard
                                         /test  /verify
                                         /ship
        └────────── memory: /save-session · /resume-session (cross-cutting) ──────────┘
```

## Phase exit criteria

| Phase | Done when |
|-------|-----------|
| **Plan** | A written spec with acceptance criteria, a reuse decision, a phased task list, and (for non-trivial work) an architecture note exist. |
| **Implement** | Code matches the plan, builds clean, types/lint pass, tests written first and green. |
| **Verify** | Code review + security review pass, coverage ≥ 80%, the app/feature observably works, docs synced. |
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

## Don'ts

- Don't skip phases. Don't start coding before a spec + plan exist for non-trivial work.
- Don't run git commit/push/branch operations unless the user explicitly asks.
- Don't write extracted/learned skills automatically — stage them for approval.
