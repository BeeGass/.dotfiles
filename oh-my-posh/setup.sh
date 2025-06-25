#!/bin/bash

# Oh-My-Posh Setup Script
# This script helps transition from oh-my-zsh to oh-my-posh while preserving functionality
# Works on both macOS and Linux

echo "Oh-My-Posh Setup Script"
echo "======================"
echo ""

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=macOS;;
    *)          OS_TYPE="UNKNOWN:${OS}"
esac
echo "Detected OS: ${OS_TYPE}"
echo ""

# Create backup of current .zshrc
echo "1. Creating backup of current .zshrc..."
cp ~/.zshrc ~/.zshrc.oh-my-zsh.backup.$(date +%Y%m%d_%H%M%S)

# Create new .zshrc with oh-my-posh
echo "2. Creating new .zshrc configuration..."

cat > ~/.zshrc.oh-my-posh << 'EOF'
# ============================================================================
# Oh-My-Posh Configuration for ZSH
# ============================================================================

# Path to your oh-my-posh configuration
export OH_MY_POSH_CONFIG="$HOME/.config/oh-my-posh/config.json"

# Initialize oh-my-posh
eval "$(oh-my-posh init zsh --config $OH_MY_POSH_CONFIG)"

# ============================================================================
# Environment Variables (preserved from oh-my-zsh)
# ============================================================================

# GPG Configuration
export GPG_TTY=$(tty)
export KEYID=0xA34200D828A7BB26
export S_KEYID=0xACC3640C138D96A2
export E_KEYID=0x21691AE75B0463CC
export A_KEYID=0x27D667E55F655FD2

# Node Version Manager
export NVM_DIR="$HOME/.nvm"

# ============================================================================
# Path Configuration
# ============================================================================

# Add custom paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# OS-specific paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific paths
    export PATH="/Users/beegass/.julia/juliaup/bin:$PATH"
else
    # Linux specific paths
    export PATH="$HOME/.julia/juliaup/bin:$PATH"
fi

# ============================================================================
# ZSH Plugins (oh-my-posh compatible alternatives)
# ============================================================================

# Detect package manager prefix
if command -v brew &> /dev/null; then
    PLUGIN_PREFIX="$(brew --prefix)"
elif [[ -d "/usr/share" ]]; then
    PLUGIN_PREFIX="/usr"
fi

