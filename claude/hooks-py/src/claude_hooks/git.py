"""Git-related hooks."""

from __future__ import annotations

import re
from pathlib import Path

from .constants import PROTECTED_BRANCHES
from .types import HookInput, HookResult
from .utils import find_git_root, run_command


def git_status_check(inp: HookInput) -> HookResult:
    """Check for uncommitted changes."""
    result = HookResult()

    if inp.tool_name not in ("Edit", "Write") or not inp.file_path:
        return result

    path = Path(inp.file_path)
    if not path.exists():
        return result

    git_root = find_git_root(path)
    if not git_root:
        return result

    proc = run_command(["git", "status", "--porcelain", inp.file_path], cwd=git_root)
    if proc and proc.stdout.strip():
        status_code = proc.stdout[:2]
        if status_code in (" M", "MM", "AM"):
            result.warn(
                f"WARNING: File has uncommitted modifications\n"
                f"File: {inp.file_path}\n"
                f"Consider committing or stashing changes first."
            )
        elif status_code != "??":
            result.warn(f"WARNING: File has uncommitted changes (status: {status_code.strip()})\nFile: {inp.file_path}")

    proc = run_command(["git", "status", "--porcelain"], cwd=git_root)
    if proc:
        changes = len(proc.stdout.strip().splitlines())
        if changes > 20:
            result.warn(
                f"NOTE: Repository has {changes} uncommitted changes\n"
                f"Consider committing or stashing before making more changes."
            )

    return result


def branch_protection(inp: HookInput) -> HookResult:
    """Warn about protected branches."""
    result = HookResult()

    if inp.tool_name not in ("Edit", "Write"):
        return result

    proc = run_command(["git", "branch", "--show-current"])
    if proc and proc.returncode == 0:
        branch = proc.stdout.strip()
        if branch in PROTECTED_BRANCHES:
            result.warn(
                f"WARNING: You are on '{branch}' branch.\n"
                f"Consider creating a feature branch: git checkout -b feature/your-feature"
            )

    return result


def validate_commit(inp: HookInput) -> HookResult:
    """Validate git commit messages and branch names."""
    result = HookResult()

    if inp.tool_name != "Bash" or not inp.command:
        return result

    # Check for branch creation first
    branch_match = re.search(r"(checkout\s+-b|switch\s+-c)\s+(\S+)", inp.command)
    if branch_match:
        branch = branch_match.group(2)

        if re.match(r"^(main|master|develop|release/.+|hotfix/.+)$", branch):
            return result

        if not re.match(r"^(feat|fix|refactor|docs|test|chore|ci|build|perf|revert)/[a-z0-9-]+$", branch):
            return result.block(
                "BLOCKED: Branch name does not follow naming convention\n\n"
                "Expected format: type/short-description\n"
                f"Example: feat/add-oauth-login\n"
                f"Your branch: {branch}"
            )

    # Check for commit messages
    if "git commit" in inp.command:
        msg_match = re.search(r'-m\s*["\']([^"\']+)["\']', inp.command)
        if msg_match:
            msg = msg_match.group(1)
            conventional_re = (
                r"^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)"
                r"(\([a-zA-Z0-9_-]+\))?: .+"
            )

            if not re.match(conventional_re, msg):
                return result.block(
                    "BLOCKED: Commit message does not follow conventional commits format\n\n"
                    "Expected format: type(scope): description\n\n"
                    "Valid types:\n"
                    "  feat     - New feature\n"
                    "  fix      - Bug fix\n"
                    "  docs     - Documentation only\n"
                    "  style    - Formatting (no code change)\n"
                    "  refactor - Code restructuring\n"
                    "  perf     - Performance improvement\n"
                    "  test     - Adding/updating tests\n"
                    "  chore    - Maintenance tasks\n"
                    "  ci       - CI/CD changes\n"
                    "  build    - Build system changes\n"
                    "  revert   - Reverting changes\n\n"
                    f"Example: feat(auth): add OAuth2 login flow\n"
                    f"Your message: {msg}"
                )

            subject = msg.split("\n")[0]
            if len(subject) > 72:
                result.warn(f"WARNING: Commit subject line is {len(subject)} chars (recommended <= 50, max 72)")

    return result


def test_file_guard(inp: HookInput) -> HookResult:
    """Track test file edits."""
    result = HookResult()

    if inp.tool_name not in ("Edit", "Write") or not inp.file_path:
        return result

    test_patterns = [
        "test_",
        "_test.",
        "/tests/",
        "Test.java",
        "Test.ts",
        "Test.tsx",
        ".test.ts",
        ".test.tsx",
        ".test.js",
        ".spec.ts",
        ".spec.js",
    ]
    if any(p in inp.file_path for p in test_patterns):
        result.warn("NOTE: Editing test file. Remember to run tests before committing.")

    return result
