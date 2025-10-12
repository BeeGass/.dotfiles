#!/usr/bin/env bash
set -euo pipefail

# --- Main installation function ---
main() {
    echo "[Termux] Starting installation..."
    install_pkgs
    setup_configs
    install_termux_zsh_plugins
    echo "[Termux] Complete."
}

# --- Helper functions ---

# Install packages from Termux repository
install_pkgs() {
    echo "[Termux] Updating and installing packages with pkg..."
    pkg update -y && pkg upgrade -y
    pkg install x11-repo science-repo game-repo root-repo

    local pkgs=(
        awk bat chafa coreutils curl eza fd file findutils fzf gh git gnupg grep jq
        lsd neofetch openssh openssl pinentry-curses ripgrep sed shellcheck shfmt tar
        termux-api tmux tree unzip w3m wget which zsh
    )
    for p in "${packages[@]}"; do
        if apt-cache show "$p" >/dev/null 2>&1; then
            pkg install -y "$p"
        else
            echo "  → skipping missing package: $p"
        fi
    done
    pkg update -y && pkg upgrade -y
}

install_termux_zsh_plugins() {
  mkdir -p ~/.zsh
  if [[ ! -d ~/.zsh/zsh-autosuggestions ]]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
  fi
  if [[ ! -d ~/.zsh/zsh-syntax-highlighting ]]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
  fi
  # Source them (guarded) from your local zsh overrides
  {
    echo '[[ -r ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh'
    echo '[[ -r ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
  } >> "$HOME/.zshrc"
}

install_zsh_plugins_termux() {
  echo "[Termux] Installing Zsh plugins (git clones)..."
  local plugdir="$HOME/.zsh/plugins"
  mkdir -p "$plugdir"

  if [[ ! -d "$plugdir/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$plugdir/zsh-autosuggestions"
  fi
  if [[ ! -d "$plugdir/zsh-syntax-highlighting" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$plugdir/zsh-syntax-highlighting"
  fi
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

    install_zsh_plugins_termux
}

# --- Run the main function ---
main
