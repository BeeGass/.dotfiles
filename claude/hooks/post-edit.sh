#!/bin/bash
RUST_BIN="$HOME/.dotfiles/claude/hooks-rs/target/release/claude-hooks"
if [[ -x "$RUST_BIN" ]]; then
    exec "$RUST_BIN" post-edit
else
    exec uv run --project "$HOME/.dotfiles/claude/hooks-py" claude-hooks post-edit
fi
