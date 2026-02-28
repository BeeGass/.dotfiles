#!/bin/bash
# PreToolUse hook to prevent edits to sensitive files
# Reads JSON from stdin, blocks dangerous file operations

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only check Edit and Write operations
case "$tool_name" in
  Edit | Write) ;;
  *) exit 0 ;;
esac

[ -z "$file_path" ] && exit 0

# Protected file patterns
protected_patterns=(
  # Secrets and credentials
  "*.env"
  "*.env.*"
  "*/.env"
  "*/.env.*"
  "*credentials*"
  "*secrets*"
  "*.pem"
  "*.key"
  "*.crt"
  "*id_rsa*"
  "*id_ed25519*"

  # Git internals
  ".git/*"
  "*/.git/*"

  # Package locks (usually auto-generated)
  "package-lock.json"
  "yarn.lock"
  "Cargo.lock"
  "uv.lock"
  "poetry.lock"

  # IDE/editor configs (user preference)
  ".vscode/settings.json"
  ".idea/*"
)

# Check against each pattern
for pattern in "${protected_patterns[@]}"; do
  case "$file_path" in
    $pattern)
      echo "BLOCKED: Cannot modify protected file: $file_path" >&2
      echo "Pattern matched: $pattern" >&2
      echo "If you need to modify this file, please do so manually." >&2
      exit 2
      ;;
  esac
done

# Warn about potential secrets in file content (for Write operations)
if [ "$tool_name" = "Write" ]; then
  content=$(echo "$input" | jq -r '.tool_input.content // empty')

  # Check for potential secrets in content
  secret_patterns=(
    "AKIA[0-9A-Z]{16}"                           # AWS Access Key ID
    "sk-[a-zA-Z0-9]{48}"                         # OpenAI API Key
    "sk-proj-[a-zA-Z0-9-]{80,}"                  # OpenAI Project Key
    "ghp_[a-zA-Z0-9]{36}"                        # GitHub PAT
    "gho_[a-zA-Z0-9]{36}"                        # GitHub OAuth
    "github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}" # GitHub Fine-grained PAT
    "xox[baprs]-[a-zA-Z0-9-]+"                   # Slack tokens
    "sk_live_[a-zA-Z0-9]+"                       # Stripe live key
    "rk_live_[a-zA-Z0-9]+"                       # Stripe restricted key
  )

  for pattern in "${secret_patterns[@]}"; do
    if echo "$content" | grep -qE "$pattern"; then
      echo "BLOCKED: Potential secret/API key detected in file content" >&2
      echo "Pattern: $pattern" >&2
      echo "Please use environment variables or a secrets manager instead." >&2
      exit 2
    fi
  done
fi

exit 0
