#!/bin/bash
# PostToolUse hook to log tool usage for later review
# Creates an audit trail of Claude's actions

LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/session-$(date +%Y-%m-%d).log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read input from stdin
input=$(cat)

# Extract relevant fields
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
tool_name=$(echo "$input" | jq -r '.tool_name // "unknown"')
cwd=$(echo "$input" | jq -r '.cwd // "unknown"')

# Get tool-specific info
case "$tool_name" in
  Edit|Write)
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // "unknown"')
    detail="file=$file_path"
    ;;
  Bash)
    command=$(echo "$input" | jq -r '.tool_input.command // "unknown"' | head -c 100)
    detail="cmd=$command"
    ;;
  Read)
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // "unknown"')
    detail="file=$file_path"
    ;;
  Glob|Grep)
    pattern=$(echo "$input" | jq -r '.tool_input.pattern // "unknown"')
    detail="pattern=$pattern"
    ;;
  *)
    detail=""
    ;;
esac

# Log entry
echo "[$timestamp] session=$session_id tool=$tool_name $detail" >> "$LOG_FILE"

# Rotate logs older than 30 days
find "$LOG_DIR" -name "session-*.log" -mtime +30 -delete 2>/dev/null

exit 0
