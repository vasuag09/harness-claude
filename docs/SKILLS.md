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
| `/harness-plan` | Plan | `/spec` → `/research` → `/plan` → `/architect`* |
| `/harness-implement` | Implement | `/implement` (TDD) → `/build-fix` |
| `/harness-verify` | Verify | `/review` → `/security-review` → `/test` → `/verify` → `/ship` |
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
| `/architect` | Make & record an architecture/design decision for load-bearing work | `architect` |

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

---

## Rules (always-on)

Not commands — these are imported by `CLAUDE.md` and shape every skill's behavior:
`workflow`, `agents`, `engineering`, `security`, `testing`, `typescript`, `python`
(in `rules/`). To apply them on your *other* projects, see the
[README](../README.md#make-the-rules-global-opt-in).
