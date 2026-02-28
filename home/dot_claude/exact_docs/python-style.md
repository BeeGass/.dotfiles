# Python Style Guide

Comprehensive Python conventions. For JAX/Flax specifics, see `jax-ml.md`.

## 1. Type System

**Rules:**

- `mypy --strict` enforced in pre-commit
- All functions typed: parameters, return values, no `Any` without justification
- Use `| None` for optionals (not `Optional`)
- Generic types fully specified: `list[dict[str, int | float]]` not `list[dict]`
- Custom `Result[T, E]` type for error handling (see Error Handling section)

**Example:**

```python
def calculate_price(
    items: list[dict[str, int | float]],
    discount: float,
    user: User | None = None,
) -> Result[Decimal, PricingError]:
    """Calculate total with discount and user-specific rules."""
    ...
```

**mypy.ini:**

```ini
[mypy]
python_version = 3.11
strict = True
warn_return_any = True
warn_unused_configs = True
disallow_untyped_defs = True
disallow_any_explicit = False  # Allow explicit Any with comment
```

---

## 2. Naming Conventions

**Functions:**

- Abbreviated + verb prefixes: `calc_total`, `fetch_user`, `parse_config`
- Prefix verbs: `get_*` (pure access), `fetch_*` (I/O), `calc_*` (computation), `parse_*`, `validate_*`
- Boolean checks: `is_valid`, `has_permission`, `can_edit`

**Classes:**

- Mutability-aware:
  - Immutable: `User`, `Config`, `TrainingState`
  - Mutable: `UserBuilder`, `ConfigLoader`, `StateManager`
  - DTOs/models: plain nouns `UserProfile`, `TrainingMetrics`

**Booleans:**

- State: `is_active`, `has_data`, `enabled`
- Capabilities: `can_retry`, `should_validate`, `may_override`

**Examples:**

```python
# Good
def calc_discount(price: Decimal, user: User) -> Decimal: ...
def fetch_orders(user_id: int) -> Result[list[Order], DBError]: ...

class User:  # immutable
    name: str
    is_admin: bool
    can_edit: bool

class UserBuilder:  # mutable
    def add_role(self, role: str) -> UserBuilder: ...

# Bad
def calculate_discount_for_user(...): ...  # too verbose
def get_orders(...): ...  # ambiguous: pure or I/O?
class UserData: ...  # unclear mutability
```

---

## 3. Import Organization

**Order:**

1. Standard library (grouped by category)
2. Third-party libraries (alphabetical)
3. Blank line
4. Local imports (absolute, alphabetical)

**Template:**

```python
# Standard library - by category
import logging
from collections.abc import Callable, Sequence
from contextlib import contextmanager
from pathlib import Path
from typing import Any

# Third-party - alphabetical
import jax
import jax.numpy as jnp
import structlog
from flax import nnx
from jax.sharding import Mesh, NamedSharding, PartitionSpec
from pydantic import BaseModel, Field

# Local - absolute paths, alphabetical
from config.training.distributed import DistributedConfig, DistributedStrategy
from core.errors import ValidationError
from core.result import Err, Ok, Result
from models.user import User
```

**Rules:**

- Explicit imports: `from module import Class1, func1` (no wildcards)
- Namespace for deep APIs: `import jax.numpy as jnp`
- Group local imports by top-level module
- **Ban: circular imports** (enforced via import-linter)

---

## 4. Error Handling

**Strategy:**

- **Primary:** `Result[T, E]` types for expected failures
- **Secondary:** Exceptions for unexpected/catastrophic errors only

**Result Type Implementation:**

```python
# core/result.py
from dataclasses import dataclass
from typing import Callable, Generic, TypeVar

T = TypeVar("T")
E = TypeVar("E")
U = TypeVar("U")

@dataclass(frozen=True)
class Ok(Generic[T]):
    value: T

    def is_ok(self) -> bool:
        return True

    def is_err(self) -> bool:
        return False

    def map(self, func: Callable[[T], U]) -> "Result[U, E]":
        return Ok(func(self.value))

    def and_then(self, func: Callable[[T], "Result[U, E]"]) -> "Result[U, E]":
        return func(self.value)

    def unwrap(self) -> T:
        return self.value

    def unwrap_or(self, default: T) -> T:
        return self.value

    def unwrap_or_else(self, func: Callable[[E], T]) -> T:
        return self.value

@dataclass(frozen=True)
class Err(Generic[E]):
    error: E

    def is_ok(self) -> bool:
        return False

    def is_err(self) -> bool:
        return True

    def map(self, func: Callable[[T], U]) -> "Result[U, E]":
        return self  # type: ignore

    def and_then(self, func: Callable[[T], "Result[U, E]"]) -> "Result[U, E]":
        return self  # type: ignore

    def unwrap(self) -> T:
        raise ValueError(f"Called unwrap on Err: {self.error}")

    def unwrap_or(self, default: T) -> T:
        return default

    def unwrap_or_else(self, func: Callable[[E], T]) -> T:
        return func(self.error)

Result = Ok[T] | Err[E]
```

