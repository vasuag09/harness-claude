---
name: review
description: Review changed code for quality, correctness, and maintainability before merge. Use immediately after implementing or modifying code. Delegates to the code-reviewer agent. First gate of the Verify phase.
---

# /review — code quality & correctness

Goal: catch bugs and quality issues before they merge.

## Do this
1. **Delegate to `code-reviewer`** with the diff in scope (`git diff`, `git diff
   --staged`, or the files named).
2. The reviewer checks correctness, edge cases, error handling, naming, complexity,
   duplication, adherence to harness rules, and test coverage — reporting `file:line`
   with severity.
3. Triage findings:
   - **Critical** → block, fix now.
   - **High** → fix before merge.
   - **Medium/Low** → fix when reasonable / note.
4. Apply fixes, then re-review the changed lines if Critical/High were found.

## Exit criterion
No Critical or High findings outstanding. Then `/security-review` (or run both in
parallel if the change is security-sensitive).
