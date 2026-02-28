#!/bin/bash
# PostToolUse hook to validate JAX/jaxtyping shape annotations
# Checks for common shape-related issues in JAX code

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

# Check if file uses JAX
if ! grep -qE "^(import jax|from jax|from flax|from jaxtyping)" "$file" 2>/dev/null; then
  exit 0
fi

# Run Python analysis
python3 - "$file" <<'PYTHON'
import sys
import ast
import re
from pathlib import Path

file_path = Path(sys.argv[1])
warnings = []

try:
    with open(file_path) as f:
        content = f.read()
        tree = ast.parse(content)
except Exception as e:
    sys.exit(0)

lines = content.split('\n')

# Check 1: Functions with Array return types should have jaxtyped decorator
class JaxTypingChecker(ast.NodeVisitor):
    def __init__(self):
        self.has_jaxtyping_import = False
        self.jaxtyped_functions = set()

    def visit_ImportFrom(self, node):
        if node.module and 'jaxtyping' in node.module:
            self.has_jaxtyping_import = True
        self.generic_visit(node)

    def visit_FunctionDef(self, node):
        # Check if function has jaxtyped decorator
        has_jaxtyped = any(
            (isinstance(d, ast.Call) and isinstance(d.func, ast.Name) and d.func.id == 'jaxtyped') or
            (isinstance(d, ast.Name) and d.id == 'jaxtyped')
            for d in node.decorator_list
        )

        # Check return annotation for Array types
        if node.returns:
            return_str = ast.unparse(node.returns) if hasattr(ast, 'unparse') else ''
            if 'Array' in return_str or 'Float[' in return_str or 'Int[' in return_str:
                if not has_jaxtyped and self.has_jaxtyping_import:
                    warnings.append(
                        f"Line {node.lineno}: Function '{node.name}' returns Array type but missing @jaxtyped decorator"
                    )

        self.generic_visit(node)

    visit_AsyncFunctionDef = visit_FunctionDef

checker = JaxTypingChecker()
checker.visit(tree)

# Check 2: Look for common shape mistakes in einsum
einsum_pattern = re.compile(r'jnp\.einsum\s*\(\s*["\']([^"\']+)["\']')
for i, line in enumerate(lines, 1):
    match = einsum_pattern.search(line)
    if match:
        subscripts = match.group(1)
        # Check for repeated indices in output that aren't in input (common mistake)
        if '->' in subscripts:
            inputs, output = subscripts.split('->')
            input_indices = set(c for c in inputs if c.isalpha())
            output_indices = set(c for c in output if c.isalpha())
            invalid = output_indices - input_indices
            if invalid:
                warnings.append(
                    f"Line {i}: einsum output has indices {invalid} not present in input"
                )

# Check 3: PRNGKey reuse detection (simple heuristic)
key_assignments = {}
key_pattern = re.compile(r'(\w+)\s*=\s*(?:jax\.random\.(?:PRNGKey|key)|jax\.random\.split)')
key_usage = re.compile(r'jax\.random\.\w+\s*\(\s*(\w+)')

for i, line in enumerate(lines, 1):
    # Track key assignments
    assign_match = key_pattern.search(line)
    if assign_match:
        key_name = assign_match.group(1)
        key_assignments[key_name] = {'line': i, 'uses': 0}

    # Track key usages
    usage_match = key_usage.search(line)
    if usage_match:
        key_name = usage_match.group(1)
        if key_name in key_assignments:
            key_assignments[key_name]['uses'] += 1

# Warn about keys used multiple times without splitting
for key_name, info in key_assignments.items():
    if info['uses'] > 1:
        warnings.append(
            f"Line {info['line']}: PRNGKey '{key_name}' appears to be used {info['uses']} times without splitting"
        )

# Check 4: vmap/pmap without explicit axis specification
vmap_pattern = re.compile(r'jax\.(vmap|pmap)\s*\(\s*\w+\s*\)')
for i, line in enumerate(lines, 1):
    if vmap_pattern.search(line):
        if 'in_axes' not in line and 'out_axes' not in line:
            warnings.append(
                f"Line {i}: vmap/pmap without explicit in_axes/out_axes (defaults to 0, verify this is intended)"
            )

# Check 5: Mixed dtype operations
dtype_ops = re.compile(r'(astype|\.dtype)')
float32_pattern = re.compile(r'float32|jnp\.float32')
bfloat16_pattern = re.compile(r'bfloat16|jnp\.bfloat16')

has_float32 = bool(float32_pattern.search(content))
has_bfloat16 = bool(bfloat16_pattern.search(content))

if has_float32 and has_bfloat16:
    # Check for potential mixed-precision issues
    for i, line in enumerate(lines, 1):
        if 'float32' in line and 'bfloat16' in line:
            if 'astype' not in line and 'dtype=' not in line:
                warnings.append(
                    f"Line {i}: Mixed float32/bfloat16 in same line - verify precision handling"
                )

# Output warnings
if warnings:
    print("JAX shape/type warnings:", file=sys.stderr)
    for w in warnings[:10]:  # Limit to 10 warnings
        print(f"  {w}", file=sys.stderr)
    if len(warnings) > 10:
        print(f"  ... and {len(warnings) - 10} more warnings", file=sys.stderr)
PYTHON

exit 0
