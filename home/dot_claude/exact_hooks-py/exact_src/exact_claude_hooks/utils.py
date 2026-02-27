"""Utility functions for Claude Code hooks."""

from __future__ import annotations

import subprocess
from pathlib import Path


def find_git_root(path: Path) -> Path | None:
    """Find the git root directory."""
    current = path if path.is_dir() else path.parent
    while current != current.parent:
        if (current / ".git").exists():
            return current
        current = current.parent
    return None


def find_project_root(path: Path) -> Path | None:
    """Find Python project root."""
    current = path if path.is_dir() else path.parent
    while current != current.parent:
        if (current / "pyproject.toml").exists() or (current / "setup.py").exists() or (current / "setup.cfg").exists():
            return current
        current = current.parent
    return None


def run_command(cmd: list[str], cwd: Path | None = None, timeout: int = 30) -> subprocess.CompletedProcess[str] | None:
    """Run a command and return result, or None on error."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd)
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None
