# ============================================================================
# External Tool Integration
# ============================================================================

# UV (Python package manager)
if command -v uv &> /dev/null; then
    eval "$(uv generate-shell-completion zsh)"
    
    # Fix completions for uv run
    _uv_run_mod() {
        if [[ "$words[2]" == "run" && "$words[CURRENT]" != -* ]]; then
            _arguments '*:filename:_files'
        else
            _uv "$@"
        fi
    }
    compdef _uv_run_mod uv
fi

# NVM
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# GPG Agent for SSH
if command -v gpgconf &> /dev/null; then
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    gpgconf --launch gpg-agent
fi

# Cargo/Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# iTerm2 Integration (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
fi

# FZF
if command -v fzf &> /dev/null; then
    # Source fzf key bindings and completion
    if [[ "$OSTYPE" == "darwin"* ]]; then
        [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    else
        [ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
        [ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
    fi
    
    # Set default options
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
    
    # Use ripgrep for better file searching
    if command -v rg &> /dev/null; then
        export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
fi

# Eza (better ls)
if command -v eza &> /dev/null; then
    alias ls='eza --icons'
    alias ll='eza -l --icons'
    alias la='eza -la --icons'
    alias lt='eza --tree --icons'
fi

# Bat (better cat)
if command -v bat &> /dev/null; then
    alias cat='bat'
    export BAT_THEME="TwoDark"
fi

# Git Delta
if command -v delta &> /dev/null; then
    export GIT_PAGER='delta'
fi