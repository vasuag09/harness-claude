# Testing Rules

## Coverage floor: 80%

Three layers, all expected for non-trivial features:

1. **Unit** — functions, utilities, components in isolation
2. **Integration** — API endpoints, DB operations, module seams
3. **E2E** — critical user flows (Playwright for web)

## TDD cycle (enforced by `/implement` and the tdd-guide agent)

1. **RED** — write the test first; run it; confirm it fails
2. **GREEN** — write the minimum code to pass
3. **REFACTOR** — clean up with tests green
4. Verify coverage stays ≥ 80%

Write the test against the **spec's acceptance criteria**, not against the
implementation you're about to write.

## Test quality

- Deterministic — no sleeps/timeouts as assertions; prefer explicit waits.
- Isolated — no shared mutable state between tests; mocks reset per test.
- One behavior per test; name states the expected outcome.
- Fix the implementation, not the test — unless the test encodes the wrong expectation.

## Web specifics

- Visual regression at breakpoints 320/768/1024/1440 for visual-heavy work.
- Accessibility: keyboard nav, reduced-motion, contrast.
- For highly visual components, visual regression often carries more signal than
  brittle markup assertions (but does not replace coverage targets).
