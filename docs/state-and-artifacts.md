# STATE.md spine & planning artifacts

The durable substrate that lets the pipeline survive context resets and hand work to a
fresh-context subagent — the harness's answer to context rot: heavy work reads durable
file-system state, not an accumulating conversation. It stays lean and prompt-only. All of
it is **plain markdown the skills read and write by instruction** — there is no engine and
no schema validator; a light hook only surfaces and timestamps state, it does not enforce it.

Everything here is **additive and optional**. Absent or malformed files degrade
gracefully — skills fall back to the freeform session-file behavior and never block.

---

## `.claude/STATE.md` — the position spine

One small file at the repo's `.claude/STATE.md`. It is the *index* above the freeform
`.claude/sessions/*.md` narrative, not a replacement: STATE.md answers "where are we and
what runs next?" in a machine-navigable form; the session files keep the human story.

Read it **first** when orienting (`/resume-session`, session-start). Patch it on every
**phase exit**. Target **under 100 lines** — a digest, not an archive.

```markdown
---
harness_state_version: "1.0"
slug: durable-state-spine          # active planning slug → .claude/planning/<slug>/  (null when none)
phase: plan                         # discover|spec|research|plan|plan-check|architect|design|
                                    #   implement|review|security-review|test|verify|ship|
                                    #   refactor-clean|idle
status: in-progress                 # in-progress|blocked|done|paused
next_skill: /plan-check             # the slash command to run next (null when idle/done)
updated: 2026-07-08T14:03:00Z       # ISO-8601; refreshed by the stop hook
---

## Verified
- STATE spine schema + graceful-degradation path (AC-1, AC-5)

## Blocked
- (nothing)

## Next
- Run /plan-check on PLAN.md before /implement
```

### Field reference

| Field | Purpose |
|---|---|
| `harness_state_version` | Schema version; lets a future reader detect format drift. |
| `slug` | Active planning slug → `.claude/planning/<slug>/`. `null` when no feature is in flight. |
| `phase` | Where in the pipeline the work sits. |
| `status` | `in-progress` \| `blocked` \| `done` \| `paused`. |
| `next_skill` | The one command to run next — what session-start surfaces. `null` when idle/done. |
| `updated` | ISO-8601 timestamp; the stop hook refreshes it when the tree is dirty. |

### Phase-exit convention (how skills keep it current)

Each pipeline skill, on completing its step, patches the frontmatter: set `phase` to the
step just finished, `status`, and `next_skill` to the recommended next command; leave the
body's **Verified / Blocked / Next** current. This is a **convention**, not enforced — a
skill that forgets simply leaves stale state the next `/resume-session` will flag as drift.
For trivial/lazy work, skip STATE.md entirely and say so in one line.

---

## `.claude/planning/<slug>/` — per-feature artifacts

Durable per-feature outputs so a step (or a fresh subagent) reads a **file**, not the
conversation. `<slug>` is a short kebab-case name for the feature (e.g.
`durable-state-spine`), chosen at `/spec` and recorded in STATE's `slug`.

```
.claude/planning/<slug>/
├── SPEC.md            # /spec  — problem, in/out scope, AC-n criteria, constraints
├── PLAN.md            # /plan  — phased tasks; each declares depends_on + exit check
└── VERIFICATION.md    # /verify — AC × evidence × pass/fail coverage matrix
```

Who reads what: `/plan` reads `SPEC.md`; `/plan-check` reads `PLAN.md` + `SPEC.md`;
`/implement` reads `PLAN.md`; `/verify` reads `SPEC.md` + `PLAN.md`. Trivial work may skip
artifacts (lazy reflex) — the skill notes the skip in one line.

### Acceptance-criteria IDs

`SPEC.md` criteria carry stable IDs — `AC-1`, `AC-2`, … — so `/verify` can build a
coverage matrix that names exactly which criterion is covered or missing.

### `PLAN.md` task format (with dependency declarations)

Each task is a bounded unit with an explicit write-set and dependencies, so
`/orchestrate` can group tasks into parallel waves safely.

```markdown
## Task T1: <goal>
- files: src/a.ts, src/b.ts        # write-set (must be disjoint from parallel tasks)
- depends_on: []                   # task IDs this must run after; [] = wave 1
- addresses: AC-1, AC-3            # which SPEC criteria it satisfies
- exit check: <test / build / observable behavior>
```

**Wave grouping (consumed by `/orchestrate`):** tasks with `depends_on: []` form wave 1
and run in parallel; a task runs in the wave after the latest wave of its dependencies.
Within a wave, write-sets must be pairwise disjoint (one writer per file). A dependency
cycle is an error — surface it, never run it.
