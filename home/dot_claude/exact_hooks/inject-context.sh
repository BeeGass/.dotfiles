#!/bin/bash
# UserPromptSubmit hook to inject contextual information based on prompt content
# Returns JSON with additionalContext field

input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Convert prompt to lowercase for matching
prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

# Build context based on prompt keywords
context=""

# Deployment/release context
if [[ "$prompt_lower" == *"deploy"* ]] || [[ "$prompt_lower" == *"release"* ]] || [[ "$prompt_lower" == *"publish"* ]]; then
  context+="DEPLOYMENT CHECKLIST:
- Run full test suite before deploying
- Check for uncommitted changes (git status)
- Verify version bump in package.json/pyproject.toml/Cargo.toml
- Update CHANGELOG.md
- Create git tag after successful deploy
"
fi

# Database/migration context
if [[ "$prompt_lower" == *"migration"* ]] || [[ "$prompt_lower" == *"database"* ]] || [[ "$prompt_lower" == *"schema"* ]]; then
  context+="DATABASE SAFETY:
- Always backup before migrations
- Test migrations on staging first
- Ensure migrations are reversible when possible
- Check for long-running locks on production tables
"
fi

# Performance/optimization context
if [[ "$prompt_lower" == *"optim"* ]] || [[ "$prompt_lower" == *"performance"* ]] || [[ "$prompt_lower" == *"slow"* ]] || [[ "$prompt_lower" == *"fast"* ]]; then
  context+="PERFORMANCE CHECKLIST:
- Profile before optimizing (measure, don't guess)
- Check algorithmic complexity first
- Consider caching strategies
- For JAX: ensure JIT compilation, check for recompilation triggers
- For Python: use cProfile or py-spy for profiling
"
fi

# Security context
if [[ "$prompt_lower" == *"auth"* ]] || [[ "$prompt_lower" == *"security"* ]] || [[ "$prompt_lower" == *"password"* ]] || [[ "$prompt_lower" == *"token"* ]]; then
  context+="SECURITY REMINDER:
- Never hardcode secrets - use environment variables
- Validate and sanitize all user inputs
- Use parameterized queries for database operations
- Check ~/.claude/docs/security.md for full guidelines
"
fi

# Testing context
if [[ "$prompt_lower" == *"test"* ]] || [[ "$prompt_lower" == *"coverage"* ]] || [[ "$prompt_lower" == *"pytest"* ]]; then
  context+="TESTING GUIDELINES:
- Test behavior, not implementation
- Include edge cases: empty inputs, null values, boundaries
- For ML: test with fixed random seeds for reproducibility
- Check ~/.claude/docs/testing.md for full guidelines
"
fi

# ML/Training context
if [[ "$prompt_lower" == *"train"* ]] || [[ "$prompt_lower" == *"model"* ]] || [[ "$prompt_lower" == *"jax"* ]] || [[ "$prompt_lower" == *"flax"* ]]; then
  context+="ML TRAINING CHECKLIST:
- Set random seeds for reproducibility
- Use gradient clipping (optax.clip_by_global_norm)
- Monitor for NaN/Inf in gradients
- Checkpoint frequently with Orbax
- Check ~/.claude/docs/jax-ml.md for JAX conventions
"
fi

# Refactoring context
if [[ "$prompt_lower" == *"refactor"* ]] || [[ "$prompt_lower" == *"clean"* ]] || [[ "$prompt_lower" == *"restructure"* ]]; then
  context+="REFACTORING GUIDELINES:
- Ensure tests pass before and after
- Make small, incremental changes
- Avoid mixing refactoring with feature changes
- Use git commits to checkpoint progress
"
fi

# Output JSON if we have context to add
if [ -n "$context" ]; then
  # Escape for JSON
  escaped_context=$(echo "$context" | jq -Rs .)
  echo "{\"additionalContext\": $escaped_context}"
fi

exit 0
