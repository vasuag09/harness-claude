---
name: plan
description: Produce a phased, risk-assessed implementation plan from a spec. Use after /spec and /research, before writing code. Delegates to the harness-claude:planner agent for non-trivial work.
---

# /plan — phased implementation plan

Goal: a plan an executor (you or a subagent) can follow without re-deriving context.

## Do this
1. For non-trivial work, **delegate to the `harness-claude:planner` agent**, passing it the spec,
   the reuse decision, and the objective/purpose (not just a one-line query).
2. For small/linear work, plan inline using the same shape.
3. Break work into **phases**: each small, independently verifiable, with an exit check.
4. Surface risks, dependencies, and ordering explicitly. **Red-team the plan before
   handing it off** — assume it already failed and ask why; attack your own draft for
   hidden assumptions and missing edge cases, not just the obvious risks. Note where
   you'll need an architecture decision (`/harness-claude:architect`) vs. where the path
   is obvious.
5. **Flag parallelizable phases.** From the per-phase file lists, mark any phase that writes
   **3+ independent files with disjoint write-sets and no cross-dependency** as an
   `/harness-claude:orchestrate` candidate. This is what makes `/implement` surface the parallel
   fan-out offer instead of silently editing serially — if you don't flag it here, it's usually
   missed there. Flag only genuine cases; if none qualify, say so.

## Output
```
## Plan: <title>
## Phases
  1. <goal> — files — exit check (test/build/behavior)
  2. ...
## Risks & dependencies
## Parallelizable phases (if any) — phases with 3+ independent files → /orchestrate candidates
## Where /architect is needed (if any)
```

## Orchestration note
This is the canonical **sequential-phase** flow (see rules/agents.md). Store the plan
in the session file for multi-session work. Compact context before heavy implementation.

## Exit criterion
Every phase has a concrete exit check. Then `/harness-claude:architect` (if flagged) or `/harness-claude:implement`.