**Error Context:**

```python
from dataclasses import dataclass, field
from typing import Any

@dataclass(frozen=True)
class ValidationError:
    """Structured validation error with context."""
    field: str
    value: Any
    constraint: str
    context: dict[str, Any] = field(default_factory=dict)

    def __str__(self) -> str:
        return f"ValidationError(field={self.field}, constraint={self.constraint})"

# Usage
def validate_user_id(user_id: int, request_id: str) -> Result[int, ValidationError]:
    if user_id <= 0:
        return Err(
            ValidationError(
                field="user_id",
                value=user_id,
                constraint="Must be positive integer",
                context={"request_id": request_id},
            )
        )
    return Ok(user_id)
```

**When to use exceptions:**

- Programmer errors: `AssertionError`, `TypeError`, `ValueError` for contract violations
- External failures: network timeouts, file not found (wrap in Result at boundary)
- Library integration: when third-party raises exceptions unavoidably

---

## 5. Code Structure

**File Organization:**

```
src/
    models/          # Data models, entities
    services/        # Business logic, orchestration
    utils/           # Pure utilities, helpers
    config/          # Configuration schemas
    core/            # Shared primitives (Result, errors, protocols)
tests/
    unit/            # Mirror src/ structure
        models/
        services/
        utils/
    integration/     # Cross-module tests
        api/
```

**Function Length:**

- **Guideline:** 100 lines max
- **True constraint:** complexity (cyclomatic, cognitive)
- Extract when: >1 decision branch, reused logic, domain rules, testability

**Example - Extract Branches:**

```python
# Before: multiple branches inline
def process_request(request: Request) -> Result[Response, Error]:
    if request.type == "order":
        # 15 lines of order logic
        ...
    elif request.type == "refund":
        # 12 lines of refund logic
        ...

# After: extract branches
def process_request(request: Request) -> Result[Response, Error]:
    match request.type:
        case "order":
            result = handle_order(request)
        case "refund":
            result = handle_refund(request)
        case _:
            return Err(UnknownTypeError(request.type))

    return result.map(format_response)
```

---

## 6. Declarative Patterns

**Pydantic for Configuration:**

```python
from pydantic import BaseModel, Field, field_validator

class TrainingConfig(BaseModel):
    """Training hyperparameters with validation."""
    learning_rate: float = Field(gt=0, le=1.0, description="Learning rate")
    batch_size: int = Field(gt=0, description="Batch size")
    max_steps: int = Field(gt=0, description="Maximum training steps")

    model_config = {"frozen": True}  # Immutable after creation

    @field_validator("batch_size")
    @classmethod
    def batch_size_power_of_two(cls, v: int) -> int:
        if v & (v - 1) != 0:
            raise ValueError(f"batch_size must be power of 2, got {v}")
        return v
```

**Protocol-based Declarative Logic:**

```python
from typing import Protocol

class TrainingStep(Protocol):
    """Protocol for declarative training step."""

    def execute(self, state: TrainState) -> Result[TrainState, StepError]:
        """Execute step and return updated state."""
        ...

def run_training(
    initial_state: TrainState,
    steps: Sequence[TrainingStep],
) -> Result[TrainState, StepError]:
    """Execute training steps sequentially."""
    state = initial_state
    for step in steps:
        result = step.execute(state)
        if result.is_err():
            return result
        state = result.unwrap()
    return Ok(state)
```

**Hybrid Controller Pattern:**

```python
def handle_user_request(request: Request) -> Result[Response, Error]:
    """Handle request with validation and business logic.

    Hybrid pattern: imperative guards + declarative pipeline.
    """
    # Imperative validation guards
    validation = validate_request(request)
    if validation.is_err():
        return validation.map(lambda _: Response())

    # Declarative business logic
    result = (
        fetch_user(request.user_id)
        .and_then(lambda u: check_permissions(u, request.action))
        .and_then(lambda u: execute_action(u, request))
    )

    return result.map(format_success_response)
```

---

## 7. Documentation

**Google Docstrings with Examples:**

All public functions/classes require:

1. One-line summary
2. Args section with type info and constraints
3. Returns section with success/error cases
4. Example section with doctests
5. Raises section (only for exceptions, not Result errors)

**Template:**

