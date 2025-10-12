#!/usr/bin/env bash
set -euo pipefail

# --- Main installation function ---
main() {
    echo "[Termux] Starting installation..."
    install_pkgs
    setup_configs
    echo "[Termux] Complete."
}

# --- Helper functions ---

# Install packages from Termux repository
install_pkgs() {
    echo "[Termux] Updating and installing packages with pkg..."
    pkg update -y
    pkg upgrade -y

    local packages=(
        # Sorted alphabetically
        awk
        bat
        chafa
        coreutils
        curl
        delta
        eza
        fd
        file
        findutils
        fzf
        gh
        git
        gnupg
        grep
        jq
        lsd
        neofetch
        openssl
        pinentry
        ripgrep
        sed
        shellcheck
        shfmt
        tar
        termux-api
        tmux
        tree
        unzip
        w3m
        wget
        which
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
    )
    pkg install -y "${packages[@]}"
}

# Set up configuration files and symlinks
setup_configs() {
    echo "[Termux] Setting up configurations..."
    mkdir -p ~/.config/neofetch
    ln -sfn ~/.dotfiles/neofetch/termux-neofetch.conf ~/.config/neofetch/config.conf

    # Optional Nerd Font for glyphs (applied as Termux font)
    if [ ! -f "$HOME/.termux/font.ttf" ]; then
        mkdir -p "$HOME/.termux"
        curl -fsSL -o "$HOME/.termux/font.ttf" \
          "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" 2>/dev/null \
          && (cd /tmp && unzip -o "$HOME/.termux/font.ttf" >/dev/null 2>&1) || true
        # Fallback: if the above zip trick fails, fetch a prebuilt TTF
        curl -fsSL -o "$HOME/.termux/font.ttf" \
          "https://github.com/ryanoasis/nerd-fonts/raw/refs/heads/master/patched-fonts/JetBrainsMono/Regular/JetBrainsMonoNerdFont-Regular.ttf" || true
    fi

    # Reload Termux settings to apply any changes (e.g., fonts, colors)
    if command -v termux-reload-settings >/dev/null 2>&1; then
        echo "Reloading Termux settings..."
        termux-reload-settings
    fi
}

# --- Run the main function ---
main
