#!/usr/bin/env python3
"""Test script to verify hooks produce correct output."""

from __future__ import annotations

import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

HOOKS_PY = Path.home() / ".dotfiles/claude/hooks-py"
HOOKS_RS = Path.home() / ".dotfiles/claude/hooks-rs/target/release/claude-hooks"


@dataclass
class TestCase:
    name: str
    hook: str
    input_data: dict[str, Any]
    expect_exit: int = 0
    expect_stderr_contains: str | None = None
    expect_stdout_contains: str | None = None
    expect_no_output: bool = False


TEST_CASES: list[TestCase] = [
    # protect-files tests
    TestCase(
        name="protect-files: blocks .env file",
        hook="protect-files",
        input_data={
            "tool_name": "Write",
            "tool_input": {"file_path": "/project/.env", "content": "SECRET=value"},
        },
        expect_exit=2,
        expect_stderr_contains="BLOCKED",
    ),
    TestCase(
        name="protect-files: allows normal file",
        hook="protect-files",
        input_data={
            "tool_name": "Write",
            "tool_input": {"file_path": "/project/main.py", "content": "print('hello')"},
        },
        expect_exit=0,
        expect_no_output=True,
    ),
    TestCase(
        name="protect-files: blocks Cargo.lock",
        hook="protect-files",
        input_data={
            "tool_name": "Write",
            "tool_input": {"file_path": "/project/Cargo.lock", "content": "lock data"},
        },
        expect_exit=2,
        expect_stderr_contains="BLOCKED",
    ),
    # large-file-check tests
    TestCase(
        name="large-file-check: warns on large file",
        hook="large-file-check",
        input_data={
            "tool_name": "Write",
            "tool_input": {"file_path": "/project/data.py", "content": "x" * 150_000},
        },
        expect_exit=0,
        expect_stderr_contains="Large file",
    ),
    TestCase(
        name="large-file-check: blocks huge file",
        hook="large-file-check",
        input_data={
            "tool_name": "Write",
            "tool_input": {"file_path": "/project/huge.py", "content": "x" * 2_000_000},
        },
        expect_exit=2,
        expect_stderr_contains="too large",
    ),
    TestCase(
        name="large-file-check: allows normal file",
        hook="large-file-check",
        input_data={
            "tool_name": "Write",
            "tool_input": {"file_path": "/project/small.py", "content": "print('hi')"},
        },
        expect_exit=0,
        expect_no_output=True,
    ),
    # dangerous-command tests
    TestCase(
        name="dangerous-command: blocks rm -rf /",
        hook="dangerous-command",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "rm -rf /"},
        },
        expect_exit=2,
        expect_stderr_contains="BLOCKED",
    ),
    TestCase(
        name="dangerous-command: blocks force push to main",
        hook="dangerous-command",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "git push --force origin main"},
        },
        expect_exit=2,
        expect_stderr_contains="BLOCKED",
    ),
    TestCase(
        name="dangerous-command: allows safe commands",
        hook="dangerous-command",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "ls -la"},
        },
        expect_exit=0,
        expect_no_output=True,
    ),
    TestCase(
        name="dangerous-command: warns on sudo",
        hook="dangerous-command",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "sudo apt update"},
        },
        expect_exit=0,
        expect_stderr_contains="sudo",
    ),
    TestCase(
        name="dangerous-command: blocks mkfs",
        hook="dangerous-command",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "mkfs.ext4 /dev/sda1"},
        },
        expect_exit=2,
        expect_stderr_contains="BLOCKED",
    ),
    # validate-commit tests
    TestCase(
        name="validate-commit: blocks non-conventional commit",
        hook="validate-commit",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "git commit -m 'fixed stuff'"},
        },
        expect_exit=2,
        expect_stderr_contains="conventional",
    ),
    TestCase(
        name="validate-commit: allows conventional commit",
        hook="validate-commit",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "git commit -m 'feat(auth): add login'"},
        },
        expect_exit=0,
        expect_no_output=True,
    ),
    TestCase(
        name="validate-commit: blocks bad branch name",
        hook="validate-commit",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "git checkout -b my-feature"},
        },
        expect_exit=2,
        expect_stderr_contains="naming convention",
    ),
    TestCase(
        name="validate-commit: allows good branch name",
        hook="validate-commit",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "git checkout -b feat/add-login"},
        },
        expect_exit=0,
        expect_no_output=True,
    ),
    TestCase(
        name="validate-commit: allows fix branch",
        hook="validate-commit",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "git checkout -b fix/memory-leak"},
        },
        expect_exit=0,
        expect_no_output=True,
    ),
    # test-file-guard tests
    TestCase(
        name="test-file-guard: warns on test file",
        hook="test-file-guard",
        input_data={
            "tool_name": "Edit",
            "tool_input": {"file_path": "/project/test_main.py"},
        },
        expect_exit=0,
        expect_stderr_contains="test file",
    ),
    TestCase(
        name="test-file-guard: warns on spec file",
        hook="test-file-guard",
        input_data={
            "tool_name": "Edit",
            "tool_input": {"file_path": "/project/app.spec.ts"},
        },
        expect_exit=0,
        expect_stderr_contains="test file",
    ),
    TestCase(
        name="test-file-guard: silent on non-test file",
        hook="test-file-guard",
        input_data={
            "tool_name": "Edit",
            "tool_input": {"file_path": "/project/main.py"},
        },
        expect_exit=0,
        expect_no_output=True,
    ),
    # inject-context tests
    TestCase(
        name="inject-context: adds deployment context",
        hook="inject-context",
        input_data={"prompt": "Help me deploy this to production"},
        expect_exit=0,
        expect_stdout_contains="DEPLOYMENT",
    ),
    TestCase(
        name="inject-context: adds security context",
        hook="inject-context",
        input_data={"prompt": "Add authentication to the API"},
        expect_exit=0,
        expect_stdout_contains="SECURITY",
    ),
    TestCase(
        name="inject-context: adds refactoring context",
        hook="inject-context",
        input_data={"prompt": "Refactor this code to be cleaner"},
        expect_exit=0,
        expect_stdout_contains="REFACTORING",
    ),
    TestCase(
        name="inject-context: adds database context",
        hook="inject-context",
        input_data={"prompt": "Run the database migration"},
        expect_exit=0,
        expect_stdout_contains="DATABASE",
    ),
    TestCase(
        name="inject-context: adds testing context",
        hook="inject-context",
        input_data={"prompt": "Write tests for this function"},
        expect_exit=0,
        expect_stdout_contains="TESTING",
    ),
    TestCase(
        name="inject-context: no context for unrelated prompt",
        hook="inject-context",
        input_data={"prompt": "What is 2 + 2?"},
        expect_exit=0,
        expect_no_output=True,
    ),
    # verify-api-calls tests
    TestCase(
        name="verify-api-calls: warns on JAX imports",
        hook="verify-api-calls",
        input_data={
            "tool_name": "Write",
            "tool_input": {
                "file_path": "/project/model.py",
                "content": "import jax\nimport flax.nnx as nnx",
            },
        },
        expect_exit=0,
        expect_stderr_contains="jax",
    ),
    TestCase(
        name="verify-api-calls: silent on non-jax code",
        hook="verify-api-calls",
        input_data={
            "tool_name": "Write",
            "tool_input": {
                "file_path": "/project/main.py",
                "content": "print('hello')",
            },
        },
        expect_exit=0,
        expect_no_output=True,
    ),
    # notify-done tests
    TestCase(
        name="notify-done: runs without error",
        hook="notify-done",
        input_data={"stop_hook_reason": "end_turn"},
        expect_exit=0,
    ),
    # Combined hooks
    TestCase(
        name="pre-edit: combined protection blocks .env",
        hook="pre-edit",
        input_data={
            "tool_name": "Write",
            "tool_input": {"file_path": "/project/.env", "content": "SECRET=x"},
        },
        expect_exit=2,
        expect_stderr_contains="BLOCKED",
    ),
    TestCase(
        name="pre-bash: combined validation blocks rm",
        hook="pre-bash",
        input_data={
            "tool_name": "Bash",
            "tool_input": {"command": "rm -rf /"},
        },
        expect_exit=2,
        expect_stderr_contains="BLOCKED",
    ),
    TestCase(
        name="user-prompt: combined context for deploy",
        hook="user-prompt",
        input_data={"prompt": "Deploy to production", "hook_event_name": "UserPromptSubmit"},
        expect_exit=0,
        expect_stdout_contains="DEPLOYMENT",
    ),
    TestCase(
        name="stop: combined runs without error",
        hook="stop",
        input_data={"session_id": "test123", "stop_hook_reason": "end_turn"},
        expect_exit=0,
    ),
]


