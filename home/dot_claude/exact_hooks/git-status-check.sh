#!/bin/bash
# PreToolUse hook to warn about uncommitted changes before major edits
# Helps prevent losing work

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Only check for Edit/Write operations
case "$tool_name" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

[ -z "$file_path" ] && exit 0

# Find git root
git_root=$(cd "$(dirname "$file_path")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
[ -z "$git_root" ] && exit 0  # Not a git repo

# Check if the specific file has uncommitted changes
if [ -f "$file_path" ]; then
  file_status=$(cd "$git_root" && git status --porcelain "$file_path" 2>/dev/null)

  if [ -n "$file_status" ]; then
    status_code="${file_status:0:2}"
    case "$status_code" in
      " M"|"MM"|"AM")
        echo "WARNING: File has uncommitted modifications" >&2
        echo "File: $file_path" >&2
        echo "Consider committing or stashing changes first." >&2
        ;;
      "??")
        # Untracked file, that's fine
        ;;
      *)
        echo "WARNING: File has uncommitted changes (status: $status_code)" >&2
        echo "File: $file_path" >&2
        ;;
    esac
  fi
fi

# Check overall repo status for large operations
total_changes=$(cd "$git_root" && git status --porcelain 2>/dev/null | wc -l)
if [ "$total_changes" -gt 20 ]; then
  echo "NOTE: Repository has $total_changes uncommitted changes" >&2
  echo "Consider committing or stashing before making more changes." >&2
fi

exit 0
