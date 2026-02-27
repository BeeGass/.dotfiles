#!/usr/bin/env bash
set -euo pipefail

# --- Early bootstrap for one-liner: curl … | bash -s -- --remote ---------------
# Clone to ~/.dotfiles and re-exec from disk before we touch BASH_SOURCE.
if [[ "${1-}" == "--remote" ]]; then
  shift
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
  exec bash "$repo/install/install.sh" "$@"
fi

# --- CLI flags ----------------------------------------------------------------
NO_SUDO=0
for arg in "$@"; do
  case "$arg" in
    --no-sudo) NO_SUDO=1 ;;
  esac
done

# Source shared library (provides colors, logging, paths, helpers)
source "${BASH_SOURCE[0]%/*}/lib.sh"

# --- Flags / Env snapshot (read by ~/.zshenv) ---------------------------------
# Keep flags compatible with 40-aliases.zsh (_is_termux checks for 'termux')
write_os_flags() {
  local os="$1"
  mkdir -p "$FLAGS_DIR"
  rm -f "$FLAGS_DIR"/{IS_*,termux,linux,macos,unknown} 2>/dev/null || true
  case "$os" in
    Termux) :> "$FLAGS_DIR/termux"; :> "$FLAGS_DIR/IS_TERMUX" ;;
    macOS)  :> "$FLAGS_DIR/macos";  :> "$FLAGS_DIR/IS_MACOS"  ;;
    Linux)  :> "$FLAGS_DIR/linux";  :> "$FLAGS_DIR/IS_LINUX"  ;;
    *)      :> "$FLAGS_DIR/unknown";:> "$FLAGS_DIR/IS_UNKNOWN";;
  esac
  ok "OS flags written to $FLAGS_DIR"
}

write_os_env_snapshot() {
  local os="$1"
  mkdir -p "$(dirname "$ENV_SNAPSHOT")"
  {
    echo "OS=$os"
    if [[ "$os" == "Termux" ]]; then
      echo "PREFIX=${PREFIX:-/data/data/com.termux/files/usr}"
      v="$( (command -v pkg >/dev/null 2>&1 && pkg --version) || echo unknown )"
      echo "TERMUX_VERSION=${TERMUX_VERSION:-$v}"
    fi
  } > "$ENV_SNAPSHOT.tmp"
  mv -f "$ENV_SNAPSHOT.tmp" "$ENV_SNAPSHOT"
  ok "Snapshot: $ENV_SNAPSHOT"
}

# --- Helpers ------------------------------------------------------------------
# create_symlink is provided by lib.sh

