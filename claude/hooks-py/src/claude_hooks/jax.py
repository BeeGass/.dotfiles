"""JAX/ML related hooks."""

from __future__ import annotations

import re
from pathlib import Path

from .constants import JAX_LIBS
from .types import HookInput, HookResult
from .utils import find_project_root, run_command


def verify_api_calls(inp: HookInput) -> HookResult:
    """Suggest verifying API calls for complex libraries."""
    result = HookResult()

    if inp.tool_name not in ("Edit", "Write"):
        return result

    if not inp.file_path or not inp.file_path.endswith(".py"):
        return result

    content = inp.content or inp.new_string or ""
    found_libs = []

    for lib in JAX_LIBS:
        lib_escaped = re.escape(lib)
        if re.search(rf"(from {lib_escaped}|import {lib_escaped})", content):
            found_libs.append(lib)

    if found_libs:
        result.warn(
            f"NOTE: Code uses APIs from: {', '.join(found_libs)}\n"
            f"These libraries have complex/evolving APIs. "
            f"Consider verifying function signatures with Context7 MCP if unsure."
        )

    return result


def jax_shape_check(inp: HookInput) -> HookResult:
    """Validate JAX shape annotations."""
    result = HookResult()

    if not inp.file_path or not inp.file_path.endswith(".py"):
        return result

    path = Path(inp.file_path)
    if not path.exists():
        return result

    content = path.read_text()

    if not any(s in content for s in ["import jax", "from jax", "from flax", "from jaxtyping"]):
        return result

    warnings = []

    for i, line in enumerate(content.splitlines(), 1):
        match = re.search(r'jnp\.einsum\s*\(\s*["\']([^"\']+)["\']', line)
        if match:
            subscripts = match.group(1)
            if "->" in subscripts:
                inputs, output = subscripts.split("->")
                input_indices = {c for c in inputs if c.isalpha()}
                output_indices = {c for c in output if c.isalpha()}
                invalid = output_indices - input_indices
                if invalid:
                    warnings.append(f"Line {i}: einsum output has indices {invalid} not present in input")

    for i, line in enumerate(content.splitlines(), 1):
        if re.search(r"jax\.(vmap|pmap)\s*\(\s*\w+\s*\)", line) and "in_axes" not in line and "out_axes" not in line:
            warnings.append(
                f"Line {i}: vmap/pmap without explicit in_axes/out_axes (defaults to 0, verify this is intended)"
            )

    if warnings:
        result.warn("JAX shape/type warnings:\n  " + "\n  ".join(warnings[:10]))

    return result


def import_cycle_check(inp: HookInput) -> HookResult:
    """Check for import cycles."""
    result = HookResult()

    if not inp.file_path or not inp.file_path.endswith(".py"):
        return result

    path = Path(inp.file_path)
    project_root = find_project_root(path)

    if not project_root:
        return result

    if (project_root / ".importlinter").exists():
        proc = run_command(["lint-imports"], cwd=project_root)
        if proc and proc.returncode != 0:
            result.warn("WARNING: Import cycle detected:\n" + "\n".join(proc.stderr.splitlines()[:20]))

    return result
