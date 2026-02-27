"""Session management and documentation hooks."""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Any

from .constants import SOURCE_EXTENSIONS
from .types import HookInput, HookResult
from .utils import run_command


def session_logger(inp: HookInput) -> HookResult:
    """Log tool usage."""
    result = HookResult()

    home = Path.home()
    log_dir = home / ".claude" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    today = datetime.now().strftime("%Y-%m-%d")
    log_file = log_dir / f"session-{today}.log"

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    session_id = inp.session_id or "unknown"
    tool_name = inp.tool_name or "unknown"

    if tool_name in ("Edit", "Write", "Read"):
        detail = f"file={inp.file_path or 'unknown'}"
    elif tool_name == "Bash":
        cmd = (inp.command or "unknown")[:100]
        detail = f"cmd={cmd}"
    elif tool_name in ("Glob", "Grep"):
        detail = f"pattern={inp.pattern or 'unknown'}"
    else:
        detail = ""

    log_line = f"[{timestamp}] session={session_id} tool={tool_name} {detail}\n"

    with open(log_file, "a") as f:
        f.write(log_line)

    return result


def notify_done(inp: HookInput) -> HookResult:
    """Send desktop notification when done."""
    result = HookResult()

    stop_reason = inp.stop_hook_reason or "completed"

    messages = {
        "user_stop": "Session stopped by user",
        "end_turn": "Task completed",
    }
    message = messages.get(stop_reason, stop_reason)

    run_command(["osascript", "-e", f'display notification "{message}" with title "Claude Code"'])
    run_command(["notify-send", "Claude Code", message, "--urgency=normal", "--icon=terminal"])

    return result


def get_session_edits(session_id: str | None, cwd: str | None) -> list[dict[str, Any]]:
    """Parse session log for Edit/Write operations in this session."""
    if not session_id:
        return []

    today = datetime.now().strftime("%Y-%m-%d")
    log_file = Path.home() / ".claude" / "logs" / f"session-{today}.log"

    if not log_file.exists():
        return []

    edits: list[dict[str, Any]] = []
    seen_files: set[str] = set()

    for line in log_file.read_text().splitlines():
        if f"session={session_id}" not in line:
            continue
        if "tool=Edit" in line or "tool=Write" in line:
            match = re.search(r"file=([^\s]+)", line)
            if match:
                file_path = match.group(1)
                if file_path not in seen_files:
                    seen_files.add(file_path)
                    is_new = "tool=Write" in line
                    edits.append({"path": file_path, "is_new": is_new})

    return edits


def doc_reminder(inp: HookInput) -> HookResult:
    """Require acknowledgment of documentation needs after code changes."""
    result = HookResult()

    cwd = Path(inp.cwd) if inp.cwd else Path.cwd()
    session_id = inp.session_id

    edited_files = get_session_edits(session_id, inp.cwd)
    if not edited_files:
        return result

    source_edits = [f for f in edited_files if Path(f["path"]).suffix in SOURCE_EXTENSIONS]

    if not source_edits:
        return result

    doc_locations: list[str] = []
    for doc_path in ["README.md", "docs", "CLAUDE.md", ".claude/CLAUDE.md"]:
        if (cwd / doc_path).exists():
            doc_locations.append(doc_path)

    lines = []
    for f in source_edits[:10]:
        label = "NEW" if f.get("is_new") else "modified"
        lines.append(f"  - {f['path']} ({label})")
    files_summary = "\n".join(lines)
    if len(source_edits) > 10:
        files_summary += f"\n  ... and {len(source_edits) - 10} more"

    docs_line = (
        "Existing documentation found: " + ", ".join(doc_locations)
        if doc_locations
        else "No project documentation found."
    )

    context = f"""
DOCUMENTATION CHECK REQUIRED

The following source files were modified this session:
{files_summary}

{docs_line}

REQUIRED: Before completing, explicitly state one of:
1. "Documentation updates needed: [list specific docs/sections]" - then make the updates
2. "No documentation updates needed: [brief reason]" - e.g., internal refactor, bug fix, etc.

Do not skip this acknowledgment.
"""

    return result.with_context({"additionalContext": context})
