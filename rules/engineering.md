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