# Create a private machine-local overrides file if missing (no secrets by default)
ensure_local_overrides() {
  local zsh_local_conf="$HOME/.dotfiles/zsh/90-local.zsh"
  install -d "$(dirname "$zsh_local_conf")"
  if [[ ! -f "$zsh_local_conf" ]]; then
    step "Creating machine-local overrides: $zsh_local_conf"
    umask 077
    cat > "$zsh_local_conf" <<'EOF'
# Local Machine Settings

# ==============================================================================
# GPG Agent for SSH
# ==============================================================================
# Example: gpg-agent as SSH agent
if command -v gpgconf &> /dev/null; then
  export GPG_TTY=$(tty)
  gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
  export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  gpgconf --launch gpg-agent >/dev/null 2>&1 || true
fi

# ==============================================================================
# API KEYS
# ==============================================================================
# Secrets are managed via pass (GPG-encrypted) with SSH fallback to Jacobian.
# Load on demand:  load-secrets
# Check status:    load-secrets --check
# Or uncomment below for manual overrides:
# export GEMINI_API_KEY="__SET_ME_SECURELY__"
# export HF_TOKEN="__SET_ME_SECURELY__"

# ==============================================================================
# ENVIRONMENT Variables - Local Overrides
# ==============================================================================
# PYPEX_CACHE_DIR: Main cache directory for PyPex datasets
# This takes precedence over HF_HOME for PyPex operations
# Default: Falls back to HF_HOME or ~/.cache/huggingface
export PYPEX_CACHE_DIR="$HOME/.cache/ludo/pypex"

# ==============================================================================
# PATH Additions - Local Overrides
# ==============================================================================
# OpenCode CLI (machine-local)
if [ -d "$HOME/.opencode/bin" ]; then
    export PATH="$HOME/.opencode/bin:$PATH"
fi

# ==============================================================================
# HUGGINGFACE ENVIRONMENT VARIABLES
# ==============================================================================

# ------------------------------------------------------------------------------
# Cache & Storage Paths
# ------------------------------------------------------------------------------

# HF_HOME: Main HuggingFace cache directory
# Default: ~/.cache/huggingface (or $XDG_CACHE_HOME/huggingface if XDG_CACHE_HOME is set)
export HF_HOME="$HOME/.cache/huggingface"

# HF_HUB_CACHE: Where repositories from the Hub are cached
# Default: $HF_HOME/hub
export HF_HUB_CACHE="$HF_HOME/hub"

# TRANSFORMERS_CACHE: Alias for HF_HUB_CACHE (for backward compatibility)
# Default: $HF_HOME/hub
# export TRANSFORMERS_CACHE="$HF_HOME/hub"

# ------------------------------------------------------------------------------
# Authentication
# ------------------------------------------------------------------------------

# HF_HUB_DISABLE_IMPLICIT_TOKEN: Disable automatic token detection
# Default: False
# Values: 1, ON, YES, TRUE (case-insensitive) = True; any other value or unset = False
# export HF_HUB_DISABLE_IMPLICIT_TOKEN=0

# ------------------------------------------------------------------------------
# Network & API Configuration
# ------------------------------------------------------------------------------

# HF_INFERENCE_ENDPOINT: Base URL for inference API
# Default: https://api-inference.huggingface.co
# export HF_INFERENCE_ENDPOINT="https://api-inference.huggingface.co"

# HF_HUB_ETAG_TIMEOUT: Timeout for fetching metadata before downloading (in seconds)
# Default: 10
# export HF_HUB_ETAG_TIMEOUT=10

# HF_HUB_DOWNLOAD_TIMEOUT: Timeout for file downloads (in seconds)
# Default: 16
# export HF_HUB_DOWNLOAD_TIMEOUT=16

# ------------------------------------------------------------------------------
# Logging & Verbosity
# ------------------------------------------------------------------------------

# HF_HUB_VERBOSITY: Set verbosity level of huggingface_hub logger
# Default: warning
# Values: debug, info, warning, error, critical
# export HF_HUB_VERBOSITY="warning"

# HF_DEBUG: Enable DEBUG logging and log requests as cURL commands
# Default: False
# Values: 1, ON, YES, TRUE (case-insensitive) = True; any other value or unset = False
# export HF_DEBUG=0

# ------------------------------------------------------------------------------
# Feature Flags (Boolean)
# ------------------------------------------------------------------------------

# HF_HUB_OFFLINE: Enable offline mode - no HTTP calls, only cached files
# Default: False
# Values: 1, ON, YES, TRUE (case-insensitive) = True; any other value or unset = False
export HF_HUB_OFFLINE=0

# HF_HUB_DISABLE_TELEMETRY: Disable usage data collection
# Default: False
# Values: 1, ON, YES, TRUE (case-insensitive) = True; any other value or unset = False
export HF_HUB_DISABLE_TELEMETRY=0

# HF_HUB_ENABLE_HF_TRANSFER: Enable Rust-based faster uploads/downloads
# Default: False
# Values: 1, ON, YES, TRUE (case-insensitive) = True; any other value or unset = False
# Note: Requires hf_transfer package to be installed
# export HF_HUB_ENABLE_HF_TRANSFER=0

# HF_HUB_DISABLE_EXPERIMENTAL_XET: Disable using hf-xet even if available
# Default: False
# Values: 1, ON, YES, TRUE (case-insensitive) = True; any other value or unset = False
# export HF_HUB_DISABLE_EXPERIMENTAL_XET=0

# ------------------------------------------------------------------------------
# Xet Integration Settings (when enabled)
# ------------------------------------------------------------------------------

# HF_XET_CHUNK_CACHE_SIZE_BYTES: Controls Xet chunk cache size
# Default: 10737418240 (10GiB)
# export HF_XET_CHUNK_CACHE_SIZE_BYTES=10737418240

# HF_XET_NUM_CONCURRENT_RANGE_GETS: Concurrent terms downloaded from S3 per file
# Default: 16
# export HF_XET_NUM_CONCURRENT_RANGE_GETS=16

# ------------------------------------------------------------------------------
# Cross-Library Variables
# ------------------------------------------------------------------------------

# TRANSFORMERS_OFFLINE: Enable offline mode for transformers library (DEPRECATED: Use HF_HUB_OFFLINE)
# Default: False
# Values: 1, ON, YES, TRUE (case-insensitive) = True; any other value or unset = False
# export TRANSFORMERS_OFFLINE=0

# HF_DATASETS_OFFLINE: Enable offline mode for datasets library (DEPRECATED: Use HF_HUB_OFFLINE)
# Default: False
# Values: 1, ON, YES, TRUE (case-insensitive) = True; any other value or unset = False
# export HF_DATASETS_OFFLINE=0

# DO_NOT_TRACK: Globally disable telemetry across tools
# Default: False
# Values: 1, ON, YES, TRUE (case-insensitive) = True; any other value or unset = False
# export DO_NOT_TRACK=0

# ------------------------------------------------------------------------------
# HuggingFace Spaces Variables (automatically set when running in Spaces)
# ------------------------------------------------------------------------------

# SPACE_CREATOR_USER_ID: ID of the user that originally created the Space
# OAUTH_CLIENT_ID: OAuth client ID when OAuth is enabled
# OAUTH_CLIENT_SECRET: OAuth client secret when OAuth is enabled
# OAUTH_SCOPES: OAuth scopes (default: "openid profile")
EOF
    chmod 600 "$zsh_local_conf"
    ok "Created $zsh_local_conf"
  else
    note "$zsh_local_conf already exists (left unchanged)"
  fi

  local kitty_local="$HOME/.config/kitty/local.conf"
  if [[ ! -f "$kitty_local" ]]; then
    step "Creating machine-local kitty overrides: $kitty_local"
    mkdir -p "$(dirname "$kitty_local")"
    local os_type
    os_type="$(detect_os)"
    {
      echo "# Machine-local Kitty overrides"
      echo "# Auto-generated by install.sh -- edit freely"
      echo ""
      echo "# Auto-start tmux"
      echo 'shell zsh -l -c "tmux -u new-session -A -s main"'
      if [[ "$os_type" == "Linux" ]]; then
        echo ""
        echo "# Force X11 for picom compositing"
        echo "linux_display_server x11"
        echo ""
        echo "# Nerd Font symbol fallback"
        echo "symbol_map U+23FB-U+23FE,U+2665,U+26A1,U+276C-U+2771,U+2B58,U+E000-U+F8FF,U+F0001-U+F1AF0 JetBrainsMono Nerd Font Mono"
      fi
    } > "$kitty_local"
    ok "Created $kitty_local"
  else
    note "$kitty_local already exists (left unchanged)"
  fi
}