def run_python_hook(hook: str, input_data: dict[str, Any]) -> tuple[int, str, str]:
    """Run hook via Python implementation."""
    proc = subprocess.run(
        ["uv", "run", "--project", str(HOOKS_PY), "claude-hooks", hook],
        input=json.dumps(input_data),
        capture_output=True,
        text=True,
        timeout=30,
    )
    return proc.returncode, proc.stdout, proc.stderr


def run_rust_hook(hook: str, input_data: dict[str, Any]) -> tuple[int, str, str]:
    """Run hook via Rust implementation."""
    if not HOOKS_RS.exists():
        return -1, "", "Rust binary not found"
    proc = subprocess.run(
        [str(HOOKS_RS), hook],
        input=json.dumps(input_data),
        capture_output=True,
        text=True,
        timeout=30,
    )
    return proc.returncode, proc.stdout, proc.stderr


def check_result(test: TestCase, exit_code: int, stdout: str, stderr: str, impl: str) -> tuple[bool, str]:
    """Check if result matches expectations."""
    if exit_code != test.expect_exit:
        return False, f"Expected exit {test.expect_exit}, got {exit_code}"

    if test.expect_stderr_contains:
        if test.expect_stderr_contains.lower() not in stderr.lower():
            return False, f"Expected stderr to contain '{test.expect_stderr_contains}'"

    if test.expect_stdout_contains:
        if test.expect_stdout_contains.lower() not in stdout.lower():
            return False, f"Expected stdout to contain '{test.expect_stdout_contains}'"

    if test.expect_no_output:
        if stdout.strip() or stderr.strip():
            return False, f"Expected no output, got stdout='{stdout[:50]}' stderr='{stderr[:50]}'"

    return True, "OK"


