#!/bin/bash
# PreToolUse hook to block dangerous bash commands
# Prevents accidental destructive operations

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ "$tool_name" != "Bash" ] && exit 0
[ -z "$command" ] && exit 0

# Dangerous patterns to block
dangerous_patterns=(
  # Destructive file operations
  "rm -rf /"
  "rm -rf /*"
  "rm -rf ~"
  "rm -rf ~/*"
  "rm -rf \$HOME"
  "rm -rf ."
  "rm -rf .."
  "rm -rf ./*"

  # System destruction
  "mkfs"
  "dd if=.* of=/dev/"
  "> /dev/sd"
  "chmod -R 777 /"
  "chown -R .* /"

  # Fork bombs and resource exhaustion
  ":(){ :|:& };:"
  "fork while fork"

  # History/credential manipulation
  "history -c"
  "shred.*history"
  "shred.*bash_history"

  # Network attacks (if somehow attempted)
  "nmap -sS"
  "hping3"

  # Git force operations on protected branches
  "git push.*--force.*main"
  "git push.*--force.*master"
  "git push.*-f.*main"
  "git push.*-f.*master"
  "git reset --hard.*origin/main"
  "git reset --hard.*origin/master"
)

for pattern in "${dangerous_patterns[@]}"; do
  if [[ "$command" =~ $pattern ]]; then
    echo "BLOCKED: Potentially dangerous command detected" >&2
    echo "Pattern matched: $pattern" >&2
    echo "Command: $command" >&2
    echo "" >&2
    echo "If you really need to run this command, please do so manually." >&2
    exit 2
  fi
done

# Warn about rm -rf with variables (could expand unexpectedly)
if [[ "$command" =~ rm[[:space:]]+-rf?[[:space:]]+.*\$ ]]; then
  echo "WARNING: rm -rf with variable expansion detected" >&2
  echo "Command: $command" >&2
  echo "Ensure the variable is set correctly before proceeding." >&2
  # Don't block, but warn
fi

# Warn about sudo usage
if [[ "$command" =~ ^sudo[[:space:]] ]]; then
  echo "WARNING: sudo command detected - will require manual approval" >&2
fi

exit 0
