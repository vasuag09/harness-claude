---
name: spec
description: Turn a vague request into a clear, written spec with acceptance criteria before any code. Use at the start of any non-trivial feature, change, or bugfix. First gate of the Plan phase.
---

# /spec — clarify the request into a spec

Goal: eliminate misunderstanding before a line of code. A vague ask becomes a short,
testable spec.

## Do this
1. **Restate** the request in your own words. If anything is ambiguous or
   underspecified, ask the user focused questions — do not guess on load-bearing points.
2. Capture the essentials only (keep it lean):
   - **Problem / why** — the user-visible outcome wanted.
   - **Scope** — what's in, and explicitly what's out.
   - **Acceptance criteria** — concrete, testable bullets ("given X, when Y, then Z").
     These become the tests in `/harness-claude:implement`.
   - **Constraints** — perf, security, compatibility, deadlines, non-functionals.
   - **Open questions** — anything blocking, with your recommended default.
3. Keep it to one screen. This is a spec, not a novel.

## Output
Write the spec to the conversation (and, for multi-session work, into the session file
via `/harness-claude:save-session`). Format:

```
# Spec: <title>
## Problem
## In scope / Out of scope
## Acceptance criteria
- [ ] ...
## Constraints
## Open questions (with recommended defaults)
```

## Exit criterion
Acceptance criteria are concrete and testable, and no blocking open question remains.
Then proceed to `/harness-claude:research`.
