#!/usr/bin/env bash
set -euo pipefail
source "${BASH_SOURCE[0]%/*}/lib.sh"

# --- Helper functions ----------------------------------------------------------

setup_apt() {
    section "[Ubuntu] Configure APT repositories"
    step "Updating base indexes and installing apt helpers"
    sudo apt update
    sudo apt install -y --no-install-recommends software-properties-common ca-certificates gnupg

    step "Updating package lists"
    sudo apt update
    ok "APT ready (no Microsoft repo)"
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
        flatpak
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
        neovim
        openssh-client
        openssh-server
        openssl
        pcscd
        pinentry-curses
        pinentry-gnome3
        picom
        pkg-config
        scdaemon
        ripgrep
        shellcheck
        shfmt
        snapd
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

setup_snap() {
    section "[Ubuntu] Setup Snap and install VS Code"

    if ! command -v snap >/dev/null 2>&1; then
        err "Snap not found; ensure apt packages installed first"
        return 1
    fi

    step "Installing VS Code via snap"
    if snap list 2>/dev/null | grep -q "^code "; then
        note "VS Code already installed"
    else
        if sudo snap install code --classic; then
            ok "Installed VS Code"
        else
            warn "Failed to install VS Code"
        fi
    fi
}

install_claude_code() {
    section "[Ubuntu] Install Claude Code"

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

setup_flatpak() {
    section "[Ubuntu] Setup Flatpak and install applications"

    if ! command -v flatpak >/dev/null 2>&1; then
        err "Flatpak not found; ensure apt packages installed first"
        return 1
    fi

    step "Adding Flathub repository"
    if flatpak remote-list | grep -q flathub; then
        note "Flathub already configured"
    else
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        ok "Added Flathub repository"
    fi

    step "Updating Flatpak repositories"
    sudo flatpak update -y || warn "Flatpak update had warnings"

    section "[Ubuntu] Installing Flatpak applications"
    local apps=(
        "md.obsidian.Obsidian:Obsidian"
        "com.discordapp.Discord:Discord"
        "com.valvesoftware.Steam:Steam"
        "com.google.Chrome:Google Chrome"
        "org.telegram.desktop:Telegram"
        "com.spotify.Client:Spotify"
        "com.slack.Slack:Slack"
    )

    local installed=0
    local failed=0
    for app in "${apps[@]}"; do
        local app_id="${app%%:*}"
        local app_name="${app#*:}"

        step "Installing $app_name ($app_id)"
        if flatpak list --app | grep -q "$app_id"; then
            note "$app_name already installed"
            installed=$((installed + 1))
        else
            if sudo flatpak install -y flathub "$app_id"; then
                ok "Installed $app_name"
                installed=$((installed + 1))
            else
                warn "Failed to install $app_name"
                failed=$((failed + 1))
            fi
        fi
    done

    ok "Flatpak setup complete: $installed apps ready, $failed failed"
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

setup_directories() {
    section "[Ubuntu] User directories & bookmarks"

    # Create standard directories
    step "Creating user directories"
    mkdir -p "$HOME/Projects" "$HOME/Papers"
    ok "Ensured Projects and Papers directories exist"

    # Add to GTK bookmarks (for GNOME Files/Nautilus sidebar)
    local bookmarks_file="$HOME/.config/gtk-3.0/bookmarks"
    mkdir -p "$(dirname "$bookmarks_file")"
    touch "$bookmarks_file"

    local projects_bookmark="file://$HOME/Projects Projects"
    local papers_bookmark="file://$HOME/Papers Papers"

    step "Adding directories to file manager sidebar"
    if ! grep -Fxq "$projects_bookmark" "$bookmarks_file" 2>/dev/null; then
        echo "$projects_bookmark" >> "$bookmarks_file"
        ok "Added Projects bookmark"
    else
        note "Projects bookmark already present"
    fi

    if ! grep -Fxq "$papers_bookmark" "$bookmarks_file" 2>/dev/null; then
        echo "$papers_bookmark" >> "$bookmarks_file"
        ok "Added Papers bookmark"
    else
        note "Papers bookmark already present"
    fi
}

setup_ssh_server() {
    setup_ssh_server_common "Ubuntu"
}

setup_git_credential_helper() {
    section "[Ubuntu] Configure Git credential helper"

    step "Symlinking Linux Git config to ~/.gitconfig.local"
    ln -sf "$HOME/.dotfiles/git/gitconfig.linux" "$HOME/.gitconfig.local"

    # Try to use libsecret if available
    if dpkg -l | grep -q libsecret-1-dev; then
        local libsecret_path="/usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret"

        if [[ -x "$libsecret_path" ]]; then
            note "Updating credential helper to libsecret"
            sed -i "s|helper = .*|helper = $libsecret_path|" "$HOME/.dotfiles/git/gitconfig.linux"
            ok "Git credential helper configured: libsecret"
        else
            # Try to build it
            local build_dir="/usr/share/doc/git/contrib/credential/libsecret"
            if [[ -d "$build_dir" ]]; then
                note "Building git-credential-libsecret"
                (cd "$build_dir" && sudo make) || warn "Failed to build libsecret helper"
                if [[ -x "$libsecret_path" ]]; then
                    sed -i "s|helper = .*|helper = $libsecret_path|" "$HOME/.dotfiles/git/gitconfig.linux"
                    ok "Git credential helper configured: libsecret (built)"
                else
                    ok "Git credential helper configured: store (libsecret build failed)"
                fi
            else
                ok "Git credential helper configured: store"
            fi
        fi
    else
        ok "Git credential helper configured: store"
    fi
}

setup_claude() {
    section "[Ubuntu] Configure Claude Code"

    local dotfiles_claude="${DOTFILES_DIR}/claude"

    if [[ ! -d "$dotfiles_claude" ]]; then
        warn "Claude dotfiles not found at $dotfiles_claude; skipping"
        return 0
    fi

    step "Ensuring ~/.claude directory exists"
    mkdir -p "$HOME/.claude"

    step "Symlinking Claude configuration files"
    # Files: src_name -> dst_name (same name for all currently)
    _symlink_claude_file "CLAUDE.md" "CLAUDE.md"
    _symlink_claude_file "settings.json" "settings.json"
    _symlink_claude_file ".mcp.json" ".mcp.json"

    step "Symlinking Claude directories"
    _symlink_claude_dir "docs"
    _symlink_claude_dir "hooks"
    _symlink_claude_dir "statusline"
    _symlink_claude_dir "templates"
    _symlink_claude_dir "commands"

    ok "Claude Code configuration complete"
}

# --- Main ---------------------------------------------------------------------
main() {
    section "[Ubuntu] Start"
    setup_apt
    install_apt_packages
    setup_snap
    install_claude_code
    setup_flatpak
    install_kitty
    setup_kitty_desktop_integration
    install_ghostty_or_fallback
    setup_symlinks
    setup_directories
    install_google_sans_fonts
    setup_picom_user_service
    setup_ssh_server
    setup_git_credential_helper
    setup_claude
    section "[Ubuntu] Complete"
}
main