def main() -> int:
    passed = 0
    failed = 0
    skipped = 0

    print("=" * 70)
    print("HOOK TESTS")
    print("=" * 70)

    for test in TEST_CASES:
        print(f"\n{test.name}")
        print("-" * 50)

        # Test Python
        try:
            py_exit, py_stdout, py_stderr = run_python_hook(test.hook, test.input_data)
            py_ok, py_msg = check_result(test, py_exit, py_stdout, py_stderr, "Python")
            if py_ok:
                print("  Python: PASS")
                passed += 1
            else:
                print(f"  Python: FAIL - {py_msg}")
                print(f"    stdout: {py_stdout[:100]}")
                print(f"    stderr: {py_stderr[:100]}")
                failed += 1
        except Exception as e:
            print(f"  Python: ERROR - {e}")
            failed += 1

        # Test Rust
        try:
            rs_exit, rs_stdout, rs_stderr = run_rust_hook(test.hook, test.input_data)
            if rs_exit == -1:
                print("  Rust: SKIP - binary not found")
                skipped += 1
            else:
                rs_ok, rs_msg = check_result(test, rs_exit, rs_stdout, rs_stderr, "Rust")
                if rs_ok:
                    print("  Rust:   PASS")
                    passed += 1
                else:
                    print(f"  Rust:   FAIL - {rs_msg}")
                    print(f"    stdout: {rs_stdout[:100]}")
                    print(f"    stderr: {rs_stderr[:100]}")
                    failed += 1
        except Exception as e:
            print(f"  Rust: ERROR - {e}")
            failed += 1

    print("\n" + "=" * 70)
    print(f"RESULTS: {passed} passed, {failed} failed, {skipped} skipped")
    print("=" * 70)

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
