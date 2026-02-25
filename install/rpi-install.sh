#!/usr/bin/env bash
set -euo pipefail
source "${BASH_SOURCE[0]%/*}/lib.sh"

# --- Helper functions ----------------------------------------------------------

setup_apt() {
    section "[RaspberryPi] Configure APT repositories"
    step "Updating base indexes and installing apt helpers"
    sudo apt update
    sudo apt install -y --no-install-recommends software-properties-common ca-certificates gnupg

    step "Updating package lists"
    sudo apt update
    ok "APT ready"
}

install_apt_packages() {
    section "[RaspberryPi] Install packages via apt"
    local packages=(
        bat
        build-essential
        ca-certificates
        chafa
        curl
        fd-find
        file
        fzf
        gh
        git
        git-delta
        gnupg
        jq
        neofetch
        neovim
        openssh-client
        openssh-server
        openssl
        pcscd
        pinentry-curses
        pkg-config
        ripgrep
        scdaemon
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
    step "Installing ${#packages[@]} packages"
    sudo apt install -y "${packages[@]}" || true
    ok "Server packages installed"
}

install_claude_code() {
    section "[RaspberryPi] Install Claude Code"

    if command -v claude >/dev/null 2>&1; then
        note "Claude Code already installed"
        return 0
    fi

    step "Installing Claude Code via official installer"
    if curl -fsSL https://claude.ai/install.sh | bash; then
        ok "Installed Claude Code"
    else
        warn "Failed to install Claude Code"
    fi
}

setup_symlinks() {
    section "[RaspberryPi] Command symlinks"
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        step "Linking fdfind -> fd"
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    else
        note "fd/fdfind already set"
    fi
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        step "Linking batcat -> bat"
        sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
    else
        note "bat/batcat already set"
    fi

    step "Configuring neofetch"
    mkdir -p ~/.config/neofetch
    ln -sfn ~/.dotfiles/neofetch/desktop-neofetch.conf ~/.config/neofetch/config.conf
    ok "Symlinks and neofetch config ready"
}

setup_directories() {
    section "[RaspberryPi] User directories"

    # Create standard directories
    step "Creating Projects directory"
    mkdir -p "$HOME/Projects"
    ok "Ensured Projects directory exists"
}

setup_ssh_server() {
    setup_ssh_server_common "Raspberry Pi"
}

setup_git_credential_helper() {
    section "[RaspberryPi] Configure Git credential helper"

    step "Symlinking Linux Git config to ~/.gitconfig.local"
    ln -sf "$HOME/.dotfiles/git/gitconfig.linux" "$HOME/.gitconfig.local"
    ok "Git credential helper configured: store"
}

# --- Main ---------------------------------------------------------------------
main() {
    section "[RaspberryPi] Start"
    setup_apt
    install_apt_packages
    install_claude_code
    setup_symlinks
    setup_directories
    setup_ssh_server
    setup_git_credential_helper
    section "[RaspberryPi] Complete"
}
main
