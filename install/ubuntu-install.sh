#!/usr/bin/env bash
set -euo pipefail

# --- Main execution function ---
main() {
    echo "[Ubuntu] Starting installation..."
    setup_apt
    install_apt_packages
    setup_symlinks
    echo "[Ubuntu] Complete."
}

# --- Helper functions ---

# Configure APT repositories
setup_apt() {
    echo "[Ubuntu] Configuring APT repositories..."
    sudo apt update
    sudo apt install -y --no-install-recommends software-properties-common ca-certificates gnupg

    local codename arch ms_keyring ms_sourcelist
    codename="$(lsb_release -cs)"
    arch="$(dpkg --print-architecture)"
    ms_keyring="/etc/apt/trusted.gpg.d/microsoft.gpg"
    ms_sourcelist="/etc/apt/sources.list.d/microsoft-prod.list"

    if [ ! -f "$ms_keyring" ]; then
        echo "Adding Microsoft GPG key..."
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o "$ms_keyring"
    fi
    if [ ! -f "$ms_sourcelist" ]; then
        echo "Adding Microsoft APT repo for ${codename} (${arch})..."
        echo "deb [arch=${arch}] https://packages.microsoft.com/repos/microsoft-ubuntu-${codename}-prod ${codename} main" | sudo tee "$ms_sourcelist"
    fi

    echo "Updating package lists..."
    sudo apt update
}

# Install packages from APT
install_apt_packages() {
    echo "[Ubuntu] Installing packages with apt..."
    local packages=(
        # Sorted alphabetically
        bat
        build-essential
        ca-certificates
        curl
        fd-find
        file
        fonts-jetbrains-mono
        fzf
        gh
        git
        git-delta
        gnome-keyring
        gnupg
        jq
        libsecret-1-0
        libsecret-1-dev
        neofetch
        openssh-client
        openssl
        pinentry-curses
        pkg-config
        ripgrep
        shellcheck
        shfmt
        tmux
        tree
        unzip
        w3m
        wget
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
    )
    sudo apt install -y "${packages[@]}" || true

    # If eza isn't available via apt on Jammy, try snap (optional)
    if ! command -v eza >/dev/null 2>&1; then
        command -v snap >/dev/null 2>&1 && sudo snap install eza --classic || true
    fi

    # Configure Git credentials via libsecret (GNOME Keyring), no GCM
    if ! command -v git-credential-libsecret >/dev/null 2>&1; then
        if [ -d /usr/share/doc/git/contrib/credential/libsecret ]; then
            echo "Building git-credential-libsecret..."
            sudo make -C /usr/share/doc/git/contrib/credential/libsecret >/dev/null
            sudo install -m 0755 /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret /usr/local/bin/
        else
            echo "WARN: libsecret helper sources not found at /usr/share/doc/git/contrib/credential/libsecret"
        fi
    fi
    if command -v git-credential-libsecret >/dev/null 2>&1; then
        echo "Configuring Git to use libsecret credential helper..."
        git config --global credential.helper libsecret
    else
        echo "WARN: git-credential-libsecret not available; credentials won't be persisted."
        echo "      You can temporarily use: git config --global credential.helper 'cache --timeout=3600'"
    fi
}

# Set up symlinks for command-line tools
setup_symlinks() {
    echo "[Ubuntu] Setting up symlinks..."
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
    fi
    # Optional: JetBrainsMono Nerd Font (for oh-my-posh glyphs)
    if [ ! -f "$HOME/.local/share/fonts/JetBrainsMonoNerd.ttf" ]; then
        mkdir -p "$HOME/.local/share/fonts"
        curl -fsSL -o /tmp/JBMNF.zip \
          "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" || true
        unzip -o /tmp/JBMNF.zip -d "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
        find "$HOME/.local/share/fonts" -name '*JetBrainsMono*Nerd*' -type f -exec bash -lc 'mv "$0" "${0%/*}/JetBrainsMonoNerd.ttf"' {} \; >/dev/null 2>&1 || true
        fc-cache -f >/dev/null 2>&1 || true
    fi
    mkdir -p ~/.config/neofetch
    ln -sfn ~/.dotfiles/neofetch/desktop-neofetch.conf ~/.config/neofetch/config.conf
}

# --- Run the main function ---
main
