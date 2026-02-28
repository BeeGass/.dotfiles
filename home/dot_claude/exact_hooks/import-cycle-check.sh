#!/bin/bash
# PostToolUse hook to check for circular imports in Python
# Runs after Python file edits

# Read JSON from stdin (PostToolUse hooks receive JSON, not positional args)
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file" ] && exit 0
[ ! -f "$file" ] && exit 0

# Only check Python files
case "$file" in
  *.py) ;;
  *) exit 0 ;;
esac

# Find project root (look for pyproject.toml, setup.py, or .git)
dir=$(dirname "$file")
project_root=""
search_dir="$dir"
while [ "$search_dir" != "/" ]; do
  if [ -f "$search_dir/pyproject.toml" ] || [ -f "$search_dir/setup.py" ] || [ -d "$search_dir/.git" ]; then
    project_root="$search_dir"
    break
  fi
  search_dir=$(dirname "$search_dir")
done

[ -z "$project_root" ] && exit 0

# Check if import-linter is available
if command -v lint-imports &>/dev/null; then
  cd "$project_root"
  if [ -f ".importlinter" ]; then
    errors=$(lint-imports 2>&1)
    if [ $? -ne 0 ]; then
      echo "WARNING: Import cycle detected:" >&2
      echo "$errors" | head -20 >&2
    fi
  fi
  exit 0
fi

# Fallback: simple import cycle detection using Python
# This is a basic check - won't catch all cycles
python3 - "$file" "$project_root" <<'PYTHON'
import sys
import ast
from pathlib import Path

file_path = Path(sys.argv[1])
project_root = Path(sys.argv[2])

# Get module name from file path
try:
    rel_path = file_path.relative_to(project_root)
    module_name = str(rel_path.with_suffix('')).replace('/', '.')
except ValueError:
    sys.exit(0)

# Parse the file and extract imports
try:
    with open(file_path) as f:
        tree = ast.parse(f.read())
except:
    sys.exit(0)

imports = []
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for alias in node.names:
            imports.append(alias.name)
    elif isinstance(node, ast.ImportFrom):
        if node.module:
            imports.append(node.module)

# Check for self-import (obvious cycle)
for imp in imports:
    if imp == module_name or imp.startswith(module_name + '.'):
        print(f"WARNING: Potential self-import detected: {imp}", file=sys.stderr)
PYTHON

exit 0
