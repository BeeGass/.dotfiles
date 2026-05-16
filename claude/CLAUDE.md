# Global Development Guidelines

- Never mention being an AI, Anthropic, or "Claude" in code, comments, or commits
- No emojis in code or comments
- Prioritize correctness and maintainability over cleverness
- Dotfiles managed at @~/.dotfiles/ (symlinked to target locations)
- Three Claude config instances: `~/.claude/`, `~/.claude-alt/`, `~/.claude-main/` — share `settings.json`, `CLAUDE.md`, `commands`, `hooks`, `rules`, `statusline`, `templates`, and `.mcp.json` via symlinks to `~/.dotfiles/claude/`; state (sessions, history, plugins, projects, tasks) is independent per instance
- Machine-specific config at @~/.claude/CLAUDE.local.md
- New plugin extensions go in @~/Projects/beegass-claude-plugins/ (unless explicitly for FreeCtrl, which uses @~/Projects/freectrl-claude-plugins/):
  1. Skills
  2. Agents (subagents)
  3. Hooks
  4. MCP servers
  5. LSP servers
  6. Output styles
  7. Commands

## Memory Convention

- Project memory lives in the repo at `.claude/memory/`, distributed per-package for monorepos. The harness per-project memory path symlinks to the repo for backward compatibility.
- In `freectrl`, see `.claude/rules/auto-memory.md` for the 3-tier placement rule (package / root cross-cutting / harness-global).
- Harness-global memory (doc/commit conventions, Claude Code config audits) lives in `~/<harness>/memory/` and is never committed.
- For other projects, follow the same convention: source of truth in the repo, symlink from the harness.
