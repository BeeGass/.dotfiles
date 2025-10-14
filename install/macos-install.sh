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
    section "[macOS] Start"
    install_homebrew
    install_homebrew_packages
    setup_kitty_cli_and_config
    create_open_here_in_kitty_app
    enable_kitty_autostart_tmux
    setup_configs
    section "[macOS] Complete"
}

# --- Helper functions ---------------------------------------------------------

install_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        step "Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        note "Homebrew already installed"
    fi

    BREW="$(command -v brew || true)"
    if [[ -z "${BREW:-}" ]]; then
        for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [[ -x "$p" ]] && BREW="$p" && break
        done
    fi
    if [[ -z "${BREW:-}" ]]; then
        err "[macOS] Homebrew not found after install"
        exit 1
    fi

    eval "$("$BREW" shellenv)"
    export BREW
    ok "Homebrew ready at: $BREW"
}

install_homebrew_packages() {
  section "[macOS] Install packages via Homebrew"
  brew update

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
cask "ghostty"
cask "iterm2"
cask "kitty"
EOF

  "$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
  ok "Homebrew packages installed"
}

setup_kitty_cli_and_config() {
  section "[macOS] Wire Kitty CLI"
  local app=""
  for p in "$HOME/Applications/kitty.app" "/Applications/kitty.app"; do
    [[ -d "$p" ]] && app="$p" && break
  done
  if [[ -z "$app" ]]; then
    warn "kitty.app not found; skipping CLI wiring"
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sfn "$app/Contents/MacOS/kitty"  "$HOME/.local/bin/kitty"
  ln -sfn "$app/Contents/MacOS/kitten" "$HOME/.local/bin/kitten"
  export PATH="$HOME/.local/bin:$PATH"
  ok "Linked kitty/kitten into ~/.local/bin"

  mkdir -p "$HOME/.config/kitty"
  if [[ ! -e "$HOME/.config/kitty/kitty.conf" && -f "$HOME/.dotfiles/kitty/kitty.conf" ]]; then
    ln -sfn "$HOME/.dotfiles/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    ok "Linked kitty.conf from dotfiles"
  else
    note "kitty.conf already exists or not provided in dotfiles"
  fi
}

create_open_here_in_kitty_app() {
  section "[macOS] Create 'Open Here in Kitty' app"
  mkdir -p "$HOME/Applications"
  local app="$HOME/Applications/Open Here in Kitty.app"
  local tmp
  tmp="$(mktemp -t kitty_open_hereXXXXX.applescript)"

  cat > "$tmp" <<'AS'
on run
  my open_in_kitty("")
end run

on open droppedItems
  if (count of droppedItems) > 0 then
    set p to POSIX path of (item 1 of droppedItems as alias)
    my open_in_kitty(p)
  else
    my open_in_kitty("")
  end if
end open

on open_in_kitty(initialPath)
  set dirPath to initialPath
  if dirPath is "" then
    tell application "Finder"
      if exists Finder window 1 then
        set dirPath to POSIX path of (target of front Finder window as alias)
      else
        set dirPath to POSIX path of (path to home folder)
      end if
    end tell
  else
    set isDir to do shell script "test -d " & quoted form of dirPath & " && echo dir || echo file"
    if isDir is "file" then
      set dirPath to do shell script "dirname " & quoted form of dirPath
    end if
  end if

  set kittyApp to do shell script "ls -d $HOME/Applications/kitty.app /Applications/kitty.app 2>/dev/null | head -n1"
  if kittyApp is "" then
    display dialog "kitty.app not found in Applications." buttons {"OK"} default button 1
    return
  end if

  do shell script "/usr/bin/open -na " & quoted form of kittyApp & " --args --directory " & quoted form of dirPath
end open_in_kitty
AS

  /usr/bin/osacompile -o "$app" "$tmp"
  rm -f "$tmp"
  ok "Created app: $app"
}

enable_kitty_autostart_tmux() {
  section "[macOS] Enable Kitty autostart tmux"
  local conf="$HOME/.config/kitty/kitty.conf"
  mkdir -p "$(dirname "$conf")"
  touch "$conf"
  if ! grep -qE '^\s*shell\s+tmux\b' "$conf"; then
    {
      echo ""
      echo "# --- Auto-start tmux on macOS ---"
      echo "shell tmux -u new-session -A -s main"
    } >> "$conf"
    ok "Appended tmux autostart to kitty.conf"
  else
    note "tmux autostart already configured"
  fi
}

setup_configs() {
    section "[macOS] Dotfile configs"
    mkdir -p ~/.config/neofetch
    ln -sfn ~/.dotfiles/neofetch/desktop-neofetch.conf ~/.config/neofetch/config.conf
    ok "neofetch config linked"
}

main
