# Engineering Rules

The non-negotiable defaults for any code this harness produces. Skills and agents
assume these; hooks enforce a subset automatically.

## Modular & lean (CRITICAL)

Many small, focused files beat few large ones.

- Target **200–400 lines** per file; **800 is a hard ceiling** — split before you hit it.
- One responsibility per module. High cohesion, low coupling.
- Organize by **feature/domain**, not by file type.
- Extract shared logic into utilities the moment it appears twice (DRY).
- Build only what the current task needs (YAGNI). Delete dead code and unused deps.
- Prefer the simplest design that works (KISS). Reach for an abstraction only when a
  concrete duplication or variation actually demands it.

## Generation reduction (the lazy reflex)

YAGNI/KISS above say *what* to build; this says *stop before over-building*. Before writing
code, take the first rung that holds: does it need to exist at all → stdlib → native platform
feature → already-installed dependency → one line → only then the minimum code that works. The
shortest working diff wins; boring over clever. Mark deliberate simplifications with a `lazy:`
comment naming the ceiling and the upgrade path. This reflex is active by default (Phase 3 ·
Layer 3 — the `session-start:lazy-activate` hook; `/lazy` controls intensity `lite|full|ultra`,
off via "stop lazy" / `LAZY_DISABLE=1`). **It never trades correctness for brevity** — the
accuracy floor (trust-boundary validation, data-loss-preventing error handling, security, a11y,
and one runnable check behind non-trivial logic) is non-negotiable. Measured marginal lift over
this file's standing YAGNI: **−35% generated output / −23% LOC at held accuracy** on an
over-build-prone task; dollar impact scales with how output-heavy the work is. See `skills/lazy/SKILL.md`.

## Surface assumptions & scope discipline

Before non-trivial work, **state the assumptions you're filling in** (about requirements,
architecture, scope) in one short block and invite correction — silently guessing at an
ambiguous spec is the most expensive failure mode. When you hit a genuine contradiction
(spec vs code, two sources disagreeing), stop and name it; don't pick an interpretation
and hope.

Touch only what the task names. Don't remove comments you don't understand, refactor
adjacent code as a side effect, delete "seemingly unused" code without approval, or add
unrequested features. Surgical diffs; cleanup belongs to `/refactor-clean`.

## Immutability (CRITICAL)

Create new values; never mutate shared ones in place.

```
WRONG:   obj.field = value          // mutates caller's data
CORRECT: const next = { ...obj, field: value }   // returns a new copy
```

Rationale: immutable data kills hidden side effects, simplifies debugging, and makes
concurrency safe.

## Error handling

- Handle errors **explicitly at every level**; never silently swallow.
- User-facing messages stay friendly; server logs carry full context.
- Fail fast at boundaries with clear messages.

## Input validation

Validate at every system boundary — user input, API responses, file contents, env.
Use schema validation (zod / pydantic) where available. Never trust external data.

## No-hardcoding

No magic values, secrets, URLs, or credentials inline. Use constants, config, or env.

## Quality checklist (before "done")

- [ ] Readable, well-named, small functions (<50 lines)
- [ ] Files focused (<800 lines), no nesting deeper than 4 levels
- [ ] Explicit error handling, validated inputs
- [ ] No hardcoded values, no secrets, no stray debug logs
- [ ] Immutable patterns used
