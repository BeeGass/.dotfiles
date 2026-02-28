# Global Development Guidelines

## Hard Rules

- Never mention being an AI, Anthropic, or "Claude" in code, comments, or commits
- No emojis in code or comments
- Prioritize correctness and maintainability over cleverness

## Environment

- **Dotfiles**: `~/.dotfiles/` (managed by chezmoi; deployed to `~` via `chezmoi apply`)
- **Primary workstation**: `manifold` (192.168.68.10) - RTX 5090, 64GB, Ubuntu 25.10
- **Secondary workstation**: `tensor` (192.168.68.11) - RTX 3080, 32GB
- See `~/.claude/docs/hardware.md` for full homelab specs

## Code Search

- **Prefer ast-grep** for structural searches (function calls, imports, syntax patterns)
- **Use grep** for simple text searches or non-code files
- See `~/.claude/docs/ast-grep.md` for pattern syntax and examples

## Language Tooling

| Language | Formatter/Linter | Type Checker | Package Manager |
|----------|------------------|--------------|-----------------|
| Python 3.11+ | ruff | mypy --strict | uv |
| TypeScript | prettier + eslint | tsc (strict) | npm/pnpm |
| Rust | rustfmt + clippy | rustc | cargo |

## Python Style

- Use `Result[T, E]` types for error handling (see `python-style.md` for implementation)
- Type all functions with `| None` syntax (not `Optional`)
- Naming: `calc_*`, `fetch_*`, `parse_*` prefixes; `is_*`, `has_*`, `can_*` for booleans
- See `~/.claude/docs/python-style.md` for comprehensive Python conventions

## ML Stack (JAX Ecosystem)

- **Neural networks**: Flax NNX (not Linen)
- **Optimization**: Optax
- **Checkpointing**: Orbax
- **Data loading**: Grain
- **Config**: Fiddle
- Use jaxtyping for array annotations: `Float[Array, "batch seq_len d_model"]`
- See `~/.claude/docs/jax-ml.md` for detailed patterns

## Verification

Before committing, run project-specific checks:

- **Python**: `uv run ruff check . && uv run ruff format . && uv run mypy . --strict`
- **Rust**: `cargo fmt && cargo clippy && cargo test`
- **TypeScript**: `npm run lint && npm run typecheck && npm run test`

## Reference Docs

- `~/.claude/docs/code-quality.md` - General principles, function extraction
- `~/.claude/docs/python-style.md` - Comprehensive Python style (types, Result, patterns)
- `~/.claude/docs/jax-ml.md` - JAX/Flax/NNX conventions, sharding, safety checks
- `~/.claude/docs/security.md` - OWASP, secure coding patterns
- `~/.claude/docs/testing.md` - Testing philosophy, frameworks
- `~/.claude/docs/documentation.md` - Code comments, docstrings, README guidelines
- `~/.claude/docs/git-workflow.md` - Conventional commits, branch naming
