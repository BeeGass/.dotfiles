#!/bin/bash
# Post-edit formatter hook for Claude Code
# Runs appropriate formatter based on file extension

file="$1"

# Exit if no file provided
[ -z "$file" ] && exit 0

# Exit if file doesn't exist
[ ! -f "$file" ] && exit 0

case "$file" in
  *.py)
    # Python: ruff check + format
    ruff check "$file" --fix --quiet 2>/dev/null
    ruff format "$file" --quiet 2>/dev/null
    ;;
  *.rs)
    # Rust: rustfmt
    rustfmt "$file" 2>/dev/null
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.json)
    # TypeScript/JavaScript: prettier
    npx prettier --write "$file" 2>/dev/null
    ;;
  *.md)
    # Markdown: prettier
    npx prettier --write "$file" --prose-wrap=always 2>/dev/null
    ;;
esac

exit 0
