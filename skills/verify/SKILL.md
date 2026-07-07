---
name: verify
description: Confirm the change actually works by running the app/feature and observing real behavior — not just that tests pass. Use late in the Verify phase, before ship. Closes the loop between "tests green" and "it works."
---

# /verify — observe it actually working

Goal: prove the feature does what the spec said, in the running app — green tests are
necessary, not sufficient.

**Default to NEEDS WORK.** Assume the change is *not* done until the running system proves each
criterion with evidence. A clean first pass is suspicious, not reassuring — look harder before
you pass it; first attempts usually have a rough edge you haven't found yet.

## Do this
1. Load the criteria from `.claude/planning/<slug>/SPEC.md` (and `PLAN.md` for what each
   task claimed to cover), if present — verify against the recorded `AC-n`, not memory.
2. Launch the app/feature the way a user would (dev server in tmux, CLI invocation,
   the affected screen/endpoint).
3. Exercise each **acceptance criterion** against the running system. For web, drive
   the browser (Playwright/Chrome) and capture a screenshot of the working state.
4. Check the unhappy paths the spec named: invalid input, empty/error states, edge
   cases. Confirm errors are handled and messages are sane.
5. Note anything observed that tests missed → add a regression test (back to `/harness-claude:test`).

## Output — coverage matrix
Build a matrix mapping **every `AC-n`** to the evidence and a verdict, and write it to
`.claude/planning/<slug>/VERIFICATION.md` (present it in the reply too; for trivial work,
the reply is enough):

```
## Verification: <title>
| Criterion | Evidence (what you ran / observed) | Verdict |
|-----------|------------------------------------|---------|
| AC-1      | <command / screenshot / log>       | pass    |
| AC-2      | (could not exercise)               | FAIL    |
```

A criterion you could not actually exercise is **FAIL**, not blank — never pass on
assumption.

## State
Patch `.claude/STATE.md`: `phase: verify`, `status: done` (or `blocked`),
`next_skill: /ship`.

## Exit criterion
**Every `AC-n` has a `pass` verdict backed by evidence.** Any unaddressed or failing
criterion blocks the exit — the matrix names which `AC-n` and why. Then `/harness-claude:ship`.
