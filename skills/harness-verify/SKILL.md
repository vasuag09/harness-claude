---
name: harness-verify
description: Orchestrate the entire VERIFY phase — code review, security review, tests, run-the-app verification, and ship-prep. Use after /harness-implement. Sequences the Verify skills, runs reviewers in parallel when sensible, halts on Critical/High findings, and stops at the git boundary.
---

# /harness-verify — run the Verify phase

Thin orchestrator over the Verify skills. Goal: prove the change is production-grade
before it can merge.

## Sequence

1. **Review** — run `/review` (delegate to `code-reviewer`) and, for any change touching
   auth/input/queries/files/external-calls/crypto/secrets, `/security-review` (delegate
   to `security-reviewer`). Run these **two in parallel** when the change is
   security-sensitive; otherwise review first, then security.
   → **HALT on any Critical or High finding** — fix, then re-review the changed lines.

2. **`/test`** — run the full suite (in tmux if long) + coverage. Every acceptance
   criterion must have a test; coverage ≥ 80% on changed code. Add missing tests via
   `tdd-guide`.

3. **`/verify`** — launch the app/feature and **observe each acceptance criterion working**
   in reality (browser screenshot for web; exercise unhappy paths). Tests passing is
   necessary, not sufficient. Anything tests missed → add a regression test (back to step 2).

4. **`/ship`** — sync docs, draft the change summary from the full diff, confirm
   build/types/lint/tests green and no secrets/debug logs.
   → **HALT at the git boundary:** do NOT commit/push/PR. Report "ready — say the word."

## Rules
- Block, don't warn, on Critical/High security or correctness findings.
- If a secret is exposed: stop, rotate, sweep for siblings.
- Never run git write operations unless the user explicitly asks.

## Output
Verify summary: review verdict, security verdict, coverage %, observed-working evidence,
docs synced, "ready to commit/PR." Then optionally `/harness-maintain`.
