"""Combined hooks for better performance."""

from __future__ import annotations

from .context import context7_docs, inject_context
from .format import format_on_save, typecheck
from .git import branch_protection, git_status_check, test_file_guard, validate_commit
from .jax import import_cycle_check, jax_shape_check, verify_api_calls
from .protection import dangerous_command, large_file_check, protect_files
from .session import doc_reminder, notify_done, session_logger
from .types import HookInput, HookResult


def pre_edit_combined(inp: HookInput) -> HookResult:
    """Combined pre-edit hooks."""
    result = HookResult()
    result = result.merge(protect_files(inp))
    if result.exit_code > 0:
        return result
    result = result.merge(large_file_check(inp))
    if result.exit_code > 0:
        return result
    result = result.merge(git_status_check(inp))
    result = result.merge(branch_protection(inp))
    result = result.merge(test_file_guard(inp))
    result = result.merge(verify_api_calls(inp))
    return result


def post_edit_combined(inp: HookInput) -> HookResult:
    """Combined post-edit hooks."""
    result = HookResult()
    result = result.merge(format_on_save(inp))
    result = result.merge(typecheck(inp))
    result = result.merge(jax_shape_check(inp))
    result = result.merge(import_cycle_check(inp))
    result = result.merge(session_logger(inp))
    return result


def pre_bash_combined(inp: HookInput) -> HookResult:
    """Combined pre-bash hooks."""
    result = HookResult()
    result = result.merge(dangerous_command(inp))
    if result.exit_code > 0:
        return result
    result = result.merge(validate_commit(inp))
    return result


def user_prompt_combined(inp: HookInput) -> HookResult:
    """Combined user prompt hooks."""
    result = HookResult()
    result = result.merge(inject_context(inp))
    result = result.merge(context7_docs(inp))
    return result


def stop_combined(inp: HookInput) -> HookResult:
    """Combined stop hooks."""
    result = HookResult()
    result = result.merge(doc_reminder(inp))
    result = result.merge(notify_done(inp))
    return result
