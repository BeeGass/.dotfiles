#!/bin/bash
# Hook to detect package mentions and suggest Context7 documentation lookup
# Triggers on UserPromptSubmit and PreToolUse (Write/Edit)

# This hook works in two modes:
# 1. UserPromptSubmit: Detects packages in prompts and suggests using Context7
# 2. PreToolUse: Detects imports in code being written and suggests docs

input=$(cat)
hook_event=$(echo "$input" | jq -r '.hook_event_name // empty')

# Package watchlist - add your packages here
# Format: "import_pattern:context7_id" (context7_id can be empty for auto-resolve)
declare -A PACKAGE_MAP=(
  # JAX Ecosystem
  ["jax"]="jax"
  ["jax.numpy"]="jax"
  ["jnp"]="jax"
  ["flax"]="flax"
  ["flax.nnx"]="flax"
  ["nnx"]="flax"
  ["optax"]="optax"
  ["orbax"]="orbax"
  ["grain"]="grain"
  ["jaxtyping"]="jaxtyping"
  ["chex"]="chex"
  ["equinox"]="equinox"
  ["fiddle"]="fiddle"

  # Other common packages
  ["pydantic"]="pydantic"
  ["fastapi"]="fastapi"
  ["pytest"]="pytest"
  ["numpy"]="numpy"
  ["pandas"]="pandas"
  ["transformers"]="transformers"
  ["torch"]="pytorch"
  ["tensorflow"]="tensorflow"
  ["langchain"]="langchain"
  ["openai"]="openai"
  ["anthropic"]="anthropic"
  ["httpx"]="httpx"
  ["aiohttp"]="aiohttp"
  ["sqlalchemy"]="sqlalchemy"
  ["alembic"]="alembic"
  ["celery"]="celery"
  ["redis"]="redis"
  ["docker"]="docker"
  ["kubernetes"]="kubernetes"
)

# Function to detect packages in text
detect_packages() {
  local text="$1"
  local detected=()

  for pkg in "${!PACKAGE_MAP[@]}"; do
    # Check for import statements or package mentions
    if echo "$text" | grep -qiE "(import\s+$pkg|from\s+$pkg|$pkg\.|\"$pkg\"|'$pkg'|\b$pkg\b)"; then
      detected+=("$pkg")
    fi
  done

  # Deduplicate and return
  printf '%s\n' "${detected[@]}" | sort -u
}

# Function to build context7 suggestion
build_suggestion() {
  local packages=("$@")
  local suggestion=""

  if [ ${#packages[@]} -gt 0 ]; then
    suggestion="DOCUMENTATION HINT: The following packages were detected: ${packages[*]}. "
    suggestion+="For up-to-date documentation, use Context7 MCP server with: "
    suggestion+="1) resolve-library-id to get the library ID, then "
    suggestion+="2) get-library-docs to fetch current documentation. "
    suggestion+="This ensures you have the latest API information."

    # Add specific Context7 IDs if known
    local known_ids=()
    for pkg in "${packages[@]}"; do
      local ctx_id="${PACKAGE_MAP[$pkg]}"
      if [ -n "$ctx_id" ]; then
        known_ids+=("$pkg -> $ctx_id")
      fi
    done

    if [ ${#known_ids[@]} -gt 0 ]; then
      suggestion+=" Known Context7 IDs: ${known_ids[*]}."
    fi
  fi

  echo "$suggestion"
}

case "$hook_event" in
  UserPromptSubmit)
    prompt=$(echo "$input" | jq -r '.prompt // empty')

    # Skip if user already mentioned context7
    if echo "$prompt" | grep -qi "context7\|use context7"; then
      exit 0
    fi

    # Detect packages in prompt
    mapfile -t detected < <(detect_packages "$prompt")

    if [ ${#detected[@]} -gt 0 ]; then
      suggestion=$(build_suggestion "${detected[@]}")
      # Return as additionalContext
      jq -n --arg ctx "$suggestion" '{"additionalContext": $ctx}'
    fi
    ;;

  PreToolUse)
    tool_name=$(echo "$input" | jq -r '.tool_name // empty')

    # Only check Write/Edit operations
    case "$tool_name" in
      Write | Edit) ;;
      *) exit 0 ;;
    esac

    # Get the content being written
    content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

    # Only check Python files
    case "$file_path" in
      *.py) ;;
      *) exit 0 ;;
    esac

    # Detect packages in content
    mapfile -t detected < <(detect_packages "$content")

    if [ ${#detected[@]} -gt 0 ]; then
      suggestion=$(build_suggestion "${detected[@]}")
      echo "NOTE: $suggestion" >&2
    fi
    ;;
esac

exit 0
