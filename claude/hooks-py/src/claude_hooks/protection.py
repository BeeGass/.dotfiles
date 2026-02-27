"""File protection and safety hooks."""

from __future__ import annotations

import fnmatch
import re

from .constants import DANGEROUS_PATTERNS, PROTECTED_PATTERNS, SECRET_PATTERNS
from .types import HookInput, HookResult


def _matches_protected_pattern(file_path: str, pattern: str) -> bool:
    """Check if file_path matches pattern, including basename matching."""
    # Direct match
    if fnmatch.fnmatch(file_path, pattern):
        return True
    # Also try matching just the basename for patterns without path separators
    if "/" not in pattern:
        basename = file_path.rsplit("/", 1)[-1] if "/" in file_path else file_path
        if fnmatch.fnmatch(basename, pattern):
            return True
    return False


def protect_files(inp: HookInput) -> HookResult:
    """Check for protected files and secrets."""
    result = HookResult()

    if inp.tool_name not in ("Edit", "Write"):
        return result

    if not inp.file_path:
        return result

    for pattern in PROTECTED_PATTERNS:
        if _matches_protected_pattern(inp.file_path, pattern):
            return result.block(
                f"BLOCKED: Cannot modify protected file: {inp.file_path}\n"
                f"Pattern matched: {pattern}\n"
                f"If you need to modify this file, please do so manually."
            )

    if inp.tool_name == "Write" and inp.content:
        for pattern in SECRET_PATTERNS:
            if re.search(pattern, inp.content):
                return result.block(
                    f"BLOCKED: Potential secret/API key detected in file content\n"
                    f"Pattern: {pattern}\n"
                    f"Please use environment variables or a secrets manager instead."
                )

    return result


def large_file_check(inp: HookInput) -> HookResult:
    """Check for large file operations."""
    result = HookResult()

    if inp.tool_name == "Write" and inp.content:
        size = len(inp.content)
        file_path = inp.file_path or "unknown"

        if size > 1_048_576:
            return result.block(
                f"BLOCKED: File content too large ({size // 1_048_576}MB)\n"
                f"This is likely a mistake. If intentional, write manually."
            )

        if size > 102_400:
            result.warn(
                f"WARNING: Large file write detected\n"
                f"File: {file_path}\n"
                f"Size: {size // 1024}KB\n\n"
                f"Consider:\n"
                f"  - Breaking into smaller files\n"
                f"  - Using external data storage\n"
                f"  - Generating programmatically instead of hardcoding"
            )

        if size > 1000:
            non_printable = sum(
                1 for b in inp.content.encode("utf-8", errors="replace") if b < 32 and b not in (9, 10, 13)
            )
            ratio = (non_printable * 100) // size
            if ratio > 20:
                result.warn(
                    f"WARNING: Content appears to contain binary data ({ratio}% non-printable)\nFile: {file_path}"
                )

    elif inp.tool_name == "Edit" and inp.new_string:
        if len(inp.new_string) > 51_200:
            result.warn(
                f"WARNING: Large edit detected ({len(inp.new_string) // 1024}KB replacement)\n"
                f"Consider breaking into smaller edits."
            )

    return result


def dangerous_command(inp: HookInput) -> HookResult:
    """Block dangerous bash commands."""
    result = HookResult()

    if inp.tool_name != "Bash" or not inp.command:
        return result

    for pattern in DANGEROUS_PATTERNS:
        if re.search(pattern, inp.command):
            return result.block(
                f"BLOCKED: Potentially dangerous command detected\n"
                f"Pattern matched: {pattern}\n"
                f"Command: {inp.command}\n\n"
                f"If you really need to run this command, please do so manually."
            )

    if re.search(r"rm\s+-rf?\s+.*\$", inp.command):
        result.warn(
            f"WARNING: rm -rf with variable expansion detected\n"
            f"Command: {inp.command}\n"
            f"Ensure the variable is set correctly before proceeding."
        )

    if inp.command.startswith("sudo "):
        result.warn("WARNING: sudo command detected - will require manual approval")

    return result
