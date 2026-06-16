---
name: architect
description: Make and record an architecture/design decision for non-trivial work — new subsystems, interfaces, data models, or significant refactors. Use when /plan flags a load-bearing decision. Delegates to the harness-claude:architect agent.
---

# /architect — design decision (ADR)

Goal: a concise, reviewable design with explicit trade-offs — not analysis paralysis.

## When to use
Only when the design is non-obvious: a new subsystem, a public interface/data model,
a cross-cutting change, or a refactor with several viable shapes. Skip for routine work.

## Do this
1. **Delegate to the `harness-claude:architect` agent** with the problem, constraints, and the
   existing architecture it must fit.
2. Require: recommended approach, alternatives considered (and why rejected),
   consequences/trade-offs, interfaces & data model, risks & mitigations.
3. Keep the recommendation decisive — one approach, justified.

## Output — ADR
```
## Context
## Decision
## Alternatives & why not
## Consequences / trade-offs
## Interfaces & data model
## Risks & mitigations
```

Save the ADR (session file, or `docs/adr/` if the project keeps them).

## Exit criterion
A single recommended design with trade-offs stated. Then `/harness-claude:implement`.