```python
def calc_discounted_price(
    base_price: Decimal,
    discount_rate: float,
    user: User | None = None,
) -> Result[Decimal, PricingError]:
    """Calculate final price after discount and user-specific adjustments.

    Applies discount rate, then user loyalty bonus if applicable.

    Args:
        base_price: Original price before discounts. Must be positive.
        discount_rate: Discount fraction in range [0.0, 1.0].
        user: Optional user for loyalty discounts. None for guest users.

    Returns:
        Ok with final price rounded to 2 decimals, or Err with:
        - InvalidPriceError if base_price <= 0
        - InvalidDiscountError if discount_rate out of range

    Example:
        >>> calc_discounted_price(Decimal("100.00"), 0.1, None)
        Ok(value=Decimal('90.00'))
        >>> calc_discounted_price(Decimal("-10"), 0.1, None)
        Err(error=InvalidPriceError(...))
    """
    ...
```

---

## 8. Testing

**Coverage:** 90% required, 100% for critical paths (payment, auth, data loss)

**Organization:** Hybrid by type + structure

```
tests/
    unit/
        models/
            test_user.py
        services/
            test_pricing.py
    integration/
        api/
            test_user_flow.py
```

**Test Naming:**

```python
def test_calc_discount_with_valid_inputs_returns_discounted_price():
    """Test discount calculation with standard inputs."""
    ...

def test_calc_discount_with_negative_price_returns_error():
    """Test error handling for invalid price input."""
    ...
```

**Fixtures for Result Types:**

```python
import pytest
from core.result import Err, Ok, Result

@pytest.fixture
def valid_user() -> User:
    return User(id=1, name="Test", loyalty=0.05)

def test_pricing_pipeline_success(valid_user: User):
    """Test full pricing pipeline with valid inputs."""
    result = (
        validate_price(Decimal("100"))
        .and_then(lambda p: calc_discount(p, 0.1))
        .and_then(lambda p: apply_loyalty(p, valid_user))
    )

    assert result.is_ok()
    assert result.unwrap() == Decimal("85.50")

def test_pricing_pipeline_invalid_price():
    """Test pipeline fails fast on invalid input."""
    result = (
        validate_price(Decimal("-10"))
        .and_then(lambda p: calc_discount(p, 0.1))
    )

    assert result.is_err()
    error = result.unwrap_or_else(lambda e: e)
    assert isinstance(error, InvalidPriceError)
```

---

## 9. Tooling Configuration

**pyproject.toml:**

```toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = [
    "E",   # pycodestyle errors
    "W",   # pycodestyle warnings
    "F",   # pyflakes
    "I",   # isort
    "N",   # pep8-naming
    "UP",  # pyupgrade
    "B",   # flake8-bugbear
    "A",   # flake8-builtins
    "C4",  # flake8-comprehensions
    "DTZ", # flake8-datetimez
    "T10", # flake8-debugger
    "RET", # flake8-return
    "SIM", # flake8-simplify
]
ignore = [
    "E501",  # Line too long (handled by formatter)
]

[tool.ruff.lint.isort]
known-first-party = ["config", "core", "models", "services", "utils"]
section-order = ["future", "standard-library", "third-party", "first-party", "local-folder"]

[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unused_configs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = "--cov=src --cov-report=term-missing --cov-fail-under=90"

[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/conftest.py"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
    "if __name__ == .__main__.:",
    "if TYPE_CHECKING:",
]
```

**.pre-commit-config.yaml:**

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.9
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.8.0
    hooks:
      - id: mypy
        additional_dependencies: [pydantic, jax]
        args: [--strict]

  - repo: local
    hooks:
      - id: import-linter
        name: import-linter
        entry: lint-imports
        language: system
        pass_filenames: false
```

**.importlinter:**

```ini
[importlinter]
root_package = src

[importlinter:contract:no-cycles]
name = No circular imports
type = forbidden
source_modules =
    src
forbidden_modules =
    src
```

---

## 10. CI Linter Checklist

```
[ ] mypy --strict passes with zero errors
[ ] ruff check passes (all rules enabled)
[ ] ruff format check passes (no formatting changes)
[ ] pytest coverage >= 90%
[ ] import-linter finds no circular imports
[ ] All public functions have Google docstrings with Examples section
[ ] All Result types use Ok[T] | Err[E] pattern with .and_then()/.map()
[ ] No Any types without # type: ignore[explicit-any] comment
[ ] Import blocks follow: stdlib -> third-party -> blank -> local
[ ] Boolean variables use is_/has_/can_/should_ prefixes
[ ] Functions use abbreviated verb prefixes (calc_, fetch_, parse_)
[ ] Classes use mutability suffixes (Builder, Manager) or plain nouns
[ ] No wildcard imports (from x import *)
[ ] Function length <100 lines or justified by single responsibility
[ ] Pydantic models use frozen=True for immutable configs
[ ] Error context uses dataclass with field/value/constraint/context
```
