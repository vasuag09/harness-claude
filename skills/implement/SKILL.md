---
name: implement
description: Execute a plan via test-driven development — write tests first, then minimal code, phase by phase. Use after /plan (and /architect if needed) to write the actual feature. Delegates to the harness-claude:tdd-guide agent.
---

# /implement — build it, test-first

Goal: turn the plan into working, tested, clean code — one phase at a time.

## Do this
1. Take the plan's phases in order. For each phase:
   - **Delegate to `harness-claude:tdd-guide`** (or run TDD inline): write a failing test against an
     acceptance criterion (RED) → minimum code to pass (GREEN) → refactor.
   - Keep files modular and lean (<800 lines), immutable patterns, inputs validated.
   - Let the format/typecheck hooks run; fix what they flag immediately.
2. **Parallel-fan-out checkpoint — evaluate before editing, don't skip.** Before you start
   editing a phase serially, count the files it will *write*. If it spans **3+ independent files
   with disjoint write-sets and no dependency between them** (the plan may already flag this
   phase as a `/orchestrate` candidate), you **must** surface the fan-out option: name the file
   split and propose `/harness-claude:orchestrate`, then let the user choose before proceeding.
   Surfacing the offer is **mandatory whenever the trigger fires** — that is the only path by
   which parallel mode ever gets used; what stays **opt-in is *acting* on it** — never silently
   start a multi-agent run (it spawns workers and costs more tokens). If the trigger doesn't fire,
   note that in one line and edit serially.
3. After each phase, confirm its exit check (test green, build clean) before moving on.
4. If the build breaks and the fix is non-obvious, hand off to `/harness-claude:build-fix`.
5. Stay inside the plan. If reality diverges from it, stop, update the plan, then resume
   — don't silently improvise scope.

## Token discipline
Delegate search/exploration and isolated edits to cheaper models; keep the orchestrator
focused on integration. Compact at phase boundaries, not mid-phase.

## Exit criterion
All phases complete, tests written-first and green, build/types/lint clean. Then
proceed to the Verify phase (`/harness-claude:review`).
