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

# --- Main ---------------------------------------------------------------------
main() {
    section "[Termux] Start"
    install_pkgs
    setup_configs
    install_termux_zsh_plugins
    section "[Termux] Complete"
}

# --- Helper functions ---------------------------------------------------------

install_pkgs() {
    section "[Termux] Update & install packages"
    step "Updating and upgrading repositories"
    pkg update -y && pkg upgrade -y

    step "Enabling extra repositories"
    pkg install -y x11-repo science-repo game-repo root-repo || true

    local pkgs=(
        awk bat chafa coreutils curl eza fd file findutils fzf gh git gnupg grep jq
        lsd neofetch openssh openssl pinentry-curses ripgrep sed shellcheck shfmt tar
        termux-api tmux tree unzip w3m wget which zsh
    )
    step "Installing ${#pkgs[@]} packages"
    for p in "${pkgs[@]}"; do
        if apt-cache show "$p" >/dev/null 2>&1; then
            pkg install -y "$p"
        else
            warn "Skipping missing package: $p"
        fi
    done

    step "Final update/upgrade pass"
    pkg update -y && pkg upgrade -y
    ok "Packages installed"
}

install_termux_zsh_plugins() {
  section "[Termux] Zsh plugins (~/.zsh/*)"
  mkdir -p ~/.zsh
  if [[ ! -d ~/.zsh/zsh-autosuggestions ]]; then
    step "Cloning zsh-autosuggestions"
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
  else
    note "zsh-autosuggestions already present"
  fi
  if [[ ! -d ~/.zsh/zsh-syntax-highlighting ]]; then
    step "Cloning zsh-syntax-highlighting"
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
  else
    note "zsh-syntax-highlighting already present"
  fi

  step "Ensuring plugins are sourced from ~/.zshrc"
  {
    echo '[[ -r ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh'
    echo '[[ -r ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
  } >> "$HOME/.zshrc"
  ok "Zsh plugins installed and referenced"
}

install_zsh_plugins_termux() {
  # (Kept for compatibility with your earlier layout; invoked from setup_configs)
  section "[Termux] Zsh plugins (~/.zsh/plugins/*)"
  local plugdir="$HOME/.zsh/plugins"
  mkdir -p "$plugdir"

  if [[ ! -d "$plugdir/zsh-autosuggestions" ]]; then
    step "Cloning zsh-autosuggestions → ~/.zsh/plugins"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$plugdir/zsh-autosuggestions"
  else
    note "zsh-autosuggestions already present in ~/.zsh/plugins"
  fi
  if [[ ! -d "$plugdir/zsh-syntax-highlighting" ]]; then
    step "Cloning zsh-syntax-highlighting → ~/.zsh/plugins"
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$plugdir/zsh-syntax-highlighting"
  else
    note "zsh-syntax-highlighting already present in ~/.zsh/plugins"
  fi
}

setup_configs() {
    section "[Termux] Dotfile configs"
    step "Linking neofetch config"
    mkdir -p ~/.config/neofetch
    ln -sfn ~/.dotfiles/neofetch/termux-neofetch.conf ~/.config/neofetch/config.conf

    step "Ensuring Nerd Font (Termux font)"
    if [ ! -f "$HOME/.termux/font.ttf" ]; then
        mkdir -p "$HOME/.termux"
        # Try zip first (may fail harmlessly), then fetch a direct TTF fallback
        if ! curl -fsSL -o "$HOME/.termux/font.ttf" \
          "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" 2>/dev/null; then
          note "Zip fetch failed or unsuitable; trying direct TTF"
        fi
        curl -fsSL -o "$HOME/.termux/font.ttf" \
          "https://github.com/ryanoasis/nerd-fonts/raw/refs/heads/master/patched-fonts/JetBrainsMono/Regular/JetBrainsMonoNerdFont-Regular.ttf" || true
    else
        note "Termux font already present"
    fi

    if command -v termux-reload-settings >/dev/null 2>&1; then
        step "Reloading Termux settings"
        termux-reload-settings || true
    fi

    install_zsh_plugins_termux
    ok "Configs applied"
}

main