# Enable syntax highlighting
if [[ -f "${PLUGIN_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "${PLUGIN_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [[ -f "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Enable autosuggestions
if [[ -f "${PLUGIN_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${PLUGIN_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [[ -f "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Enable vi-mode
bindkey -v

# Better vi-mode search
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# ============================================================================
# Aliases (preserved from oh-my-zsh)
# ============================================================================

alias n="nvim"
alias yubioath='ykman oath accounts list'
alias zshfig="nvim ~/.zshrc"
alias keyconfirm='gpg-connect-agent updatestartuptty /bye; export GPG_TTY=$(tty); export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket); gpgconf --launch gpg-agent; ssh-add -l'
alias gpgmesg='gpg -se -r recipient_userid'
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# UV aliases (replacing poetry/pyenv workflow)
alias mkuv="uv venv"
alias activateuv="source .venv/bin/activate"
alias uvrun="uv run"
alias uvsync="uv sync"
alias uvlock="uv lock"
alias uvtool="uv tool"

# OS-specific aliases
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'
fi

# ============================================================================
# Functions (updated for uv)
# ============================================================================

# Create a new Python project with uv
uvnew() {
    if [ -z "$1" ]; then
        echo "Usage: uvnew <project-name> [python-version]"
        echo "Example: uvnew myproject 3.11"
        return 1
    fi
    
    local project_name="$1"
    local python_version="${2:-3.11}"
    
    mkdir -p "$project_name"
    cd "$project_name"
    uv init
    uv venv --python "$python_version"
    echo "Created new uv project: $project_name with Python $python_version"
}

# Install dependencies and activate virtual environment
uvsetup() {
    if [ -f "pyproject.toml" ]; then
        uv sync
        source .venv/bin/activate
        echo "Dependencies installed and virtual environment activated"
    else
        echo "No pyproject.toml found in current directory"
        return 1
    fi
}

# Sync all extras and upgrade lock file
uvupgrade() {
    if [ -f "pyproject.toml" ]; then
        echo "Syncing all extras and upgrading dependencies..."
        uv sync --all-extras && uv lock --upgrade
        echo "Dependencies upgraded and synced with all extras"
    else
        echo "No pyproject.toml found in current directory"
        return 1
    fi
}

allbranches() {
    git for-each-ref --format='%(refname:short)' refs/remotes | \
    while read remote; do 
        git switch --create "${remote#origin/}" --track "$remote" 2>/dev/null
    done
}

gpgmsg() {
    if [ -z "$1" ]; then
        echo "Usage: gpgmsg <recipient_email>"
        return 1
    fi
    gpg -se -r "$1"
}

# ============================================================================
# External Tool Integration
# ============================================================================

# UV (Python package manager)
if command -v uv &> /dev/null; then
    eval "$(uv generate-shell-completion zsh)"
fi

# NVM
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# GPG Agent for SSH
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent

# Cargo/Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# iTerm2 Integration (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
fi

# ============================================================================
# Additional ZSH Configuration
# ============================================================================

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY

# Completion system
autoload -Uz compinit
compinit

# Colored output for ls
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# Enable color support for various commands
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias ls='ls -G'
else
    alias ls='ls --color=auto'
fi
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ============================================================================
# Oh-My-Posh specific features
# ============================================================================

# Enable transient prompt (minimal prompt for previous commands)
enable-transient-prompt() {
    oh-my-posh toggle transient-prompt
}

# Reload oh-my-posh configuration
reload-omp() {
    eval "$(oh-my-posh init zsh --config $OH_MY_POSH_CONFIG)"
}

# Switch between different oh-my-posh themes
switch-theme() {
    local theme="$1"
    if [ -z "$theme" ]; then
        echo "Usage: switch-theme <theme-name>"
        echo "Available themes:"
        if command -v brew &> /dev/null; then
            ls $(brew --prefix oh-my-posh)/themes/ | grep -E '\.omp\.(json|yaml|toml)$' | sed 's/\.[^.]*$//'
        else
            ls /usr/share/oh-my-posh/themes/ | grep -E '\.omp\.(json|yaml|toml)$' | sed 's/\.[^.]*$//'
        fi
        return 1
    fi
    
    local theme_path
    if command -v brew &> /dev/null; then
        theme_path="$(brew --prefix oh-my-posh)/themes/${theme}.omp.json"
    else
        theme_path="/usr/share/oh-my-posh/themes/${theme}.omp.json"
    fi
    
    if [ -f "$theme_path" ]; then
        export OH_MY_POSH_CONFIG="$theme_path"
        reload-omp
        echo "Switched to theme: $theme"
    else
        echo "Theme not found: $theme"
        return 1
    fi
}

# Edit oh-my-posh configuration
edit-omp() {
    ${EDITOR:-nvim} "$OH_MY_POSH_CONFIG"
}

EOF

echo ""
echo "3. Setting up font configuration..."
echo ""
echo "To install Google Sans and Google Sans Mono fonts:"
echo "   a) Clone the font repositories:"
echo "      git clone git@github.com:hprobotic/Google-Sans-Font.git"
echo "      git clone git@github.com:mehant-kr/Google-Sans-Mono.git"
echo ""
if [[ "$OS_TYPE" == "macOS" ]]; then
    echo "   b) On macOS, install fonts by:"
    echo "      - Double-clicking the .ttf files in Finder"
    echo "      - Or copying to ~/Library/Fonts/"
    echo ""
    echo "   c) Configure iTerm2:"
    echo "      - Go to Preferences > Profiles > Text > Font"
    echo "      - Select 'Google Sans Mono' or 'Google Sans'"
else
    echo "   b) On Linux, install fonts by:"
    echo "      mkdir -p ~/.local/share/fonts"
    echo "      cp Google-Sans-Font/*.ttf ~/.local/share/fonts/"
    echo "      cp Google-Sans-Mono/*.ttf ~/.local/share/fonts/"
    echo "      fc-cache -f -v"
    echo ""
    echo "   c) Configure your terminal emulator to use the new fonts"
fi
echo ""

echo "4. Installing additional ZSH plugins..."

if [[ "$OS_TYPE" == "macOS" ]]; then
    # macOS installation using Homebrew
    if ! [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
        echo "   Installing zsh-syntax-highlighting..."
        brew install zsh-syntax-highlighting
    fi
    
    if ! [ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
        echo "   Installing zsh-autosuggestions..."
        brew install zsh-autosuggestions
    fi
else
    # Linux installation
    echo ""
    echo "   On Linux, install ZSH plugins using your package manager:"
    echo "   For Ubuntu/Debian:"
    echo "      sudo apt install zsh-syntax-highlighting zsh-autosuggestions"
    echo "   For Arch:"
    echo "      sudo pacman -S zsh-syntax-highlighting zsh-autosuggestions"
    echo "   For Fedora:"
    echo "      sudo dnf install zsh-syntax-highlighting zsh-autosuggestions"
fi

echo ""
echo "5. Setup complete!"
echo ""
echo "To switch to oh-my-posh, run:"
echo "   mv ~/.zshrc.oh-my-posh ~/.zshrc"
echo "   source ~/.zshrc"
echo ""
echo "To revert back to oh-my-zsh, run:"
echo "   mv ~/.zshrc.oh-my-zsh.backup.<timestamp> ~/.zshrc"
echo "   source ~/.zshrc"
echo ""
echo "Additional commands available:"
echo "   reload-omp      - Reload oh-my-posh configuration"
echo "   edit-omp        - Edit your oh-my-posh theme"
echo "   switch-theme    - Switch to a different theme"
echo ""
echo "UV Python commands:"
echo "   uvnew           - Create a new Python project with uv"
echo "   uvsetup         - Install dependencies and activate venv"
echo "   uvupgrade       - Sync all extras and upgrade dependencies"
echo "   mkuv            - Create a new virtual environment"
echo "   activateuv      - Activate the virtual environment"
echo ""