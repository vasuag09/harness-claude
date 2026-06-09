# Python Rules

## Style & idioms

- PEP 8, formatted by **ruff format**; lint with **ruff** (the quality-gate hook runs it).
- Type hints on all public functions; check with **mypy** (or pyright). Avoid bare `Any`.
- Pythonic constructs: comprehensions over manual loops, context managers for resources,
  `pathlib` over `os.path`, f-strings over `%`/`.format`.
- EAFP where it reads clearly; explicit guards where it doesn't.

## Structure

- Small modules; functions <50 lines. Group by feature/domain.
- Validate external data with **pydantic** at boundaries.
- Dependency-inject collaborators; depend on protocols/ABCs, not concretions.

## Errors & resources

- Raise specific exceptions; never bare `except:`. Catch narrowly.
- Never swallow exceptions silently — log with context or re-raise.
- Use `with` for files, locks, connections, sessions.

## Tooling

- Prefer `uv` / `pip-tools` for reproducible deps; pin versions.
- Tests with **pytest**; fixtures for setup, parametrize for cases (≥80% coverage).
- No mutable default arguments. No hardcoded secrets — use env / a secret manager.
