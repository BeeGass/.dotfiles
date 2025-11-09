#!/usr/bin/env bash
set -euo pipefail

# --- Colors & Logging ----------------------------------------------------------
_use_color=1
if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then _use_color=0; fi
if [[ $_use_color -eq 1 ]] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
  BOLD=$(tput bold); RESET=$(tput sgr0); DIM=$(tput dim)
  RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4); MAGENTA=$(tput setaf 5); CYAN=$(tput setaf 6)
else
  BOLD=$'\033[1m'; RESET=$'\033[0m'; DIM=$'\033[2m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'
  [[ $_use_color -eq 0 ]] && BOLD='' && RESET='' && DIM='' && RED='' && GREEN='' && YELLOW='' && BLUE='' && MAGENTA='' && CYAN=''
fi
section() { printf "%s==>%s %s%s%s\n" "$CYAN$BOLD" "$RESET" "$BOLD" "$*" "$RESET"; }
step()    { printf "  %s->%s %s\n"     "$BLUE$BOLD" "$RESET" "$*"; }
ok()      { printf "  %s[ok]%s %s\n"   "$GREEN$BOLD" "$RESET" "$*"; }
warn()    { printf "  %s[warn]%s %s\n" "$YELLOW$BOLD" "$RESET" "$*"; }
err()     { printf "  %s[err ]%s %s\n" "$RED$BOLD" "$RESET" "$*"; }
note()    { printf "  %s%s%s\n"        "$DIM" "$*" "$RESET"; }

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
    section "[RaspberryPi] Configure SSH server"

    if ! command -v sshd >/dev/null 2>&1; then
        warn "sshd not found; ensure openssh-server is installed"
        return 1
    fi

    step "Creating SSH config drop-in directory"
    sudo mkdir -p /etc/ssh/sshd_config.d

    step "Symlinking YubiKey SSH configuration"
    if [[ -f "$HOME/.dotfiles/ssh/99-yubikey-only.conf" ]]; then
        sudo ln -sf "$HOME/.dotfiles/ssh/99-yubikey-only.conf" /etc/ssh/sshd_config.d/99-yubikey-only.conf
        ok "Symlinked SSH config to /etc/ssh/sshd_config.d/"
    else
        warn "~/.dotfiles/ssh/99-yubikey-only.conf not found; skipping"
        return 0
    fi

    step "Verifying main sshd_config has Include directive"
    if ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
        warn "Include directive not found in sshd_config; may need manual configuration"
    else
        ok "Include directive present"
    fi

    step "Disabling SSH socket activation (conflicts with custom port)"
    if systemctl is-enabled ssh.socket >/dev/null 2>&1; then
        sudo systemctl stop ssh.socket
        sudo systemctl disable ssh.socket
        ok "Disabled ssh.socket"
    else
        note "ssh.socket not enabled"
    fi

    step "Enabling and restarting SSH service"
    sudo systemctl enable ssh
    sudo systemctl restart ssh || sudo systemctl restart sshd

    step "Verifying SSH is listening on port 40822"
    if sudo ss -tlnp | grep -q ":40822"; then
        ok "SSH server listening on port 40822"
    else
        warn "SSH may not be listening on port 40822; check configuration"
    fi
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
    section "[RaspberryPi] Complete"
}
main
