#!/bin/bash
# Post-edit type checker for Python, TypeScript, and Rust
# Provides immediate type error feedback to Claude

file="$1"
[ -z "$file" ] && exit 0
[ ! -f "$file" ] && exit 0

case "$file" in
  *.py)
    # Python: mypy with strict mode
    errors=$(mypy "$file" --strict --no-error-summary --no-color 2>&1)
    if [ $? -ne 0 ]; then
      echo "mypy errors in $file:" >&2
      echo "$errors" >&2
      exit 2
    fi
    ;;
  *.ts|*.tsx)
    # TypeScript: tsc with noEmit
    dir=$(dirname "$file")
    # Find tsconfig.json in parent directories
    tsconfig=""
    search_dir="$dir"
    while [ "$search_dir" != "/" ]; do
      if [ -f "$search_dir/tsconfig.json" ]; then
        tsconfig="$search_dir/tsconfig.json"
        break
      fi
      search_dir=$(dirname "$search_dir")
    done

    if [ -n "$tsconfig" ]; then
      errors=$(npx tsc --noEmit --project "$tsconfig" 2>&1 | grep -E "^$file")
      if [ -n "$errors" ]; then
        echo "TypeScript errors in $file:" >&2
        echo "$errors" >&2
        exit 2
      fi
    fi
    ;;
  *.rs)
    # Rust: clippy for the file's crate
    dir=$(dirname "$file")
    # Find Cargo.toml in parent directories
    cargo_dir=""
    search_dir="$dir"
    while [ "$search_dir" != "/" ]; do
      if [ -f "$search_dir/Cargo.toml" ]; then
        cargo_dir="$search_dir"
        break
      fi
      search_dir=$(dirname "$search_dir")
    done

    if [ -n "$cargo_dir" ]; then
      errors=$(cd "$cargo_dir" && cargo clippy --message-format=short 2>&1 | grep -E "^error" | head -10)
      if [ -n "$errors" ]; then
        echo "Clippy errors:" >&2
        echo "$errors" >&2
        exit 2
      fi
    fi
    ;;
esac

exit 0
