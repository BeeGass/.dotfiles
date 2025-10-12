#!/usr/bin/env bash
set -euo pipefail

# --- Main installation function ---
main() {
    echo "[macOS] Starting installation..."
    install_homebrew
    install_homebrew_packages
    setup_configs
    echo "[macOS] Complete."
}

# --- Helper functions ---

# Install Homebrew if not already installed
install_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    # Ensure brew is in the PATH for this script's execution
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
    eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
}

# Install packages and casks from a Brewfile-like heredoc
install_homebrew_packages() {
    echo "[macOS] Installing packages via Homebrew..."
    brew update
    brew bundle --no-lock --file=/dev/stdin <<EOF
# Taps
tap "jandedobbeleer/oh-my-posh/oh-my-posh"
tap "homebrew/cask-fonts"

# Formulae
brew "bat"
brew "chafa"
brew "curl"
brew "eza"
brew "fd"
brew "fzf"
brew "gh"
brew "git"
brew "git-delta"
brew "gnupg"
brew "jq"
brew "lsd"
brew "neofetch"
brew "neovim"
brew "oh-my-posh"
brew "pfetch"  # Optional; skipped in install script
brew "pinentry-mac"
brew "pre-commit"
brew "ripgrep"
brew "shellcheck"
brew "shfmt"
brew "tmux"
brew "tree"
brew "unzip"
brew "w3m"
brew "wget"
brew "zsh"
brew "zsh-autosuggestions"
brew "zsh-history-substring-search"
brew "zsh-syntax-highlighting"

# Casks
cask "font-jetbrains-mono-nerd-font"
cask "git-credential-manager"
EOF

    # Install fzf keybindings and completions
    "$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
}

# Set up configuration files and symlinks
setup_configs() {
    echo "[macOS] Setting up configurations..."
    mkdir -p ~/.config/neofetch
    ln -sfn ~/.dotfiles/neofetch/desktop-neofetch.conf ~/.config/neofetch/config.conf
}

# --- Run the main function ---
main
