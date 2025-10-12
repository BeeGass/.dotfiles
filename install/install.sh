#!/usr/bin/env bash
set -euo pipefail

# --- Early bootstrap for one-liner: curl … | bash -s -- --remote ---------------
# Clone to ~/.dotfiles and re-exec from disk before we touch BASH_SOURCE.
if [[ "${1-}" == "--remote" ]]; then
  repo="${DOTFILES_DIR:-$HOME/.dotfiles}"
  if ! command -v git >/dev/null 2>&1; then
    # Termux convenience; harmless elsewhere
    command -v pkg >/dev/null 2>&1 && pkg install -y git curl >/dev/null 2>&1 || true
  fi
  if [[ ! -d "$repo/.git" ]]; then
    git clone --depth=1 https://github.com/BeeGass/.dotfiles "$repo"
  else
    git -C "$repo" pull --ff-only || true
  fi
  exec bash "$repo/install/install.sh"
fi

# --- Script Setup and Constants ------------------------------------------------
# Resolve the repo root robustly (works for file, git checkout, or fallback)
resolve_dotfiles_dir() {
  # 1) Caller provided a path
  if [[ -n "${DOTFILES_DIR:-}" && -d "${DOTFILES_DIR:-}" ]]; then
    printf '%s\n' "$DOTFILES_DIR"; return
  fi
  # 2) Inside a git checkout?
  if command -v git >/dev/null 2>&1; then
    if top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      printf '%s\n' "$top"; return
    fi
  fi
  # 3) Real script path (not /dev or /proc)?
  case "${BASH_SOURCE[0]-}" in
    ''|/dev/*|/proc/*) ;;  # unusable
    *) ( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd ); return ;;
  esac
  # 4) Fallback
  printf '%s\n' "$HOME/.dotfiles"
}

# --- Script Setup and Constants ---
# Resolve repo root regardless of where the script is invoked
DOTFILES_DIR="$(resolve_dotfiles_dir)"
SCRIPT_DIR="$DOTFILES_DIR/install"
LOCAL_BIN_DIR="$HOME/.local/bin"
NEOFETCH_IMG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/neofetch/pics"

# --- Main Execution ---
main() {
    echo "🚀 Dotfiles Installation"
    echo "Repo: $DOTFILES_DIR"

    local os_type
    os_type=$(detect_os)
    echo "Detected OS: $os_type"
    echo

    # Ensure ~/.local/bin exists and is in PATH for this script and future shells
    ensure_local_bin_in_path

    # --- Installation Steps ---
    setup_symlinks "$os_type"
    install_platform_packages "$os_type"
    install_developer_tools "$os_type"
    setup_git_identity
    configure_credential_helper "$os_type"
    setup_misc_tools
    download_neofetch_assets

    echo
    echo "✅ Done. Open a new shell or run: source ~/.zshrc"
}

# --- Helper Functions ---

# Clone dotfiles repo if running in remote mode
bootstrap_remote() {
    echo "Cloning into ~/.dotfiles ..."
    if ! git clone https://github.com/BeeGass/.dotfiles.git "$HOME/.dotfiles"; then
        git clone git@github.com:BeeGass/.dotfiles.git "$HOME/.dotfiles"
    fi
    # Re-run from the fresh clone
    exec "$HOME/.dotfiles/install/install.sh"
}

# Detect the operating system
detect_os() {
    if [[ -n "${TERMUX_VERSION-}" ]] || [[ "${PREFIX-}" == *"com.termux"* ]] || [[ "$(uname -o 2>/dev/null)" == "Android" ]]; then
        echo "Termux"
    elif [[ "$(uname -s)" == "Linux" ]]; then
        echo "Linux"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "macOS"
    else
        echo "Unknown"
    fi
}

# Create a symlink, overwriting existing files
# create_symlink() {
#     local src="$1" dst="$2"
#     mkdir -p "$(dirname "$dst")"
#     ln -sfn "$src" "$dst"
#     echo "  ✓ $src → $dst"
# }
create_symlink() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then mv "$dst" "${dst}.backup.$(date +%Y%m%d_%H%M%S)"; fi
    ln -sfn "$src" "$dst"
    echo "  ✓ $src → $dst"
}

append_path_export() {
    local zsh_local_conf="$DOTFILES_DIR/zsh/90-local.zsh"
    local line='export PATH="$HOME/.local/bin:$PATH"'
    mkdir -p "$(dirname "$zsh_local_conf")"
    grep -qF -- "$line" "$zsh_local_conf" 2>/dev/null || echo "$line" >> "$zsh_local_conf"
}

# Ensure ~/.local/bin exists and is in the PATH
ensure_local_bin_in_path() {
    mkdir -p "$LOCAL_BIN_DIR"
    if [[ ":$PATH:" != *":$LOCAL_BIN_DIR:"* ]]; then
        export PATH="$LOCAL_BIN_DIR:$PATH"
        echo "  Temporarily added $LOCAL_BIN_DIR to PATH."
    fi
    append_path_export
}

# Create all common symlinks
setup_symlinks() {
    local os_type="$1"
    echo
    echo "1) Creating symlinks..."
    create_symlink "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
    create_symlink "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"
    create_symlink "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"
    create_symlink "$DOTFILES_DIR/vim/vimrc" "$HOME/.config/nvim/init.vim"
    create_symlink "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
    create_symlink "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
    chmod 700 "$HOME/.ssh" && chmod 600 "$HOME/.ssh/config" || true

    [[ -f "$DOTFILES_DIR/wezterm/wezterm.lua" ]] && create_symlink "$DOTFILES_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
    [[ -f "$DOTFILES_DIR/claude/CLAUDE.md" ]] && create_symlink "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.config/claude/CLAUDE.md"
    [[ -f "$DOTFILES_DIR/gemini/GEMINI.md" ]] && create_symlink "$DOTFILES_DIR/gemini/GEMINI.md" "$HOME/.config/gemini/GEMINI.md"

    echo
    echo "Linking scripts to $LOCAL_BIN_DIR..."
    if [[ -d "$DOTFILES_DIR/scripts" ]]; then
        for s in "$DOTFILES_DIR/scripts"/*; do
            [[ -f "$s" ]] || continue
            create_symlink "$s" "$LOCAL_BIN_DIR/$(basename "$s")"
            chmod +x "$s"
        done
    fi

    if [[ "$os_type" == "Termux" ]]; then
        echo
        echo "Applying Termux custom files..."
        if [[ -d "$DOTFILES_DIR/termux" ]]; then
            for f in "$DOTFILES_DIR/termux"/*; do
                [[ -f "$f" ]] || continue
                create_symlink "$f" "$HOME/.termux/$(basename "$f")"
            done
        fi
    fi
}

# Dispatch to OS-specific installation script
install_platform_packages() {
    local os_type="$1"
    echo
    echo "2) Installing platform packages..."
    case "$os_type" in
    macOS) bash "$SCRIPT_DIR/macos-install.sh" ;;
    Termux) bash "$SCRIPT_DIR/termux-install.sh" ;;
    Linux)
        if [[ -f /etc/NIXOS ]]; then
            bash "$SCRIPT_DIR/nixos-install.sh"
        else
            bash "$SCRIPT_DIR/ubuntu-install.sh"
        fi
        ;;
    *) echo "Unknown OS '$os_type', skipping platform packages." ;;
    esac
}

# Install tools from source or custom scripts
install_oh_my_posh() {
    local os_type="$1"
    echo "Installing oh-my-posh..."
    if [[ "$os_type" == "macOS" ]]; then
        # macOS via official installer
        echo "Installing oh-my-posh via brew..."
    elif [[ "$os_type" == "Linux" || "$os_type" == "Termux" ]]; then
        # Linux/Termux via official installer
        curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$LOCAL_BIN_DIR"
        append_path_export
    else
        echo "Unknown OS '$os_type', skipping oh-my-posh installation."
        return
    fi
    [[ -f "$DOTFILES_DIR/oh-my-posh/config.json" ]] \
    && create_symlink "$DOTFILES_DIR/oh-my-posh/config.json" "$HOME/.config/oh-my-posh/config.json"
}

# Install uv and Python-based tools
install_python_tools() {
    # Ensure local bin is in PATH for the current script and future sessions
    if ! command -v uv >/dev/null 2>&1; then
        echo "Installing uv..."
        curl -Ls https://astral.sh/uv/install.sh | sh
        append_path_export
    fi
    echo "Updating uv and installing Python tools..."
    UV_BIN="$(command -v uv || echo "$HOME/.local/bin/uv")"
    "$UV_BIN" self update
    "$UV_BIN" python install 3.11 3.12
    if ! command -v python-lsp-server >/dev/null 2>&1; then
        echo "Installing python-lsp-server..."
        "$UV_BIN" tool install 'python-lsp-server[all]'
    fi
    if ! command -v ruff >/dev/null 2>&1; then
        echo "Installing ruff..."
        "$UV_BIN" tool install ruff
    fi
    if ! command -v mypy >/dev/null 2>&1; then
        echo "Installing mypy..."
        "$UV_BIN" tool install mypy
    fi
    if ! command -v pytest >/dev/null 2>&1; then
        echo "Installing pytest..."
        "$UV_BIN" tool install pytest
    fi
    if ! command -v pre-commit >/dev/null 2>&1; then
        echo "Installing pre-commit..."
        "$UV_BIN" tool install pre-commit
    fi
}

# Install nvm and the latest LTS version of Node.js
install_node() {
    export NVM_DIR="$HOME/.nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    fi

    # Source nvm to use it in the current script
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    echo "Installing latest LTS Node.js and setting as default..."
    nvm install --lts
    nvm alias default 'lts/*'
    nvm use default >/dev/null # Use the default version silently
    echo "Node.js $(node -v) and npm $(npm -v) are available."
}

# Install various command-line interfaces
install_clis() {
    echo "Installing CLIs..."
    # Install Node-based CLIs
    if command -v npm >/dev/null 2>&1; then
        echo "Installing Node.js-based CLIs..."
        npm install -g \
            @google/gemini-cli@latest \
            @anthropic-ai/claude-code \
            typescript \
            typescript-language-server || true
    fi

    # Install OpenCode AI CLI
    if [ ! -d "$HOME/.opencode" ]; then
        echo "Installing opencode.ai CLI..."
        curl -fsSL https://opencode.ai/install | bash
    fi
    export PATH="$HOME/.opencode/bin:$PATH"
}

# Install pfetch from source
install_pfetch() {
    local os_type="$1"
    echo "Installing pfetch from source..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    (
        cd "$tmp_dir" &&
            wget -q https://github.com/dylanaraps/pfetch/archive/master.zip -O pfetch.zip &&
            unzip -q pfetch.zip &&
            cd pfetch-master &&
            if [[ "$os_type" == "Termux" ]]; then
                install -Dm755 pfetch "$PREFIX/bin/pfetch"
            elif [[ "$os_type" == "Linux" ]]; then
                sudo install pfetch /usr/local/bin/
            fi
    )
    rm -rf "$tmp_dir"
}

# Install language runtimes and developer tools
install_developer_tools() {
    local os_type="$1"
    echo
    echo "3) Installing developer tools..."

    # Tailscale VPN
    if ! command -v tailscale || [[ "$os_type" != "Termux" ]]; then
        echo "Installing Tailscale VPN..."
        curl -fsSL https://tailscale.com/install.sh | sh
    fi

    install_oh_my_posh "$os_type"
    install_python_tools
    install_node
    install_clis

    # pfetch (lightweight system info tool)
    if ! command -v pfetch >/dev/null 2>&1 && [[ "$os_type" != "macOS" ]]; then
        install_pfetch "$os_type"
    fi
}

# Configure Git user identity if not already set
setup_git_identity() {
    echo
    echo "4) Configuring Git identity..."
    if ! git config --global user.name >/dev/null 2>&1; then
        read -r -p "  Enter Git username: " git_user_name
        git config --global user.name "$git_user_name"
    fi
    if ! git config --global user.email >/dev/null 2>&1; then
        read -r -p "  Enter Git email: " git_user_email
        git config --global user.email "$git_user_email"
    fi
    echo "  Git identity is set."
}

# Configure a sane credential helper per OS (gitconfig stays portable)
configure_credential_helper() {
    local os_type="$1"
    case "$os_type" in
    macOS)
        # Prefer Git Credential Manager (installed via brew cask below)
        git config --global credential.helper manager || true
        ;;
    Linux)
        # Ubuntu/Debian with libsecret keyring
        if command -v git-credential-libsecret >/dev/null 2>&1; then
            git config --global credential.helper libsecret
        else
            git config --global credential.helper 'cache --timeout=7200'
        fi
        ;;
    Termux)
        # No secure keyring; use cache to avoid writing secrets to disk
        git config --global credential.helper 'cache --timeout=7200'
        ;;
    esac
}

# Install miscellaneous tools like TPM and bootstrap GPG
setup_misc_tools() {
    echo
    echo "5) Setting up miscellaneous tools..."

    # Tmux Plugin Manager
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        echo "Installing Tmux Plugin Manager (TPM)..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        "$HOME/.tmux/plugins/tpm/bin/install_plugins" || echo "  ⚠ TPM plugin install failed; run manually in tmux (prefix + I)."
    fi

    # GPG/SSH bootstrap
    if command -v gpg >/dev/null 2>&1 && [[ -x "$DOTFILES_DIR/scripts/setup_gpg_ssh.sh" ]]; then
        echo "Bootstrapping GPG + SSH..."
        "$DOTFILES_DIR/scripts/setup_gpg_ssh.sh" --regen || echo "  ⚠ GPG bootstrap failed; continuing."
    fi

    # Termux-specific settings reload
    if command -v termux-reload-settings >/dev/null 2>&1; then
        echo "Reloading Termux settings..."
        termux-reload-settings
    fi
}

# Download image assets for Neofetch
download_neofetch_assets() {
    mkdir -p "$NEOFETCH_IMG_DIR"
    if ! find "$NEOFETCH_IMG_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | grep -q .; then
        echo
        echo "6) Downloading neofetch image assets to $NEOFETCH_IMG_DIR..."
        uvx gdown 'https://drive.google.com/drive/folders/1vjMG9j9t9cay5baPQbYLngWRi-EQ2pyK?usp=sharing' --folder --no-cookies --output "$NEOFETCH_IMG_DIR" || echo "  ⚠ Neofetch asset download failed."
    fi
}


# --- Run the main function ---
main "$@"
