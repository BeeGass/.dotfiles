#!/usr/bin/env bash
# Minimal bootstrap script for fresh machines
# Usage: curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/bootstrap.sh | bash
#        curl ... | bash -s -- --no-sudo

set -euo pipefail

REPO_URL="https://github.com/BeeGass/.dotfiles"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
NO_SUDO=false

log() { printf '[bootstrap] %s\n' "$*"; }

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --no-sudo) NO_SUDO=true ;;
        esac
    done
}

detect_os() {
    if [[ "$OSTYPE" == darwin* ]]; then
        echo "macos"
    elif [[ -n "${TERMUX_VERSION:-}" ]]; then
        echo "termux"
    elif [[ -f /etc/os-release ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

install_git() {
    if command -v git &>/dev/null; then
        log "git already installed"
        return
    fi

    local os
    os=$(detect_os)
    log "Installing git for $os..."

    case "$os" in
        macos)
            xcode-select --install 2>/dev/null || true
            log "Waiting for Xcode Command Line Tools installation..."
            until command -v git &>/dev/null; do sleep 5; done
            ;;
        linux)
            if $NO_SUDO; then
                log "ERROR: git not found and --no-sudo specified"
                exit 1
            fi
            sudo apt-get update && sudo apt-get install -y git
            ;;
        termux)
            pkg install -y git
            ;;
        *)
            log "ERROR: Cannot install git on unknown OS"
            exit 1
            ;;
    esac
}

install_just() {
    if command -v just &>/dev/null; then
        log "just already installed"
        return
    fi

    log "Installing just..."
    mkdir -p "$HOME/.local/bin"

    if command -v cargo &>/dev/null; then
        cargo install just
    else
        curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to "$HOME/.local/bin"
    fi

    export PATH="$HOME/.local/bin:$PATH"
}

clone_or_update_repo() {
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        log "Dotfiles repo exists, pulling latest..."
        git -C "$DOTFILES_DIR" pull --ff-only
    else
        log "Cloning dotfiles repo..."
        git clone "$REPO_URL" "$DOTFILES_DIR"
    fi
}

main() {
    parse_args "$@"
    log "Starting bootstrap (no-sudo=$NO_SUDO)"

    install_git
    install_just
    clone_or_update_repo

    cd "$DOTFILES_DIR"
    log "Running just install..."
    if $NO_SUDO; then
        just install --no-sudo
    else
        just install
    fi

    log "Bootstrap complete"
}

main "$@"
