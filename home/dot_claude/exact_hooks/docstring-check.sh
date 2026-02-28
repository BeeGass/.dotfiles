#!/bin/bash
# PostToolUse hook to check for missing docstrings on public functions/classes
# Enforces documentation standards

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

# Skip test files and __init__.py
case "$file" in
  *test_* | *_test.py | *__init__.py | *conftest.py) exit 0 ;;
esac

python3 - "$file" <<'PYTHON'
import sys
import ast
from pathlib import Path

file_path = Path(sys.argv[1])
warnings = []

try:
    with open(file_path) as f:
        content = f.read()
        tree = ast.parse(content)
except Exception as e:
    sys.exit(0)

class DocstringChecker(ast.NodeVisitor):
    def __init__(self):
        self.class_stack = []

    def _is_public(self, name):
        """Check if name is public (doesn't start with _)."""
        return not name.startswith('_')

    def _has_docstring(self, node):
        """Check if function/class has a docstring."""
        if not node.body:
            return False
        first = node.body[0]
        if isinstance(first, ast.Expr) and isinstance(first.value, ast.Constant):
            return isinstance(first.value.value, str)
        return False

    def _check_docstring_quality(self, node, name):
        """Check docstring has required sections."""
        if not self._has_docstring(node):
            return None

        docstring = node.body[0].value.value
        issues = []

        # Check for Args section if function has parameters
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            # Get non-self/cls parameters
            params = [
                arg.arg for arg in node.args.args
                if arg.arg not in ('self', 'cls')
            ]
            params += [arg.arg for arg in node.args.kwonlyargs]

            if params and 'Args:' not in docstring and 'Parameters:' not in docstring:
                issues.append("missing Args section")

        # Check for Returns section if function has return annotation
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if node.returns and 'Returns:' not in docstring and 'Return:' not in docstring:
                # Allow if return type is None
                return_str = ast.unparse(node.returns) if hasattr(ast, 'unparse') else str(node.returns)
                if 'None' not in return_str:
                    issues.append("missing Returns section")

        # Check for Example section (encouraged but not required for all)
        # Only warn for complex functions
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if len(node.body) > 10 and 'Example' not in docstring:
                issues.append("consider adding Example section")

        return issues if issues else None

    def visit_FunctionDef(self, node):
        # Skip private functions and methods
        if not self._is_public(node.name):
            self.generic_visit(node)
            return

        # Skip if inside a class (check methods separately)
        in_class = bool(self.class_stack)

        # Check for missing docstring
        if not self._has_docstring(node):
            if in_class:
                class_name = self.class_stack[-1]
                warnings.append(
                    f"Line {node.lineno}: Method '{class_name}.{node.name}' missing docstring"
                )
            else:
                warnings.append(
                    f"Line {node.lineno}: Function '{node.name}' missing docstring"
                )
        else:
            # Check docstring quality
            issues = self._check_docstring_quality(node, node.name)
            if issues:
                name = f"{self.class_stack[-1]}.{node.name}" if in_class else node.name
                warnings.append(
                    f"Line {node.lineno}: '{name}' docstring: {', '.join(issues)}"
                )

        self.generic_visit(node)

    visit_AsyncFunctionDef = visit_FunctionDef

    def visit_ClassDef(self, node):
        if not self._is_public(node.name):
            self.generic_visit(node)
            return

        if not self._has_docstring(node):
            warnings.append(
                f"Line {node.lineno}: Class '{node.name}' missing docstring"
            )

        self.class_stack.append(node.name)
        self.generic_visit(node)
        self.class_stack.pop()

checker = DocstringChecker()
checker.visit(tree)

if warnings:
    print("Docstring warnings:", file=sys.stderr)
    for w in warnings[:10]:
        print(f"  {w}", file=sys.stderr)
    if len(warnings) > 10:
        print(f"  ... and {len(warnings) - 10} more warnings", file=sys.stderr)
    print("", file=sys.stderr)
    print("See ~/.claude/docs/python-style.md section 7 for docstring format.", file=sys.stderr)
PYTHON

exit 0
