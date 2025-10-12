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

# Install Homebrew if not already installed, and expose it as $BREW
install_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Resolve brew path (Apple Silicon: /opt/homebrew; Intel: /usr/local)
    BREW="$(command -v brew || true)"
    if [[ -z "${BREW:-}" ]]; then
        for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [[ -x "$p" ]] && BREW="$p" && break
        done
    fi
    if [[ -z "${BREW:-}" ]]; then
        echo "[macOS] ERROR: Homebrew not found after install." >&2
        exit 1
    fi

    # Put brew on PATH for this shell
    eval "$("$BREW" shellenv)"
    export BREW
}

# Install packages and casks from a Brewfile-like heredoc
install_homebrew_packages() {
  echo "[macOS] Installing packages via Homebrew..."
  brew update

  # No cask-fonts tap — it's deprecated.
  brew bundle --file=/dev/stdin <<'EOF'
tap "jandedobbeleer/oh-my-posh"

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
brew "pfetch"
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

cask "font-jetbrains-mono-nerd-font"
EOF

  # fzf bindings/completions
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
