#!/bin/bash
# PreToolUse hook to warn about large file operations
# Prevents accidentally creating huge files

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

case "$tool_name" in
  Write)
    content=$(echo "$input" | jq -r '.tool_input.content // empty')
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

    # Check content size (in bytes)
    content_size=${#content}

    # Warn if content is larger than 100KB
    if [ "$content_size" -gt 102400 ]; then
      size_kb=$((content_size / 1024))
      echo "WARNING: Large file write detected" >&2
      echo "File: $file_path" >&2
      echo "Size: ${size_kb}KB" >&2
      echo "" >&2
      echo "Consider:" >&2
      echo "  - Breaking into smaller files" >&2
      echo "  - Using external data storage" >&2
      echo "  - Generating programmatically instead of hardcoding" >&2
      # Don't block, just warn
    fi

    # Block if content is larger than 1MB (likely a mistake)
    if [ "$content_size" -gt 1048576 ]; then
      size_mb=$((content_size / 1048576))
      echo "BLOCKED: File content too large (${size_mb}MB)" >&2
      echo "This is likely a mistake. If intentional, write manually." >&2
      exit 2
    fi

    # Check for binary-looking content (high ratio of non-printable chars)
    non_printable=$(echo "$content" | tr -d '[:print:][:space:]' | wc -c)
    total=${#content}
    if [ "$total" -gt 1000 ]; then
      ratio=$((non_printable * 100 / total))
      if [ "$ratio" -gt 20 ]; then
        echo "WARNING: Content appears to contain binary data (${ratio}% non-printable)" >&2
        echo "File: $file_path" >&2
      fi
    fi
    ;;

  Edit)
    new_string=$(echo "$input" | jq -r '.tool_input.new_string // empty')
    new_size=${#new_string}

    # Warn if replacement is very large
    if [ "$new_size" -gt 51200 ]; then
      size_kb=$((new_size / 1024))
      echo "WARNING: Large edit detected (${size_kb}KB replacement)" >&2
      echo "Consider breaking into smaller edits." >&2
    fi
    ;;
esac

exit 0
