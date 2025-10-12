# --- refresh.sh (replace your current file with this full script) -------------
#!/usr/bin/env bash
# refresh.sh — idempotent refresh for shell env + CLIs (no pipx)
set -euo pipefail

log() { printf "\n[refresh] %s\n" "$*"; }
backup_file() { local f="$1"; [[ -f "$f" && ! -L "$f" ]] && cp -a "$f" "${f}.backup.$(date +%Y%m%d_%H%M%S)"; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- 0) Ensure ~/.zshrc loader stub, but don't touch if it's a symlink --------
STUB_START="# >>> BeeGass dotfiles >>>"
STUB_END="# <<< BeeGass dotfiles <<<"
STUB_CONTENT=$(cat <<'EOF'
# >>> BeeGass dotfiles >>>
if [ -f "$HOME/.dotfiles/zsh/zshrc" ]; then
  source "$HOME/.dotfiles/zsh/zshrc"
fi
# <<< BeeGass dotfiles <<<
EOF
)

touch "$HOME/.zshrc"

# If .zshrc is a symlink (e.g., to your repo zshrc), don't append a stub
if [[ -L "$HOME/.zshrc" ]]; then
  log "~/.zshrc is a symlink; skipping loader stub"
else
  if ! grep -Fq "$STUB_START" "$HOME/.zshrc"; then
    log "Adding dotfiles loader to ~/.zshrc"
    backup_file "$HOME/.zshrc"
    printf "\n%s\n" "$STUB_CONTENT" >> "$HOME/.zshrc"
  else
    log "~/.zshrc loader already present"
  fi
fi


# --- 1) Ensure 90-local.zsh exists (never overwrite) --------------------------
LOCAL_OVR="$HOME/.dotfiles/zsh/90-local.zsh"
install -d "$(dirname "$LOCAL_OVR")"
if [[ ! -f "$LOCAL_OVR" ]]; then
  log "Creating $LOCAL_OVR (machine-local overrides)"
  umask 077
  cat > "$LOCAL_OVR" <<'EOF'
# Local Machine Settings

# ==============================================================================
# GPG Agent for SSH
# ==============================================================================
if command -v gpgconf &> /dev/null; then
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    export GPG_TTY=$(tty)
    gpgconf --launch gpg-agent >/dev/null 2>&1 || true
fi

# ==============================================================================
# API KEYS
# ==============================================================================
# ...

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
  chmod 600 "$LOCAL_OVR"
else
  log "$LOCAL_OVR already exists (left unchanged)"
fi

# --- 2) Ensure OpenCode installed (and PATH will pick it up next shell) -------
log "Installing/updating OpenCode CLI"
curl -fsSL https://opencode.ai/install | bash || true

# --- 3) Update oh-my-posh + zsh plugins --------------------------------------
if have brew; then
  log "Brew update/upgrade core bits"
  brew update
  brew upgrade jandedobbeleer/oh-my-posh/oh-my-posh || true
  brew upgrade zsh-autosuggestions zsh-syntax-highlighting || true
elif have apt; then
  log "Refreshing oh-my-posh via official installer (Debian/Ubuntu)"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin" || true
  log "Installing zsh plugins via apt"
  sudo apt update -y
  sudo apt install -y zsh-autosuggestions zsh-syntax-highlighting || true
else
  log "Unknown package manager; skipping oh-my-posh/plugin upgrades"
fi

# --- 3b) Ensure an oh-my-posh config exists (repo-managed) --------------------
OMP_DIR="$HOME/.dotfiles/oh-my-posh"
OMP_CFG="$OMP_DIR/config.json"
install -d "$OMP_DIR"

if [[ ! -e "$OMP_CFG" ]]; then
  log "Scaffolding oh-my-posh config in repo"
  cat > "$OMP_CFG" <<'JSON'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "final_space": true,
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "segments": [
        { "type": "path",   "style": "powerline" },
        { "type": "git",    "style": "powerline" },
        { "type": "python", "style": "powerline" }
      ]
    }
  ]
}
JSON
  log "Wrote minimal OMP config at $OMP_CFG"
fi

# Optional: also expose it under XDG so other tools discover it
XDG_OMP="$HOME/.config/oh-my-posh/config.json"
install -d "$(dirname "$XDG_OMP")"
ln -sfn "$OMP_CFG" "$XDG_OMP"


# --- 4) Update Claude Code + Gemini CLI (Node toolchains only) ----------------
update_node_globals() {
  if have npm; then
    log "npm: installing/updating globals: $*"
    npm install -g "$@" || true
  elif have pnpm; then
    log "pnpm: installing/updating globals: $*"
    pnpm add -g "$@" || true
  elif have yarn; then
    log "yarn: installing/updating globals: $*"
    yarn global add "$@" || true
  else
    log "No Node package manager detected; skipping: $*"
  fi
}
update_node_globals @anthropic-ai/claude-code @google/gemini-cli

# --- 5) uv install/update + ensure Pythons 3.11/3.12 --------------------------
log "Installing/updating uv"
curl -LsSf https://astral.sh/uv/install.sh | sh

# Locate uv (prefer PATH; fall back to ~/.local/bin/uv)
UV_BIN="$(command -v uv || true)"
[[ -z "$UV_BIN" && -x "$HOME/.local/bin/uv" ]] && UV_BIN="$HOME/.local/bin/uv"

if [[ -n "$UV_BIN" ]]; then
  log "Using uv at $UV_BIN"
  "$UV_BIN" --version || true
  log "Installing CPython 3.11 and 3.12 via uv"
  "$UV_BIN" python install 3.11 3.12
  log "Regenerating zsh completions for uv"
  eval "$("$UV_BIN" generate-shell-completion zsh)" >/dev/null 2>&1 || true
else
  log "uv not found after install; ensure ~/.local/bin is in PATH, then rerun."
fi

# --- 6) Final notes -----------------------------------------------------------
log "Refresh complete. Open a new terminal or run: source ~/.zshrc"
