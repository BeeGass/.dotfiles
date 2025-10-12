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
alias nf="$HOME/.dotfiles/script/neofetch_random.sh"

# Smart ls fallback: prefer eza → lsd → ls
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --classify --group-directories-first'
    alias ll='eza -lgh --icons --group-directories-first'
    alias la='eza -lgha --icons --group-directories-first'
elif command -v lsd >/dev/null 2>&1; then
    alias ls='lsd --classify'
    alias ll='lsd -l --group-dirs=first'
    alias la='lsd -la --group-dirs=first'
else
    alias ll='ls -l'
    alias la='ls -la'
    if [[ "$OSTYPE" == "darwin"* ]]; then
        alias ls='ls -G'
    else
        alias ls='ls --color=auto'
    fi
fi
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Detect Termux without assumptions elsewhere
if [[ -n "$TERMUX_VERSION" ]]; then
  # Faster key-chord recognition on mobile keyboards
  export KEYTIMEOUT=1

  # Handy Android bridges
  alias open='termux-open'            # open files/URLs
  alias clip='termux-clipboard-set'   # pipe to clipboard
  alias paste='termux-clipboard-get'  # read from clipboard

  # In case tmux terminfo is fussy on Android
  export TERM=xterm-256color
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS-specific aliases
    alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

# OS-specific aliases
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'
fi
