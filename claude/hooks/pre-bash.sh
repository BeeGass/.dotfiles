#!/bin/bash
RUST_BIN="$HOME/.dotfiles/claude/hooks-rs/target/release/claude-hooks"
if [[ -x "$RUST_BIN" ]]; then
    exec "$RUST_BIN" pre-bash
else
    exec uv run --project "$HOME/.dotfiles/claude/hooks-py" claude-hooks pre-bash
fi
