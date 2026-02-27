"""Type definitions for Claude Code hooks."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any


@dataclass
class HookResult:
    """Result from a hook execution."""

    exit_code: int = 0
    stderr_messages: list[str] = field(default_factory=list)
    stdout_json: str | None = None

    def warn(self, msg: str) -> HookResult:
        self.stderr_messages.append(msg)
        return self

    def block(self, msg: str) -> HookResult:
        self.stderr_messages.append(msg)
        self.exit_code = 2
        return self

    def with_context(self, data: dict[str, Any]) -> HookResult:
        self.stdout_json = json.dumps(data)
        return self

    def merge(self, other: HookResult) -> HookResult:
        self.stderr_messages.extend(other.stderr_messages)
        if other.exit_code > self.exit_code:
            self.exit_code = other.exit_code
        if other.stdout_json:
            if self.stdout_json:
                try:
                    self_data = json.loads(self.stdout_json)
                    other_data = json.loads(other.stdout_json)
                    if "additionalContext" in self_data and "additionalContext" in other_data:
                        self_data["additionalContext"] = (
                            self_data["additionalContext"] + "\n\n" + other_data["additionalContext"]
                        )
                        self.stdout_json = json.dumps(self_data)
                    else:
                        self.stdout_json = other.stdout_json
                except json.JSONDecodeError:
                    self.stdout_json = other.stdout_json
            else:
                self.stdout_json = other.stdout_json
        return self


@dataclass
class HookInput:
    """Parsed hook input from Claude Code."""

    tool_name: str | None = None
    file_path: str | None = None
    content: str | None = None
    new_string: str | None = None
    old_string: str | None = None
    command: str | None = None
    pattern: str | None = None
    cwd: str | None = None
    session_id: str | None = None
    prompt: str | None = None
    hook_event_name: str | None = None
    stop_hook_reason: str | None = None

    @classmethod
    def from_json(cls, data: dict[str, Any]) -> HookInput:
        tool_input = data.get("tool_input", {}) or {}
        return cls(
            tool_name=data.get("tool_name"),
            file_path=tool_input.get("file_path"),
            content=tool_input.get("content"),
            new_string=tool_input.get("new_string"),
            old_string=tool_input.get("old_string"),
            command=tool_input.get("command"),
            pattern=tool_input.get("pattern"),
            cwd=data.get("cwd"),
            session_id=data.get("session_id"),
            prompt=data.get("prompt"),
            hook_event_name=data.get("hook_event_name"),
            stop_hook_reason=data.get("stop_hook_reason"),
        )
