---
description: Formatter, linter, type checker, and package manager for each language
---

# Language Tooling

| Language | Formatter/Linter | Type Checker | Package Manager |
|----------|------------------|--------------|-----------------|
| Python 3.11+ | ruff | mypy --strict | uv |
| TypeScript | prettier + eslint | tsc (strict) | npm/pnpm |
| Rust | rustfmt + clippy | rustc | cargo |

## Verification

Before committing, run project-specific checks:
- **Python**: `uv run ruff check . && uv run ruff format . && uv run mypy . --strict`
- **Rust**: `cargo fmt && cargo clippy && cargo test`
- **TypeScript**: `npm run lint && npm run typecheck && npm run test`
