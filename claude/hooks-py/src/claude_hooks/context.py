"""Context injection hooks."""

from __future__ import annotations

import re

from .constants import KNOWN_LIBS
from .types import HookInput, HookResult


def inject_context(inp: HookInput) -> HookResult:
    """Inject contextual information based on prompt."""
    result = HookResult()

    if not inp.prompt:
        return result

    prompt = inp.prompt.lower()
    context_parts = []

    if any(k in prompt for k in ["deploy", "release", "publish"]):
        context_parts.append(
            "DEPLOYMENT CHECKLIST:\n"
            "- Run full test suite before deploying\n"
            "- Check for uncommitted changes (git status)\n"
            "- Verify version bump in package.json/pyproject.toml/Cargo.toml\n"
            "- Update CHANGELOG.md\n"
            "- Create git tag after successful deploy"
        )

    if any(k in prompt for k in ["migration", "database", "schema"]):
        context_parts.append(
            "DATABASE SAFETY:\n"
            "- Always backup before migrations\n"
            "- Test migrations on staging first\n"
            "- Ensure migrations are reversible when possible\n"
            "- Check for long-running locks on production tables"
        )

    if any(k in prompt for k in ["optim", "performance", "slow", "fast"]):
        context_parts.append(
            "PERFORMANCE CHECKLIST:\n"
            "- Profile before optimizing (measure, don't guess)\n"
            "- Check algorithmic complexity first\n"
            "- Consider caching strategies\n"
            "- For JAX: ensure JIT compilation, check for recompilation triggers"
        )

    if any(k in prompt for k in ["auth", "security", "password", "token"]):
        context_parts.append(
            "SECURITY REMINDER:\n"
            "- Never hardcode secrets - use environment variables\n"
            "- Validate and sanitize all user inputs\n"
            "- Use parameterized queries for database operations"
        )

    if any(k in prompt for k in ["test", "coverage", "pytest"]):
        context_parts.append(
            "TESTING GUIDELINES:\n"
            "- Test behavior, not implementation\n"
            "- Include edge cases: empty inputs, null values, boundaries\n"
            "- For ML: test with fixed random seeds for reproducibility"
        )

    if any(k in prompt for k in ["train", "model", "jax", "flax"]):
        context_parts.append(
            "ML TRAINING CHECKLIST:\n"
            "- Set random seeds for reproducibility\n"
            "- Use gradient clipping (optax.clip_by_global_norm)\n"
            "- Monitor for NaN/Inf in gradients\n"
            "- Checkpoint frequently with Orbax"
        )

    if any(k in prompt for k in ["refactor", "clean", "restructure"]):
        context_parts.append(
            "REFACTORING GUIDELINES:\n"
            "- Ensure tests pass before and after\n"
            "- Make small, incremental changes\n"
            "- Avoid mixing refactoring with feature changes\n"
            "- Use git commits to checkpoint progress"
        )

    if context_parts:
        result.with_context({"additionalContext": "\n\n".join(context_parts)})

    return result


def context7_docs(inp: HookInput) -> HookResult:
    """Suggest Context7 documentation lookup."""
    result = HookResult()

    hook_event = inp.hook_event_name or ""

    if hook_event == "UserPromptSubmit" and inp.prompt:
        prompt = inp.prompt.lower()

        if "context7" in prompt:
            return result

        doc_triggers = [
            "how do i",
            "how to",
            "how can i",
            "documentation",
            "docs",
            "api",
            "examples",
            "tutorial",
            "guide",
            "getting started",
            "learn",
            "show me how",
        ]
        is_doc_question = any(t in prompt for t in doc_triggers)

        for lib in KNOWN_LIBS:
            if lib in prompt:
                if is_doc_question:
                    result.with_context(
                        {
                            "additionalContext": (
                                f"Use Context7 MCP for up-to-date {lib} docs: "
                                f"resolve-library-id('{lib}') then get-library-docs()"
                            )
                        }
                    )
                    return result
                elif "?" in prompt:
                    result.with_context(
                        {
                            "additionalContext": (
                                f"Consider using Context7 MCP for current {lib} documentation if needed."
                            )
                        }
                    )
                    return result

    elif hook_event == "PreToolUse":
        if inp.tool_name not in ("Edit", "Write"):
            return result

        if not inp.file_path or not inp.file_path.endswith(".py"):
            return result

        content = (inp.content or inp.new_string or "").lower()

        for lib in KNOWN_LIBS:
            if lib in content and re.search(rf"{lib}\.([a-z_]+)\(", content):
                result.warn(
                    f"NOTE: Code uses {lib} APIs. If unsure about function signatures, verify with Context7 MCP."
                )
                return result

    return result
