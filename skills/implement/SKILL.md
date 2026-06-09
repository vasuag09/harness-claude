---
name: implement
description: Execute a plan via test-driven development — write tests first, then minimal code, phase by phase. Use after /plan (and /architect if needed) to write the actual feature. Delegates to the tdd-guide agent.
---

# /implement — build it, test-first

Goal: turn the plan into working, tested, clean code — one phase at a time.

## Do this
1. Take the plan's phases in order. For each phase:
   - **Delegate to `tdd-guide`** (or run TDD inline): write a failing test against an
     acceptance criterion (RED) → minimum code to pass (GREEN) → refactor.
   - Keep files modular and lean (<800 lines), immutable patterns, inputs validated.
   - Let the format/typecheck hooks run; fix what they flag immediately.
2. After each phase, confirm its exit check (test green, build clean) before moving on.
3. If the build breaks and the fix is non-obvious, hand off to `/build-fix`.
4. Stay inside the plan. If reality diverges from it, stop, update the plan, then resume
   — don't silently improvise scope.

## Token discipline
Delegate search/exploration and isolated edits to cheaper models; keep the orchestrator
focused on integration. Compact at phase boundaries, not mid-phase.

## Exit criterion
All phases complete, tests written-first and green, build/types/lint clean. Then
proceed to the Verify phase (`/review`).
