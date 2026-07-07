# Workflow — the SDLC pipeline

This harness runs a four-phase pipeline. Each phase has a skill; each skill can
delegate to an agent. Move forward only when the current phase's exit criteria are met.

```
DISCOVER† ─► PLAN ─────────────► IMPLEMENT ─────► VERIFY ─────────────► MAINTAIN
/discover    /spec  /research          /implement     /review   /test          /refactor-clean
             /plan  /plan-check         /build-fix     /security-review         /onboard
             /architect* /design*                     /design-review*  /verify
                                                       /ship
   └─── memory: /save-session · /resume-session · .claude/STATE.md spine (cross-cutting) ───┘
```

`†` conditional — the **discovery entry**. `/discover` fires *above* `/spec` only when intent is
vague (you want *something* but can't yet state *what*); an already-clear request skips it and starts
at `/spec`. `*` conditional — the **design gate**. `/architect` (system design) fires for load-bearing
architecture; `/design` (product/UX) and its VERIFY counterpart `/design-review` fire for
user-facing surfaces. A change can need one, both, or neither; internal/CLI work skips them.

## Phase exit criteria

| Phase | Done when |
|-------|-----------|
| **Plan** | A written spec with ID'd acceptance criteria, a reuse decision, a phased task list that **passes `/plan-check`** (no Critical finding), and — *when warranted* — an architecture note (`/architect`) and/or a product/UX design brief (`/design`) exist. |
| **Implement** | Code matches the plan, builds clean, types/lint pass, tests written first and green. |
| **Verify** | Code review + security review pass, coverage ≥ 80%, **every acceptance criterion (`AC-n`) has a `pass` verdict backed by evidence in the `/verify` coverage matrix**, the app/feature observably works, **any user-facing surface passes `/design-review` (craft + a11y/UX floor)**, docs synced. |
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

## Durable state & per-phase artifacts (the context-rot substrate)

Two file-system layers keep work resumable and delegation-ready across context resets —
both **optional and additive**; absent or malformed files degrade to the freeform
session-file behavior and never block. Full schema: `docs/state-and-artifacts.md`.

- **`.claude/STATE.md` spine** — one small (<100-line) machine-navigable file: frontmatter
  (`phase`, `status`, `slug`, `next_skill`, `updated`) over Verified/Blocked/Next body
  sections. It's the *index* above the `.claude/sessions/*.md` narrative, not a replacement.
  Read it **first** when orienting; each pipeline skill patches it on **phase exit**. The
  session-start hook surfaces `next_skill`; the stop hook refreshes `updated`.
- **`.claude/planning/<slug>/` artifacts** — `/spec` writes `SPEC.md` (ID'd `AC-n`
  criteria), `/plan` writes `PLAN.md` (tasks with write-sets + `depends_on`), `/verify`
  writes `VERIFICATION.md` (the `AC-n` coverage matrix). A downstream step — or a
  fresh-context subagent — reads the **file**, not the conversation. Trivial/lazy work
  skips artifacts and says so in one line.

## Plan-check gate (between Plan and Implement)

`/plan-check` adversarially reviews `PLAN.md` against `SPEC.md` before any code is written —
criteria coverage, scope creep, and parallel-task write-set disjointness — delegating to the
`planner` agent read-only and looping ≤3 revisions. Non-blocking except on **Critical** (a
plan that can't satisfy a criterion, or parallel tasks colliding on a file). It is the
plan-phase counterpart to `/review`. Surfaced-mandatory, act-opt-in: `/plan` recommends it;
you run it.

## Discovery entry (opt-in, conditional)

The pipeline's front door (`/spec`) assumes you can already state *what* you want. When intent is
**vague** — you want *something* but can't name the shape, or you're asking "what would make the best
use of X?" — `/discover` is the entry *above* `/spec`. It's a **divergent→convergent** move:
interrogate the real goal (Socratic, via focused questions), map a **bounded** set of ≤5 grounded
options, then **force convergence to exactly one** recommended direction, and hand a one-screen *intent
statement* to `/spec`. The discipline is the convergence: it ends in a **decision, not a brainstorm** —
an unranked option dump is an invalid exit. It's strictly upstream of `/spec`/`/research`/`/design`
(it produces the request; it does **not** write acceptance criteria — that stays `/spec`'s job), and
**conditional**: an already-clear request is detected and routed straight to `/spec` with no interview.
Read-only; the git boundary holds.

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

## Bug-fix entry (opt-in)

The pipeline above is greenfield-shaped — it assumes you're *building* a feature. When something
is **already broken** (a red test, a prod error, a reported defect), `/fix` is the parallel entry:
it does the bug-specific part — **reproduce as a failing test FIRST**, name the root cause, write a
**minimal** fix-plan — then hands off to the *existing* pipeline (`/implement` → `/review` +
`/security-review` → `/verify` → `/ship`) so the fix rides the proven gates rather than duplicating
them. Distinct from `/build-fix` (which is for build/type/compile errors, not behavioral bugs).
Opt-in; the git boundary still holds — `/fix` never commits/pushes/branches.

## Release & feedback loop (opt-in)

The pipeline above is a **line** that stops at the repo edge: `/ship` prepares a clean commit/PR and
halts. Two opt-in skills close it into a **loop** by bracketing the live environment:

```
/ship → /deploy → (prod) → /observe → /fix → … back into the pipeline
```

- **`/deploy`** — the first step *past* the repo. It orchestrates the project's **own existing** deploy
  mechanism (detects `vercel.json` / `Dockerfile` / `Makefile` / CI / `package.json` scripts — never
  prescribes a stack), names the rollback path, runs pre-deploy smoke, then **arm-to-fire HALTs**:
  no real outward action until you type `arm deploy`. On arm it deploys in tmux, smoke-tests the
  *deployed* artifact (reusing `/health`), and guards a rollback (`arm rollback`) if that smoke fails.
- **`/observe`** — the step that brings production *back in*. You hand it a signal (stack trace, log,
  error, issue URL — **bring-a-signal**, no polling/credentials/MCP); it locates the failing area in
  code and shapes a repro seed, then routes to `/fix`. It does **not** write the finished failing test
  — that stays `/fix`'s job.

Both are opt-in and off by default. The git boundary still holds, and the **arm-to-fire** boundary
holds absolutely — `/deploy` performs no outward action without an explicit arm.

## Don'ts

- Don't skip phases. Don't start coding before a spec + plan exist for non-trivial work.
- Don't run git commit/push/branch operations unless the user explicitly asks.
- Don't write extracted/learned skills automatically — stage them for approval.
- Don't let a long `/operate` run continue past a drift halt — stop, surface the failing
  criterion, and fix the cause; never bump the run id to dodge a guardrail.
- Don't fire a `/deploy` (or rollback) without the explicit `arm deploy` / `arm rollback` signal —
  "the plan looks fine" is not an arm; the arm-to-fire HALT is a hard stop.
