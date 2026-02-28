#!/bin/bash
# PostToolUse hook to track TODO/FIXME additions
# Warns when new TODOs are added without ticket references

file="$1"
[ -z "$file" ] && exit 0
[ ! -f "$file" ] && exit 0

# Only check code files
case "$file" in
  *.py | *.rs | *.ts | *.tsx | *.js | *.jsx | *.go | *.java | *.c | *.cpp | *.h) ;;
  *) exit 0 ;;
esac

# Find TODOs and FIXMEs in the file
todos=$(grep -n -E "(TODO|FIXME|HACK|XXX|BUG)" "$file" 2>/dev/null)

if [ -n "$todos" ]; then
  # Check for TODOs without ticket references (common formats: #123, JIRA-123, etc.)
  bad_todos=$(echo "$todos" | grep -v -E "(#[0-9]+|[A-Z]+-[0-9]+|\([a-zA-Z]+\))" || true)

  if [ -n "$bad_todos" ]; then
    echo "WARNING: Found TODO/FIXME comments without ticket references:" >&2
    echo "$bad_todos" | head -5 >&2
    echo "" >&2
    echo "Consider adding a ticket reference, e.g.:" >&2
    echo "  TODO(username): description" >&2
    echo "  TODO #123: description" >&2
    echo "  FIXME JIRA-456: description" >&2
    # Don't block, just warn
  fi
fi

exit 0
