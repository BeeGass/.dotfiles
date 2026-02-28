# Code Quality - General Principles

Language-agnostic principles. See language-specific guides for detailed conventions:

- `python-style.md` - Comprehensive Python style guide
- `jax-ml.md` - JAX/Flax/NNX conventions

## Core Principles

- **DRY (Don't Repeat Yourself)**: Extract repeated logic into reusable functions/modules
- **SOLID principles**: Apply when designing classes and modules
- **Single Responsibility**: Each function/class should have one clear purpose
- **Fail fast**: Validate inputs early and return/throw errors immediately
- **Immutability**: Prefer immutable data structures where appropriate
- **Composition over inheritance**: Favor functional composition and traits/interfaces

## Error Handling

- **Never silently fail**: Always handle or propagate errors explicitly
- **Use type-safe error handling**: Result types (Rust/Python), exceptions with proper types
- **Provide context**: Error messages should include what failed and why
- **Log appropriately**: Use proper log levels (error, warn, info, debug)
- **Clean up resources**: Use RAII (Rust), context managers (Python), try-finally (JS/TS)

## Code Organization

- **Clear module boundaries**: Well-defined interfaces between modules
- **Logical file structure**: Group related functionality together
- **Avoid circular dependencies**: Design modules to have clear dependency hierarchies
- **Keep functions focused**: Single responsibility, extract when complexity grows

## Function Extraction Priority

Extract when:

1. **Multiple decision branches** - Extract each branch
2. **Domain logic** (business rules, calculations) - Always extract
3. **Reused code** - Extract to utility
4. **Testability** (mocking needed) - Extract I/O boundary
5. **Complexity** (cyclomatic, cognitive) - Not just length
