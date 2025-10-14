# ============================================================================
# External Tool Integration (no aliases here—centralized in 40-aliases.zsh)
# ============================================================================

# UV (Python package manager) completions + smarter completion for `uv run`
if command -v uv &> /dev/null; then
  eval "$(uv generate-shell-completion zsh 2>/dev/null)" || true

  # Let `uv run <script>` complete filenames when appropriate
  _uv_run_mod() {
    if [[ "$words[2]" == "run" && "$words[CURRENT]" != -* ]]; then
      _arguments '*:filename:_files'
    else
      _uv "$@"
    fi
  }
  compdef _uv_run_mod uv
fi

# Cargo/Rust env
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# iTerm2 Integration (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
fi

# FZF key bindings + completion (prefer distro examples on Linux)
if command -v fzf &> /dev/null; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  else
    [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
  fi

  # Default fzf TUI ergonomics
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

  # Use ripgrep for file lists when present
  if command -v rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
fi

# Git Delta pager (don’t alias; keep pager config explicit)
if command -v delta &> /dev/null; then
  export GIT_PAGER='delta'
fi

# (Intentionally no `ls`/`cat`/`bat` aliases here—single source of truth is 40-aliases.zsh)
