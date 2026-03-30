# Global Development Guidelines

- Never mention being an AI, Anthropic, or "Claude" in code, comments, or commits
- No emojis in code or comments
- Prioritize correctness and maintainability over cleverness
- Dotfiles managed at @~/.dotfiles/ (symlinked to target locations)
- Machine-specific config at @~/.claude/CLAUDE.local.md
- New plugin extensions go in @~/Projects/beegass-claude-plugins/ (unless explicitly for FreeCtrl, which uses @~/Projects/freectrl-claude-plugins/):
  1. Skills
  2. Agents (subagents)
  3. Hooks
  4. MCP servers
  5. LSP servers
  6. Output styles
  7. Commands

## Remote Control Services

Manifold runs persistent Claude Code Remote Control servers as systemd user services. Each appears as a separate environment in the Claude mobile app and claude.ai/code.

| Environment | Service | Directory |
|---|---|---|
| Manifold | `claude-rc-manifold` | `~/` |
| Manifold Projects | `claude-rc-projects` | `~/Projects` |
| Manifold FreeCtrl | `claude-rc-freectrl` | `~/Projects/FreeCtrl` |
| Manifold RSDE | `claude-rc-rsde` | `~/Projects/RSDE` |

Service files: `~/.config/systemd/user/claude-rc-*.service`

### Management (via SSH or terminal)

```bash
systemctl --user status claude-rc-*          # Status of all
systemctl --user stop claude-rc-freectrl     # Stop one
systemctl --user start claude-rc-freectrl    # Start one
systemctl --user restart claude-rc-manifold   # Restart one
```

### Notes

- All four auto-start on login and restart on failure
- Sessions are sandboxed to each service's working directory
- Each server supports up to 32 concurrent sessions
- Trust state is stored in `~/.claude.json` under `projects.<path>.hasTrustDialogAccepted`
