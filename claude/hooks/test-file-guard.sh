#!/bin/bash
# PreToolUse hook to track test file edits and remind to run tests
# Helps ensure tests are run after modifying test files

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only check Edit and Write operations
case "$tool_name" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

[ -z "$file_path" ] && exit 0

# Check if this is a test file
is_test_file=false
case "$file_path" in
  *test_*.py|*_test.py|*/tests/*.py|*Test.java|*Test.ts|*Test.tsx|*.test.ts|*.test.tsx|*.test.js|*.spec.ts|*.spec.js)
    is_test_file=true
    ;;
esac

if [ "$is_test_file" = true ]; then
  # Track the edit in a temp file for session awareness
  tracking_file="/tmp/claude_test_edits_$$"
  echo "$file_path" >> "$tracking_file"

  # Count how many test files edited this session
  if [ -f "$tracking_file" ]; then
    count=$(sort -u "$tracking_file" | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
      echo "NOTE: Editing test file. Remember to run tests before committing." >&2
      echo "Test files modified this session: $count" >&2
    fi
  fi
fi

exit 0
