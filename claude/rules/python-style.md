---
description: Python type annotations, naming, imports, and code style conventions
paths:
  - "**/*.py"
---

# Python Style Guide

For JAX/Flax specifics, see `jax-ml.md`.

## 1. Type System

- `mypy --strict` enforced in pre-commit
- All functions typed: parameters, return values, no `Any` without justification
- Use `| None` for optionals (not `Optional`)
- Generic types fully specified: `list[dict[str, int | float]]` not `list[dict]`
- Custom `Result[T, E]` type for error handling (see section 4)

---

## 2. Naming Conventions

- **Functions:** abbreviated verb prefixes — `get_*` (pure), `fetch_*` (I/O), `calc_*` (computation), `parse_*`, `validate_*`
- **Booleans:** `is_*`, `has_*`, `can_*`, `should_*`
- **Classes:** plain nouns for immutable (`User`, `Config`), suffixed for mutable (`UserBuilder`, `StateManager`)
- **No:** verbose names (`calculate_discount_for_user`), ambiguous verbs (`get_orders` when doing I/O)

---

## 3. Import Organization

Order: stdlib -> third-party -> blank line -> local (all alphabetical, explicit imports, no wildcards).

```python
import logging
from pathlib import Path

import jax
from pydantic import BaseModel

from core.result import Ok, Result
from models.user import User
```

Ban circular imports (enforced via import-linter).

---

## 4. Error Handling

- **Primary:** `Result[T, E]` (`Ok[T] | Err[E]`) for expected failures with `.map()` / `.and_then()` chaining
- **Secondary:** Exceptions only for programmer errors, contract violations, or unavoidable third-party raises
- Wrap external failures in `Result` at system boundaries
- Error context via frozen dataclass with `field`, `value`, `constraint`, `context` attributes

---

## 5. Code Structure

```
src/{models,services,utils,config,core}/
tests/{unit/<mirrors src>,integration/}
```

- Functions: 100 lines max, extract on >1 decision branch or reused logic
- Use `match`/`case` over `if`/`elif` chains

---

## 6. Declarative Patterns

- Pydantic `BaseModel` with `frozen=True` for configs, `Field` constraints, `@field_validator`
- `Protocol` for interfaces (not ABCs)
- Hybrid controller: imperative guards + declarative `.and_then()` pipeline

---

## 7. Documentation

Google docstrings on all public functions/classes: one-line summary, `Args`, `Returns` (with `Ok`/`Err` cases), `Example` with doctests. `Raises` only for actual exceptions.

---

## 8. Testing

- 90% coverage required, 100% for critical paths
- Naming: `test_<func>_with_<condition>_returns_<outcome>()`
- Test `Result` pipelines: assert `.is_ok()` / `.is_err()`, check unwrapped values

---

## 9. ty Environment

ty auto-discovers: `VIRTUAL_ENV` env var -> `.venv` in project root -> `python3` in PATH.

All `uv` projects work automatically. For non-standard locations:
```toml
[tool.ty.environment]
python = "path/to/your/venv"
```

---

## 10. Tooling

| Tool | Config Key | Key Settings |
|------|-----------|-------------|
| ruff | `[tool.ruff]` | `line-length = 100`, `target-version = "py311"`, rules: E/W/F/I/N/UP/B/A/C4/DTZ/T10/RET/SIM |
| mypy | `[tool.mypy]` | `strict = true`, `python_version = "3.11"` |
| pytest | `[tool.pytest.ini_options]` | `--cov=src --cov-fail-under=90` |
| import-linter | `.importlinter` | No circular imports |
| pre-commit | `.pre-commit-config.yaml` | ruff (check+format), mypy --strict, import-linter |

---

## 11. CI Checklist

- mypy --strict: zero errors
- ruff check + format: clean
- pytest coverage >= 90%
- No circular imports
- All public APIs have Google docstrings with Examples
- Result types use `Ok[T] | Err[E]` with `.and_then()` / `.map()`
- No unqualified `Any`
- Import order: stdlib -> third-party -> local
- Naming conventions followed (verb prefixes, boolean prefixes, mutability suffixes)
- Function length < 100 lines
- Pydantic configs use `frozen=True`
