#!/bin/bash
# Post-edit formatter hook for Claude Code
# Runs appropriate formatter based on file extension

# Read JSON from stdin (PostToolUse hooks receive JSON, not positional args)
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Exit if no file provided
[ -z "$file" ] && exit 0

# Exit if file doesn't exist
[ ! -f "$file" ] && exit 0

case "$file" in
  *.py)
    # Python: ruff check + format
    if command -v ruff &>/dev/null; then
      ruff check "$file" --fix --quiet
      ruff format "$file" --quiet
    else
      echo "WARNING: ruff not found, skipping Python formatting for $file" >&2
    fi
    ;;
  *.rs)
    # Rust: rustfmt
    if command -v rustfmt &>/dev/null; then
      rustfmt "$file"
    else
      echo "WARNING: rustfmt not found, skipping Rust formatting for $file" >&2
    fi
    ;;
  *.ts | *.tsx | *.js | *.jsx | *.json)
    # TypeScript/JavaScript: prettier
    if command -v npx &>/dev/null; then
      npx prettier --write "$file" --log-level warn
    else
      echo "WARNING: npx/prettier not found, skipping JS/TS formatting for $file" >&2
    fi
    ;;
  *.md)
    # Markdown: prettier
    if command -v npx &>/dev/null; then
      npx prettier --write "$file" --prose-wrap=always --log-level warn
    else
      echo "WARNING: npx/prettier not found, skipping Markdown formatting for $file" >&2
    fi
    ;;
esac

exit 0
