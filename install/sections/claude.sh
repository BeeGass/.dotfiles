#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  # Alias for refresh.sh compatibility
  DOT="$DOTFILES_DIR"

  section "Claude Code"

  # Check common Claude Code install locations
  claude_bin=""
  if have claude; then
    claude_bin="$(command -v claude)"
  elif [[ -x "$HOME/.local/bin/claude" ]]; then
    claude_bin="$HOME/.local/bin/claude"
  elif [[ -x "$HOME/.claude/local/bin/claude" ]]; then
    claude_bin="$HOME/.claude/local/bin/claude"
  elif [[ -x "/usr/local/bin/claude" ]]; then
    claude_bin="/usr/local/bin/claude"
  fi

  if [[ -n "$claude_bin" ]]; then
    note "Claude Code installed at $claude_bin"
    version=$("$claude_bin" --version 2>/dev/null || echo "unknown")
    ok "Claude Code present: $version"
  else
    warn "Claude Code not found"
    note "Install with: curl -fsSL https://claude.ai/install.sh | bash"
  fi

  # Check and fix Claude config symlinks
  dotfiles_claude="$DOT/claude"

  if [[ ! -d "$dotfiles_claude" ]]; then
    note "Claude dotfiles not found; skipping config check"
    exit 0
  fi

  step "Checking Claude config symlinks"

  # Check files (using _symlink_claude_file from lib.sh)
  _symlink_claude_file "CLAUDE.md" "CLAUDE.md"
  _symlink_claude_file "settings.json" "settings.json"
  _symlink_claude_file ".mcp.json" ".mcp.json"

  # Check directories (using _symlink_claude_dir from lib.sh)
  _symlink_claude_dir "docs"
  _symlink_claude_dir "hooks"
  _symlink_claude_dir "statusline"
  _symlink_claude_dir "templates"
  _symlink_claude_dir "commands"
}

main "$@"
