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
1. Launch the app/feature the way a user would (dev server in tmux, CLI invocation,
   the affected screen/endpoint).
2. Exercise each **acceptance criterion** against the running system. For web, drive
   the browser (Playwright/Chrome) and capture a screenshot of the working state.
3. Check the unhappy paths the spec named: invalid input, empty/error states, edge
   cases. Confirm errors are handled and messages are sane.
4. Note anything observed that tests missed → add a regression test (back to `/harness-claude:test`).

## Output
A short evidence note: what you ran, what you observed per criterion (pass/fail),
screenshots/log snippets for the key states.

## Exit criterion
Every acceptance criterion **observably works and is backed by evidence** in the running app.
Any criterion you could not actually exercise **fails by default** — never pass on assumption.
Then `/harness-claude:ship`.
