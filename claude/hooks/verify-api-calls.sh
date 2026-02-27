#!/bin/bash
# PreToolUse hook to suggest verifying API calls with Context7
# Helps prevent hallucinated function calls for complex/evolving libraries

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

case "$tool_name" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only check Python files
case "$file_path" in
  *.py) ;;
  *) exit 0 ;;
esac

# Libraries where API verification is especially valuable
# These have complex/evolving APIs where hallucination is more likely
VERIFY_LIBS=(
  # JAX ecosystem
  "jax"
  "jax.numpy"
  "jax.lax"
  "jax.random"
  "jax.nn"
  "flax.nnx"
  "flax.linen"
  "optax"
  "orbax"
  "orbax.checkpoint"
  "jaxtyping"
  "grain"
  "chex"
  "equinox"
  "fiddle"
  # ML/AI libraries
  "langchain"
  "transformers"
  "anthropic"
  "openai"
)

# Function to get common aliases for a library
get_aliases() {
  local lib="$1"
  case "$lib" in
    "jax.numpy")  echo "jnp" ;;
    "jax.lax")    echo "lax" ;;
    "jax.random") echo "jr|jrand|random" ;;
    "jax.nn")     echo "jnn" ;;
    "flax.nnx")   echo "nnx" ;;
    "flax.linen") echo "nn" ;;
    "equinox")    echo "eqx" ;;
    "fiddle")     echo "fdl" ;;
    *)            echo "" ;;
  esac
}

# Check if code imports any of these libraries
warnings=""
for lib in "${VERIFY_LIBS[@]}"; do
  # Escape dots for regex
  lib_pattern=$(echo "$lib" | sed 's/\./\\./g')

  # Get base name (last part after dot, or whole name if no dot)
  base_name=$(echo "$lib" | sed 's/.*\.//')

  # Build import patterns to check
  # Pattern 1: "from flax.nnx import" or "import flax.nnx"
  # Pattern 2: "from flax import nnx" (for dotted libs like flax.nnx)
  import_found=false

  if echo "$content" | grep -qE "(from ${lib_pattern}|import ${lib_pattern})"; then
    import_found=true
  fi

  # For dotted libraries, also check "from parent import child" style
  if [[ "$lib" == *.* ]]; then
    parent=$(echo "$lib" | sed 's/\.[^.]*$//')
    parent_pattern=$(echo "$parent" | sed 's/\./\\./g')
    if echo "$content" | grep -qE "from ${parent_pattern} import.*\\b${base_name}\\b"; then
      import_found=true
    fi
  fi

  if [ "$import_found" = true ]; then
    # Check for function/method calls to this library
    # Look for patterns like: nnx.Linear, optax.adam, etc.
    # Also check common aliases (e.g., jnp for jax.numpy)

    # Build pattern: base_name OR known aliases
    call_pattern="${base_name}"
    aliases=$(get_aliases "$lib")
    if [[ -n "$aliases" ]]; then
      call_pattern="${base_name}|${aliases}"
    fi

    if echo "$content" | grep -qE "(${call_pattern})\.[a-zA-Z_]+\(" 2>/dev/null; then
      warnings+="$lib "
    fi
  fi
done

if [ -n "$warnings" ]; then
  echo "NOTE: Code uses APIs from: $warnings" >&2
  echo "These libraries have complex/evolving APIs. Consider verifying function signatures with Context7 MCP if unsure." >&2
fi

exit 0
