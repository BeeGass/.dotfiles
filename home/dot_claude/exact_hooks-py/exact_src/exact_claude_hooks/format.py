"""Formatting and type checking hooks."""

from __future__ import annotations

from pathlib import Path

from .types import HookInput, HookResult
from .utils import find_project_root, run_command


def format_on_save(inp: HookInput) -> HookResult:
    """Run formatters on saved files."""
    result = HookResult()

    if not inp.file_path:
        return result

    path = Path(inp.file_path)
    if not path.exists():
        return result

    if inp.file_path.endswith(".py"):
        run_command(["ruff", "check", inp.file_path, "--fix", "--quiet"])
        run_command(["ruff", "format", inp.file_path, "--quiet"])
    elif inp.file_path.endswith(".rs"):
        run_command(["rustfmt", inp.file_path])
    elif any(inp.file_path.endswith(ext) for ext in (".ts", ".tsx", ".js", ".jsx", ".json")):
        run_command(["npx", "prettier", "--write", inp.file_path])
    elif inp.file_path.endswith(".md"):
        run_command(["npx", "prettier", "--write", inp.file_path, "--prose-wrap=always"])

    return result


def typecheck(inp: HookInput) -> HookResult:
    """Run type checkers."""
    result = HookResult()

    if not inp.file_path:
        return result

    path = Path(inp.file_path)
    if not path.exists():
        return result

    if inp.file_path.endswith(".py"):
        return typecheck_python(inp.file_path)
    elif inp.file_path.endswith((".ts", ".tsx")):
        return typecheck_typescript(inp.file_path)
    elif inp.file_path.endswith(".rs"):
        return typecheck_rust(inp.file_path)

    return result


def typecheck_python(file_path: str) -> HookResult:
    """Run mypy on Python files."""
    result = HookResult()
    path = Path(file_path)
    project_root = find_project_root(path)

    if not project_root:
        return result

    has_config = (
        (project_root / "mypy.ini").exists()
        or (project_root / ".mypy.ini").exists()
        or (
            (project_root / "pyproject.toml").exists()
            and "[tool.mypy]" in (project_root / "pyproject.toml").read_text()
        )
    )

    if not has_config:
        return result

    rel_path = path.relative_to(project_root)

    if (project_root / "pyproject.toml").exists():
        proc = run_command(
            ["uv", "run", "--quiet", "mypy", str(rel_path), "--no-error-summary", "--no-color"],
            cwd=project_root,
            timeout=60,
        )
    else:
        proc = run_command(
            ["mypy", str(rel_path), "--no-error-summary", "--no-color"],
            cwd=project_root,
            timeout=60,
        )

    if proc and proc.returncode != 0:
        errors = [line for line in proc.stdout.splitlines() if line.startswith(str(rel_path))]
        if errors:
            return result.block(f"mypy errors in {file_path}:\n" + "\n".join(errors))

    return result


def typecheck_typescript(file_path: str) -> HookResult:
    """Run tsc on TypeScript files."""
    result = HookResult()
    path = Path(file_path)

    current = path.parent
    tsconfig = None
    while current != current.parent:
        if (current / "tsconfig.json").exists():
            tsconfig = current / "tsconfig.json"
            break
        current = current.parent

    if not tsconfig:
        return result

    proc = run_command(["npx", "tsc", "--noEmit", "--project", str(tsconfig)], timeout=60)
    if proc:
        errors = [line for line in proc.stdout.splitlines() if line.startswith(file_path)]
        if errors:
            return result.block(f"TypeScript errors in {file_path}:\n" + "\n".join(errors))

    return result


def typecheck_rust(file_path: str) -> HookResult:
    """Run clippy on Rust files."""
    result = HookResult()
    path = Path(file_path)

    current = path.parent
    cargo_dir = None
    while current != current.parent:
        if (current / "Cargo.toml").exists():
            cargo_dir = current
            break
        current = current.parent

    if not cargo_dir:
        return result

    proc = run_command(["cargo", "clippy", "--message-format=short"], cwd=cargo_dir, timeout=60)
    if proc:
        errors = [line for line in proc.stderr.splitlines() if line.startswith("error")][:10]
        if errors:
            return result.block("Clippy errors:\n" + "\n".join(errors))

    return result
