#!/bin/bash
# PreToolUse hook to warn when editing files on protected branches
# Encourages feature branch workflow

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# Only check Edit and Write operations
case "$tool_name" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

# Check if we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
  exit 0
fi

branch=$(git branch --show-current 2>/dev/null)

# Protected branch patterns
protected_branches=(
  "main"
  "master"
  "production"
  "prod"
  "release"
  "develop"
)

for protected in "${protected_branches[@]}"; do
  if [[ "$branch" == "$protected" ]]; then
    echo "WARNING: You are on '$branch' branch." >&2
    echo "Consider creating a feature branch: git checkout -b feature/your-feature" >&2
    echo "" >&2
    # Don't block, just warn
    break
  fi
done

exit 0
