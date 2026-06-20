# Skills & Agents Reference

Every command the harness ships, what it does, and which subagent it delegates to.
Invoke a skill by typing its name as a slash command (e.g. `/spec`).

---

## Phase orchestrators

Thin wrappers that sequence the atomic skills for a whole phase, delegate to subagents,
and **pause at each gate for your input**. Not unattended runs.

| Command | Phase | Runs |
|---------|-------|------|
| `/harness` | All | The full pipeline, with a checkpoint between every phase |
| `/harness-plan` | Plan | `/spec` → `/research` → `/plan` → `/architect`* / `/design`* |
| `/harness-implement` | Implement | `/implement` (TDD) → `/build-fix` |
| `/harness-verify` | Verify | `/review` → `/security-review` → `/design-review`* → `/test` → `/verify` → `/ship` |
| `/harness-maintain` | Maintain | `/onboard`* → `/refactor-clean` |

`*` = conditional (runs only when warranted).

---

## Atomic skills

### Plan phase

| Command | What it does | Delegates to |
|---------|--------------|--------------|
| `/spec` | Turn a vague request into a written spec with acceptance criteria | — |
| `/research` | **Reuse-first:** search existing libs/registries/code for a ≥80% fit before writing new code | — |
| `/plan` | Produce a phased, risk-assessed implementation plan from the spec | `planner` |
| `/architect`* | Make & record a *system* design decision (ADR) for load-bearing work | `architect` |
| `/design`* | Produce a product/UX/UI design brief for a user-facing surface — routes by surface to the harness's own craft rubrics (product-UI / aesthetic-direction) and overlays the a11y/UX floor | — |

### Implement phase

| Command | What it does | Delegates to |
|---------|--------------|--------------|
| `/implement` | Execute the plan via TDD — tests first, then minimal code, phase by phase | `tdd-guide` |
| `/build-fix` | Resolve build / type / compile errors fast, with minimal diffs | `build-error-resolver` |

### Verify phase

| Command | What it does | Delegates to |
|---------|--------------|--------------|
| `/review` | Review changed code for quality, correctness, maintainability | `code-reviewer` |
| `/security-review` | OWASP Top-10 + secret scan; blocks on Critical/High | `security-reviewer` |
| `/design-review`* | Craft + a11y/UX gate for user-facing changes; blocks on Blockers | — |
| `/test` | Run the suite, confirm coverage ≥ floor, add missing tests | — |
| `/verify` | Run the app/feature and confirm it observably works | — |
| `/ship` | Sync docs, prepare a clean commit/PR summary — **does not push** | — |

### Maintain phase

| Command | What it does | Delegates to |
|---------|--------------|--------------|
| `/refactor-clean` | Remove dead code, duplication, tech debt — behavior-preserving | `refactor-cleaner` |
| `/onboard` | Build a fast mental map of an unfamiliar codebase | — |

### Memory (cross-cutting)

| Command | What it does |
|---------|--------------|
| `/save-session` | Summarize progress to a dated session file |
| `/resume-session` | Reload the most recent session and re-establish context |

### Opt-in eval (off by default)

| Command | What it does | Delegates to |
|---------|--------------|--------------|
| `/eval` | Checkpoint a change against its spec's acceptance criteria | — |
| `/extract` | Turn a repeatable workflow into a staged skill proposal (human-approved) | — |
| `/benchmark` | Measure whether a component earns its keep — fork + worktree, with vs. without, pass@k / pass^k | — |
| `/health` | Run the repo's test/lint/typecheck pulse on demand (auto-detected or `--cmd`) | — |

### Cost & token optimization (Phase 3)

| Command | What it does | Delegates to |
|---------|--------------|--------------|
| `/lazy` | Generation reduction — build the minimum that works (the "lazy senior dev" ladder). Active by default via the `session-start:lazy-activate` hook; intensity `lite\|full\|ultra`, off via "stop lazy" / `LAZY_DISABLE=1`. Never trades correctness for brevity. | — |

### Long-running agents (Phase 4, opt-in)

| Command | What it does | Delegates to |
|---------|--------------|--------------|
| `/operate` | Supervise an unattended run on the platform's `/loop` + `/schedule` — halting guardrails (drift > budget > iteration-cap) + durable state (`.claude/runs/<id>.json`); self-checkpoints against `/health` + `/eval` so it can't silently drift. | `loop-operator` |

### Multi-agent orchestration (Phase 5, opt-in)

| Command | What it does | Delegates to |
|---------|--------------|--------------|
| `/orchestrate` | Decompose a task spanning 3+ independent files, fan out to workers in parallel on the platform Workflow tool, guarantee one-writer-per-file (assignment-by-plan), and reconcile structured summaries into one result. The third orchestration mode. | platform Workflow tool |

---

## Agents

Scoped subagents the skills delegate to. Reviewers are **read-only**; resolvers may edit.
Each gets the minimum tools its job requires.

| Agent | Role | Scope |
|-------|------|-------|
| `planner` | Implementation planning | Read-only analysis → plan |
| `architect` | System design & architecture decisions | Read-only analysis → decision note |
| `code-reviewer` | Code quality / pattern review | Read-only |
| `security-reviewer` | Vulnerability & secret scan | Read-only |
| `tdd-guide` | Test-first implementation | Read + write (tests then code) |
| `build-error-resolver` | Fix build/type errors | Read + write (minimal diffs) |
| `refactor-cleaner` | Dead-code & duplication removal | Read + write (behavior-preserving) |
| `loop-operator` | One safe iteration of a long-running `/operate` run | Read + write (one increment, then checkpoint) |

---

## Rules (always-on)

Not commands — these are imported by `CLAUDE.md` and shape every skill's behavior:
`workflow`, `agents`, `engineering`, `security`, `testing`, `typescript`, `python`
(in `rules/`). To apply them on your *other* projects, see the
[README](../README.md#make-the-rules-global-opt-in).
