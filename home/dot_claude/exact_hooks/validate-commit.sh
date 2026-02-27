#!/bin/bash
# PreToolUse hook to validate git commit messages follow conventional commits
# Also validates branch naming conventions

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ "$tool_name" != "Bash" ] && exit 0
[ -z "$command" ] && exit 0

# Check for git commit commands
if [[ "$command" == *"git commit"* ]]; then
  # Extract commit message from -m flag
  # Handle both -m "message" and -m 'message'
  if [[ "$command" =~ -m[[:space:]]*[\"\']([^\"\']+)[\"\'] ]]; then
    msg="${BASH_REMATCH[1]}"

    # Conventional commit regex
    # type(optional-scope): description
    conventional_regex="^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)(\([a-zA-Z0-9_-]+\))?: .+"

    if ! [[ "$msg" =~ $conventional_regex ]]; then
      echo "BLOCKED: Commit message does not follow conventional commits format" >&2
      echo "" >&2
      echo "Expected format: type(scope): description" >&2
      echo "" >&2
      echo "Valid types:" >&2
      echo "  feat     - New feature" >&2
      echo "  fix      - Bug fix" >&2
      echo "  docs     - Documentation only" >&2
      echo "  style    - Formatting (no code change)" >&2
      echo "  refactor - Code restructuring" >&2
      echo "  perf     - Performance improvement" >&2
      echo "  test     - Adding/updating tests" >&2
      echo "  chore    - Maintenance tasks" >&2
      echo "  ci       - CI/CD changes" >&2
      echo "  build    - Build system changes" >&2
      echo "  revert   - Reverting changes" >&2
      echo "" >&2
      echo "Example: feat(auth): add OAuth2 login flow" >&2
      echo "Your message: $msg" >&2
      exit 2
    fi

    # Check subject line length (should be <= 50 chars for best practice)
    subject=$(echo "$msg" | head -n1)
    if [ ${#subject} -gt 72 ]; then
      echo "WARNING: Commit subject line is ${#subject} chars (recommended <= 50, max 72)" >&2
      # Don't block, just warn
    fi
  fi
fi

# Check for branch creation with invalid names
if [[ "$command" == *"git checkout -b"* ]] || [[ "$command" == *"git switch -c"* ]]; then
  # Extract branch name
  if [[ "$command" =~ (checkout[[:space:]]+-b|switch[[:space:]]+-c)[[:space:]]+([^[:space:]]+) ]]; then
    branch="${BASH_REMATCH[2]}"

    # Valid branch patterns
    branch_regex="^(feat|fix|refactor|docs|test|chore|ci|build|perf|revert)/[a-z0-9-]+$"

    # Allow main, master, develop, release branches
    if [[ "$branch" =~ ^(main|master|develop|release/.+|hotfix/.+)$ ]]; then
      exit 0
    fi

    if ! [[ "$branch" =~ $branch_regex ]]; then
      echo "BLOCKED: Branch name does not follow naming convention" >&2
      echo "" >&2
      echo "Expected format: type/short-description" >&2
      echo "Example: feat/add-oauth-login" >&2
      echo "Your branch: $branch" >&2
      exit 2
    fi
  fi
fi

exit 0
