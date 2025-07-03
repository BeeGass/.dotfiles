# ============================================================================
# Claude-specific configuration and functions
# ============================================================================

# Source Claude functions if they exist
if [[ -f ~/.dotfiles/claude/claude-functions.zsh ]]; then
    source ~/.dotfiles/claude/claude-functions.zsh
fi

# Claude environment variables
export CLAUDE_PROJECT_ROOT="${HOME}/projects"
export CLAUDE_PYTHON_VERSION="3.11"
export UV_PYTHON_PREFERENCE="only-managed"