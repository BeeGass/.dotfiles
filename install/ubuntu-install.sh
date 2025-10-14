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
    section "[Ubuntu] Configure APT repositories"
    step "Updating base indexes and installing apt helpers"
    sudo apt update
    sudo apt install -y --no-install-recommends software-properties-common ca-certificates gnupg

    local codename arch ms_keyring ms_sourcelist
    codename="$(lsb_release -cs)"
    arch="$(dpkg --print-architecture)"
    ms_keyring="/etc/apt/trusted.gpg.d/microsoft.gpg"
    ms_sourcelist="/etc/apt/sources.list.d/microsoft-prod.list"

    if [ ! -f "$ms_keyring" ]; then
        step "Adding Microsoft GPG key"
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o "$ms_keyring"
        ok "Wrote $ms_keyring"
    else
        note "Microsoft key already present"
    fi
    if [ ! -f "$ms_sourcelist" ]; then
        step "Adding Microsoft repo for ${codename} (${arch})"
        echo "deb [arch=${arch}] https://packages.microsoft.com/repos/microsoft-ubuntu-${codename}-prod ${codename} main" | sudo tee "$ms_sourcelist" >/dev/null
        ok "Wrote $ms_sourcelist"
    else
        note "Microsoft repo already configured"
    fi

    step "Updating package lists"
    sudo apt update
    ok "APT ready"
}

install_apt_packages() {
    section "[Ubuntu] Install packages via apt"
    local packages=(
        bat
        build-essential
        ca-certificates
        chafa
        curl
        desktop-file-utils
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
        pinentry-gnome3
        picom
        pkg-config
        ripgrep
        shellcheck
        shfmt
        tmux
        tree
        unzip
        w3m
        wget
        xdg-utils
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
    )
    step "Installing ${#packages[@]} packages"
    sudo apt install -y "${packages[@]}" || true
    ok "Base packages installed"

    step "Running community Ghostty installer (best-effort)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)" || \
      warn "Community Ghostty installer exited non-zero (this can be normal on 22.04)"
}

install_kitty() {
    section "[Ubuntu] Install/Update Kitty"
    step "Invoking official installer"
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
    ok "Kitty installed/updated"
}

setup_kitty_desktop_integration() {
    section "[Ubuntu] Desktop integration for Kitty"
    local appdir="$HOME/.local/kitty.app"
    local localbin="$HOME/.local/bin"
    local applications_dir="$HOME/.local/share/applications"
    local icon_path="$appdir/share/icons/hicolor/256x256/apps/kitty.png"
    local desktop_main="$applications_dir/kitty.desktop"
    local desktop_open="$applications_dir/kitty-open.desktop"
    local kitty_conf="$HOME/.config/kitty/kitty.conf"

    step "Ensuring directories"
    mkdir -p "$localbin" "$applications_dir" "$HOME/.config"

    step "Linking kitty/kitten into PATH"
    ln -sf "$appdir/bin/kitty"  "$localbin/kitty"
    ln -sf "$appdir/bin/kitten" "$localbin/kitten"

    # Ensure ~/.local/bin precedes /usr/bin for this and future shells
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) export PATH="$HOME/.local/bin:$PATH";;
    esac
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
      if [ -f "$rc" ]; then
        if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$rc"; then
          printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
        fi
      else
        printf 'export PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
      fi
    done
    hash -r || true

    step "Copying desktop entries"
    cp -f "$appdir/share/applications/kitty.desktop" "$desktop_main"
    cp -f "$appdir/share/applications/kitty-open.desktop" "$desktop_open" 2>/dev/null || true

    step "Rewriting Exec/Icon paths"
    sed -i "s|^Icon=kitty$|Icon=${icon_path}|g" "$desktop_main"
    sed -i "s|^Exec=kitty|Exec=${appdir}/bin/kitty|g" "$desktop_main"
    if [ -f "$desktop_open" ]; then
        sed -i "s|^Icon=kitty$|Icon=${icon_path}|g" "$desktop_open"
        sed -i "s|^Exec=kitty|Exec=${appdir}/bin/kitty|g" "$desktop_open"
    fi

    step "Making xdg-terminal-exec prefer kitty"
    echo 'kitty.desktop' > "$HOME/.config/xdg-terminals.list"
    update-desktop-database "$applications_dir" >/dev/null 2>&1 || true

    # Patch deprecated/invalid keys so they stop being ignored
    if [ -f "$kitty_conf" ]; then
        step "Patching kitty.conf keys"
        if grep -qE '^[[:space:]]*enable_wayland[[:space:]]' "$kitty_conf"; then
            sed -Ei 's/^[[:space:]]*enable_wayland[[:space:]]+no[[:space:]]*$/linux_display_server x11/' "$kitty_conf"
            sed -Ei 's/^[[:space:]]*enable_wayland[[:space:]]+yes[[:space:]]*$/linux_display_server wayland/' "$kitty_conf"
        fi
        # Remove invalid cursor_blink knob; kitty uses cursor_blink_interval
        sed -Ei '/^[[:space:]]*cursor_blink[[:space:]]+/d' "$kitty_conf"
    fi

    ok "Kitty desktop integration complete"

    step "Diagnostics"
    type -a kitty | sed 's/^/    /'
    readlink -f "$(command -v kitty)" | sed 's/^/    exe: /'
    kitty --version | sed 's/^/    version: /'
}