ensure_local_bin_in_path() {
  mkdir -p "$LOCAL_BIN_DIR"
  if [[ ":$PATH:" != *":$LOCAL_BIN_DIR:"* ]]; then
    export PATH="$LOCAL_BIN_DIR:$PATH"
    step "Temporarily added $LOCAL_BIN_DIR to PATH for this run"
  fi
  ensure_local_overrides
}

# --- Symlinks -----------------------------------------------------------------
setup_symlinks() {
  local os_type="$1"
  section "1) Creating symlinks"

  # 0) Link minimal .zshenv first so future shells see flags/env immediately
  if [[ -f "$DOTFILES_DIR/zsh/zshenv" ]]; then
    create_symlink "$DOTFILES_DIR/zsh/zshenv" "$HOME/.zshenv"
    chmod 644 "$DOTFILES_DIR/zsh/zshenv" "$HOME/.zshenv" || true
  fi

  create_symlink "$DOTFILES_DIR/zsh/zshrc"      "$HOME/.zshrc"
  create_symlink "$DOTFILES_DIR/git/gitconfig"  "$HOME/.gitconfig"
  create_symlink "$DOTFILES_DIR/vim/vimrc"      "$HOME/.vimrc"
  create_symlink "$DOTFILES_DIR/vim/vimrc"      "$HOME/.config/nvim/init.vim"
  create_symlink "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
  create_symlink "$DOTFILES_DIR/ssh/config"     "$HOME/.ssh/config"
  chmod 700 "$HOME/.ssh" && chmod 600 "$HOME/.ssh/config" || true

  [[ -f "$DOTFILES_DIR/kitty/kitty.conf"   ]] && create_symlink "$DOTFILES_DIR/kitty/kitty.conf"   "$HOME/.config/kitty/kitty.conf"
  [[ -f "$DOTFILES_DIR/wezterm/wezterm.lua" ]] && create_symlink "$DOTFILES_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
  [[ -f "$DOTFILES_DIR/claude/CLAUDE.md"    ]] && create_symlink "$DOTFILES_DIR/claude/CLAUDE.md"    "$HOME/.config/claude/CLAUDE.md"
  [[ -f "$DOTFILES_DIR/gemini/GEMINI.md"    ]] && create_symlink "$DOTFILES_DIR/gemini/GEMINI.md"    "$HOME/.config/gemini/GEMINI.md"

  step "Linking scripts to $LOCAL_BIN_DIR"
  if [[ -d "$DOTFILES_DIR/scripts" ]]; then
    mkdir -p "$LOCAL_BIN_DIR"
    shopt -s nullglob
    for s in "$DOTFILES_DIR/scripts"/*; do
      [[ -f "$s" ]] || continue
      chmod +x "$s" || true
      base="$(basename "$s")"
      name_noext="${base%.*}"
      create_symlink "$s" "$LOCAL_BIN_DIR/$base"
      if [[ "$base" == *.sh ]]; then
        create_symlink "$s" "$LOCAL_BIN_DIR/$name_noext"
      fi
    done
    shopt -u nullglob
  fi

  if [[ -x "$DOTFILES_DIR/scripts/neofetch_random.sh" ]]; then
    create_symlink "$DOTFILES_DIR/scripts/neofetch_random.sh" "$LOCAL_BIN_DIR/nf"
  fi

  if [[ -x "$DOTFILES_DIR/scripts/yk-gpg-refresh.sh" ]]; then
    create_symlink "$DOTFILES_DIR/scripts/yk-gpg-refresh.sh" "$LOCAL_BIN_DIR/yk-refresh"
  fi

  # Link install scripts globally
  step "Linking dotfiles install scripts"
  if [[ -f "$DOTFILES_DIR/install/install.sh" ]]; then
    create_symlink "$DOTFILES_DIR/install/install.sh" "$LOCAL_BIN_DIR/dots-install"
  fi
  if [[ -f "$DOTFILES_DIR/install/refresh.sh" ]]; then
    create_symlink "$DOTFILES_DIR/install/refresh.sh" "$LOCAL_BIN_DIR/dots-refresh"
  fi
  if [[ -f "$DOTFILES_DIR/install/bootstrap.sh" ]]; then
    create_symlink "$DOTFILES_DIR/install/bootstrap.sh" "$LOCAL_BIN_DIR/dots-bootstrap"
  fi
  if [[ -f "$DOTFILES_DIR/install/clean.sh" ]]; then
    create_symlink "$DOTFILES_DIR/install/clean.sh" "$LOCAL_BIN_DIR/dots-clean"
  fi

  if [[ "$os_type" == "Termux" ]]; then
    section "Termux custom files"
    if [[ -d "$DOTFILES_DIR/termux" ]]; then
      for f in "$DOTFILES_DIR/termux"/*; do
        [[ -f "$f" ]] || continue
        create_symlink "$f" "$HOME/.termux/$(basename "$f")"
      done
    fi
  fi
}

# --- Platform packages --------------------------------------------------------
install_platform_packages() {
  local os_type="$1"
  section "2) Installing platform packages"
  if (( NO_SUDO )); then
    warn "Skipping platform packages (--no-sudo)"
    return
  fi
  case "$os_type" in
    macOS)  bash "$SCRIPT_DIR/macos-install.sh" ;;
    Termux) bash "$SCRIPT_DIR/termux-install.sh" ;;
    Linux)
      if [[ -f /etc/NIXOS ]]; then
        bash "$SCRIPT_DIR/nixos-install.sh"
      elif [[ -f /proc/device-tree/model ]] && grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null; then
        step "Detected Raspberry Pi (headless server)"
        bash "$SCRIPT_DIR/rpi-install.sh"
      else
        bash "$SCRIPT_DIR/ubuntu-install.sh"
      fi
      ;;
    *) warn "Unknown OS '$os_type', skipping platform packages." ;;
  esac
}

# --- Dev tools ---------------------------------------------------------------
install_oh_my_posh() {
  local os_type="$1"
  step "Installing oh-my-posh"
  if [[ "$os_type" == "macOS" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install jandedobbeleer/oh-my-posh/oh-my-posh || brew install oh-my-posh || true
    else
      curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$LOCAL_BIN_DIR"
    fi
  elif [[ "$os_type" == "Linux" || "$os_type" == "Termux" ]]; then
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$LOCAL_BIN_DIR"
  else
    warn "Unknown OS '$os_type', skipping oh-my-posh installation."
    return
  fi
  [[ -f "$DOTFILES_DIR/oh-my-posh/config.json" ]] \
    && create_symlink "$DOTFILES_DIR/oh-my-posh/config.json" "$HOME/.config/oh-my-posh/config.json"
}

install_python_tools() {
  if ! command -v uv >/dev/null 2>&1; then
    step "Installing uv"
    curl -Ls https://astral.sh/uv/install.sh | sh
    ensure_local_bin_in_path
  fi
  step "Updating uv and installing Python tools"
  local UV_BIN
  UV_BIN="$(command -v uv || echo "$HOME/.local/bin/uv")"
  "$UV_BIN" self update || true
  "$UV_BIN" python install 3.11 3.12 3.13 3.14 || true
  if ! command -v python-lsp-server >/dev/null 2>&1; then "$UV_BIN" tool install 'python-lsp-server[all]' || true; fi
  if ! command -v ruff              >/dev/null 2>&1; then "$UV_BIN" tool install ruff || true; fi
  if ! command -v mypy              >/dev/null 2>&1; then "$UV_BIN" tool install mypy || true; fi
  if ! command -v pytest            >/dev/null 2>&1; then "$UV_BIN" tool install pytest || true; fi
  if ! command -v pre-commit        >/dev/null 2>&1; then "$UV_BIN" tool install pre-commit || true; fi
}

install_node() {
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    step "Installing nvm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  step "Installing latest LTS Node.js and setting as default"
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default >/dev/null || true
  ok "Node.js $(node -v) and npm $(npm -v) are available"
}

install_clis() {
  section "Installing CLIs"
  if command -v npm >/dev/null 2>&1; then
    npm install -g \
      @google/gemini-cli@latest \
      @openai/codex@latest \
      typescript \
      typescript-language-server || true
  fi
  if [ ! -d "$HOME/.opencode" ]; then
    step "Installing opencode.ai CLI"
    curl -fsSL https://opencode.ai/install | bash || true
  fi
  export PATH="$HOME/.opencode/bin:$PATH"
}

install_pfetch() {
  local os_type="$1"
  step "Installing pfetch from source"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  (
    cd "$tmp_dir" &&
      wget -q https://github.com/dylanaraps/pfetch/archive/master.zip -O pfetch.zip &&
      unzip -q pfetch.zip &&
      cd pfetch-master &&
      if [[ "$os_type" == "Termux" ]]; then
        install -Dm755 pfetch "${PREFIX:-/data/data/com.termux/files/usr}/bin/pfetch"
      elif [[ "$os_type" == "Linux" ]]; then
        if (( NO_SUDO )); then
          warn "Skipping pfetch system install (--no-sudo)"
        else
          sudo install -m 0755 pfetch /usr/local/bin/pfetch
        fi
      fi
  ) || warn "pfetch build/install failed"
  rm -rf "$tmp_dir"
}

install_developer_tools() {
  local os_type="$1"
  section "3) Installing developer tools"
  if ! command -v tailscale >/dev/null 2>&1; then
    if [[ "$os_type" == "macOS" ]]; then
      if command -v brew >/dev/null 2>&1; then
        brew install tailscale || true
      fi
    elif [[ "$os_type" == "Linux" ]]; then
      if (( NO_SUDO )); then
        warn "Skipping Tailscale install (--no-sudo)"
      else
        curl -fsSL https://tailscale.com/install.sh | sh || true
      fi
    fi
  fi
  if command -v sf >/dev/null 2>&1; then
    ok "SF Compute CLI already installed"
  else
    step "Installing SF Compute CLI"
    curl -fsSL https://sfcompute.com/cli/install | bash || warn "SF Compute CLI install failed"
    ensure_local_bin_in_path
  fi
  install_oh_my_posh "$os_type"
  install_python_tools
  install_node
  install_clis
  if ! command -v pfetch >/dev/null 2>&1 && [[ "$os_type" != "macOS" ]]; then
    install_pfetch "$os_type"
  fi
}

# --- Git identity / creds -----------------------------------------------------
setup_git_identity() {
  section "4) Configuring Git identity"
  if ! git config --global user.name  >/dev/null 2>&1; then read -r -p "  Enter Git username: " git_user_name;  git config --global user.name  "$git_user_name";  fi
  if ! git config --global user.email >/dev/null 2>&1; then read -r -p "  Enter Git email: "    git_user_email; git config --global user.email "$git_user_email"; fi
  ok "Git identity is set"
}

configure_credential_helper() {
  local os_type="$1"
  if [[ -f "$HOME/.gitconfig.local" ]]; then
    ok "Git credential helper configured via ~/.gitconfig.local"
  else
    warn "~/.gitconfig.local not found; per-OS install script should create it"
  fi
}

# --- Misc / assets ------------------------------------------------------------
setup_misc_tools() {
  section "5) Setting up miscellaneous tools"
  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    step "Installing Tmux Plugin Manager (TPM)"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "TPM plugin install failed; run manually in tmux (prefix + I)"
  fi
  if command -v gpg >/dev/null 2>&1 && [[ -x "$DOTFILES_DIR/scripts/setup_gpg_ssh.sh" ]]; then
    step "Bootstrapping GPG + SSH"
    "$DOTFILES_DIR/scripts/setup_gpg_ssh.sh" --regen || warn "GPG bootstrap failed; continuing"
  fi
  if command -v termux-reload-settings >/dev/null 2>&1; then
    step "Reloading Termux settings"
    termux-reload-settings || true
  fi
}

download_neofetch_assets() {
  mkdir -p "$NEOFETCH_IMG_DIR"
  if ! find "$NEOFETCH_IMG_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | grep -q .; then
    section "6) Downloading neofetch image assets"
    note "Destination: $NEOFETCH_IMG_DIR"
    if command -v uvx >/dev/null 2>&1; then
      uvx gdown 'https://drive.google.com/drive/folders/1vjMG9j9t9cay5baPQbYLngWRi-EQ2pyK?usp=sharing' --folder --no-cookies --output "$NEOFETCH_IMG_DIR" \
        || warn "Neofetch asset download failed"
    else
      warn "uvx not found; skipping neofetch assets"
    fi
  fi
}

# --- Main ---------------------------------------------------------------------
main() {
  section "Dotfiles Installation"
  step   "Repo: $DOTFILES_DIR"

  local os_type
  os_type="$(detect_os)"
  step "Detected OS: $os_type"

  # Write flags + OS env snapshot FIRST so .zshenv can rely on them
  write_os_flags "$os_type"
  write_os_env_snapshot "$os_type"

  # Ensure ~/.local/bin exists and is usable in this process
  ensure_local_bin_in_path

  # Symlinks (includes .zshenv early)
  setup_symlinks "$os_type"

  # Packages + tools
  install_platform_packages "$os_type"
  install_developer_tools "$os_type"

  # Git identity + credential helper
  setup_git_identity
  configure_credential_helper "$os_type"

  # Misc + assets
  setup_misc_tools
  download_neofetch_assets

  section "Done"
  step   "Open a new shell or run: source ~/.zshrc"
}

main "$@"
