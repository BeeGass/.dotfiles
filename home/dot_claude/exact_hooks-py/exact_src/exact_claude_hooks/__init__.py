"""Claude Code hooks - modular hook system for Claude Code CLI."""

from __future__ import annotations

import json
import sys

from .combined import (
    post_edit_combined,
    pre_bash_combined,
    pre_edit_combined,
    stop_combined,
    user_prompt_combined,
)
from .context import context7_docs, inject_context
from .format import format_on_save, typecheck
from .git import branch_protection, git_status_check, test_file_guard, validate_commit
from .jax import import_cycle_check, jax_shape_check, verify_api_calls
from .protection import dangerous_command, large_file_check, protect_files
from .session import doc_reminder, notify_done, session_logger
from .types import HookInput, HookResult

__all__ = [
    "HookInput",
    "HookResult",
    "protect_files",
    "large_file_check",
    "dangerous_command",
    "git_status_check",
    "branch_protection",
    "test_file_guard",
    "validate_commit",
    "format_on_save",
    "typecheck",
    "verify_api_calls",
    "jax_shape_check",
    "import_cycle_check",
    "inject_context",
    "context7_docs",
    "session_logger",
    "notify_done",
    "doc_reminder",
    "pre_edit_combined",
    "post_edit_combined",
    "pre_bash_combined",
    "user_prompt_combined",
    "stop_combined",
]

HOOKS = {
    "protect-files": protect_files,
    "large-file-check": large_file_check,
    "git-status-check": git_status_check,
    "branch-protection": branch_protection,
    "test-file-guard": test_file_guard,
    "verify-api-calls": verify_api_calls,
    "dangerous-command": dangerous_command,
    "validate-commit": validate_commit,
    "format-on-save": format_on_save,
    "typecheck": typecheck,
    "jax-shape-check": jax_shape_check,
    "import-cycle-check": import_cycle_check,
    "session-logger": session_logger,
    "inject-context": inject_context,
    "context7-docs": context7_docs,
    "notify-done": notify_done,
    "doc-reminder": doc_reminder,
    "pre-edit": pre_edit_combined,
    "post-edit": post_edit_combined,
    "pre-bash": pre_bash_combined,
    "user-prompt": user_prompt_combined,
    "stop": stop_combined,
}


def main() -> int:
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: claude-hooks <hook-name>", file=sys.stderr)
        return 1

    hook_name = sys.argv[1]
    hook_fn = HOOKS.get(hook_name)

    if not hook_fn:
        print(f"Unknown hook: {hook_name}", file=sys.stderr)
        return 1

    try:
        input_data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        return 0

    inp = HookInput.from_json(input_data)
    result = hook_fn(inp)

    for msg in result.stderr_messages:
        print(msg, file=sys.stderr)

    if result.stdout_json:
        print(result.stdout_json)

    return result.exit_code


if __name__ == "__main__":
    sys.exit(main())