install_ghostty_or_fallback() {
  section "[Ubuntu] Install Ghostty or fallback"
  if [[ "${SKIP_GHOSTTY:-0}" == "1" ]]; then
    note "SKIP_GHOSTTY=1; installing Kitty instead"
    sudo apt-get update && sudo apt-get install -y kitty
    return
  fi

  local version_id
  version_id="$(. /etc/os-release; echo "$VERSION_ID")"

  if [[ "$version_id" == "22.04" && -z "${INSTALL_GHOSTTY_FROM_SOURCE:-}" ]]; then
    warn "Ghostty not supported on Ubuntu 22.04; installing Kitty fallback"
    sudo apt-get update && sudo apt-get install -y kitty
    return
  fi

  step "Installing/Updating Ghostty"
  if curl -fsSL https://ghostty.dev/install.sh | bash; then
    ok "Ghostty installed/updated"
  else
    warn "Ghostty install failed; falling back to Kitty"
    sudo apt-get update && sudo apt-get install -y kitty
  fi
}

setup_symlinks() {
    section "[Ubuntu] Command symlinks and fonts"
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

    step "Installing JetBrainsMono Nerd Font (user-local)"
    if [ ! -f "$HOME/.local/share/fonts/JetBrainsMonoNerd.ttf" ]; then
        mkdir -p "$HOME/.local/share/fonts"
        if curl -fsSL -o /tmp/JBMNF.zip \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
            unzip -o /tmp/JBMNF.zip -d "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
            find "$HOME/.local/share/fonts" -name '*JetBrainsMono*Nerd*' -type f -exec bash -lc 'mv "$0" "${0%/*}/JetBrainsMonoNerd.ttf"' {} \; >/dev/null 2>&1 || true
            fc-cache -f >/dev/null 2>&1 || true
            ok "Installed Nerd Font (user)"
        else
          warn "Failed to download Nerd Font archive"
        fi
    else
        note "Nerd Font already present"
    fi
}

install_google_sans_fonts() {
    section "[Ubuntu] Install Google Sans fonts (user-local, SSH-only)"

    local fonts_root="$HOME/.local/share/fonts"
    local mono_dir="$fonts_root/GoogleSansMono"
    local sans_dir="$fonts_root/GoogleSans"

    mkdir -p "$mono_dir" "$sans_dir"

    have_fonts() {
        local family="$1" dir="$2"
        if command -v fc-list >/dev/null 2>&1 && fc-list | grep -iqE "$family"; then
            return 0
        fi
        shopt -s nullglob
        local f=("$dir"/*.ttf "$dir"/*.otf)
        shopt -u nullglob
        (( ${#f[@]} > 0 ))
    }

    install_from_repo_ssh() {
        local repo_ssh="$1" dest_dir="$2" label="$3"
        local tmp
        tmp="$(mktemp -d)"
        step "Cloning $label via SSH: $repo_ssh"
        if ! git clone --depth 1 "$repo_ssh" "$tmp/repo" >/dev/null 2>&1; then
            err "SSH clone failed for $label ($repo_ssh). Skipping."
            rm -rf "$tmp"
            return 0
        fi

        step "Copying $label font files to ${dest_dir}"
        mkdir -p "$dest_dir"
        local copied
        copied=$(find "$tmp/repo" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print -exec cp -f {} "$dest_dir"/ \; | wc -l | tr -d ' ')
        if [[ "${copied:-0}" == "0" ]]; then
            warn "No .ttf/.otf files found for $label"
        else
            ok "Installed $copied files for $label"
        fi
        rm -rf "$tmp"
    }

    # Google Sans Mono
    if have_fonts "Google Sans Mono" "$mono_dir"; then
        note "Google Sans Mono already installed"
    else
        install_from_repo_ssh "git@github.com:mehant-kr/Google-Sans-Mono.git" "$mono_dir" "Google Sans Mono"
    fi

    # Google Sans (avoid matching Mono)
    if have_fonts "^Google Sans($|[^M])" "$sans_dir"; then
        note "Google Sans already installed"
    else
        install_from_repo_ssh "git@github.com:hprobotic/Google-Sans-Font.git" "$sans_dir" "Google Sans"
    fi

    step "Linking Fontconfig override for Google Sans Mono"
    mkdir -p "$HOME/.config/fontconfig/conf.d"
    ln -sfn "$HOME/.dotfiles/fontconfig/30-google-sans-mono-mono.conf" "$HOME/.config/fontconfig/conf.d/30-google-sans-mono-mono.conf"

    step "Refreshing font cache"
    fc-cache -f >/dev/null 2>&1 || true
    ok "Fonts ready"
}

setup_picom_user_service() {
    section "[Ubuntu] Picom user service"
    # Config
    mkdir -p "$HOME/.config/picom"
    if [[ -f "$HOME/.dotfiles/picom/picom.conf" ]]; then
        ln -sfn "$HOME/.dotfiles/picom/picom.conf" "$HOME/.config/picom/picom.conf"
        ok "Linked picom.conf"
    else
        warn "~/.dotfiles/picom/picom.conf not found; using defaults if picom starts"
    fi

    # User service
    mkdir -p "$HOME/.config/systemd/user"
    if [[ -f "$HOME/.dotfiles/systemd/user/picom.service" ]]; then
        ln -sfn "$HOME/.dotfiles/systemd/user/picom.service" "$HOME/.config/systemd/user/picom.service"
        ok "Linked systemd user unit for picom"
    else
        warn "~/.dotfiles/systemd/user/picom.service missing"
        return 0
    fi

    systemctl --user daemon-reload || true
    # Enable, but it will only actually run on X11 sessions due to ExecCondition gates
    systemctl --user enable --now picom.service || warn "Could not start picom (likely non-X11 session); it will start when conditions match"
}

# --- Main ---------------------------------------------------------------------
main() {
    section "[Ubuntu] Start"
    setup_apt
    install_apt_packages
    install_kitty
    setup_kitty_desktop_integration
    install_ghostty_or_fallback
    setup_symlinks
    install_google_sans_fonts
    setup_picom_user_service
    section "[Ubuntu] Complete"
}
main
