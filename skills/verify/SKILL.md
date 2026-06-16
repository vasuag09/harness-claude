---
name: verify
description: Confirm the change actually works by running the app/feature and observing real behavior — not just that tests pass. Use late in the Verify phase, before ship. Closes the loop between "tests green" and "it works."
---

# /verify — observe it actually working

Goal: prove the feature does what the spec said, in the running app — green tests are
necessary, not sufficient.

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
Every acceptance criterion observably works in the running app. Then `/harness-claude:ship`.
