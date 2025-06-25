# ============================================================================
# Aliases
# ============================================================================

# Editor shortcuts
alias n="nvim"
alias zshfig="nvim ~/.dotfiles/zsh/zshrc"
alias zshconfig="cd ~/.dotfiles && nvim"

# Security/GPG
alias yubioath='ykman oath accounts list'
alias keyconfirm='gpg-connect-agent updatestartuptty /bye; export GPG_TTY=$(tty); export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket); gpgconf --launch gpg-agent; ssh-add -l'
alias gpgmesg='gpg -se -r recipient_userid'

# Git (dotfiles)
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# UV/Python
alias mkuv="uv venv"
alias activateuv="source .venv/bin/activate"
alias uvrun="uv run"
alias uvsync="uv sync"
alias uvlock="uv lock"
alias uvtool="uv tool"

# Better defaults (will be overridden by eza/bat if installed)
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias ls='ls -G'
else
    alias ls='ls --color=auto'
fi
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# OS-specific aliases
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'
fi