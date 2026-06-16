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
4. Surface risks, dependencies, and ordering explicitly. Note where you'll need an
   architecture decision (`/harness-claude:architect`) vs. where the path is obvious.

## Output
```
## Plan: <title>
## Phases
  1. <goal> — files — exit check (test/build/behavior)
  2. ...
## Risks & dependencies
## Where /architect is needed (if any)
```

## Orchestration note
This is the canonical **sequential-phase** flow (see rules/agents.md). Store the plan
in the session file for multi-session work. Compact context before heavy implementation.

## Exit criterion
Every phase has a concrete exit check. Then `/harness-claude:architect` (if flagged) or `/harness-claude:implement`.
