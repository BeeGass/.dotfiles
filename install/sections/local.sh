#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  # Alias for refresh.sh compatibility
  DOT="$DOTFILES_DIR"
  ZDOT_LOCAL="$DOT/zsh/90-local.zsh"

  section "Machine-local overrides (~/.dotfiles/zsh/90-local.zsh)"
  mkdir -p "$(dirname "$ZDOT_LOCAL")"
  if [[ ! -f "$ZDOT_LOCAL" ]]; then
    run "umask 077; cat > \"$ZDOT_LOCAL\" <<'EOF'
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
# export GEMINI_API_KEY=\"__SET_ME_SECURELY__\"

# HF_TOKEN: User Access Token for HuggingFace Hub authentication
# Default: None
# Usage: Set to your personal access token from https://huggingface.co/settings/tokens
# export HF_TOKEN=\"__SET_ME_SECURELY__\"

# ==============================================================================
# ENVIRONMENT Variables - Local Overrides
# ==============================================================================
# PYPEX_CACHE_DIR: Main cache directory for PyPex datasets
# This takes precedence over HF_HOME for PyPex operations
# Default: Falls back to HF_HOME or ~/.cache/huggingface
export PYPEX_CACHE_DIR=\"\$HOME/.cache/ludo/pypex\"

# ==============================================================================
# PATH Additions - Local Overrides
# ==============================================================================
# OpenCode CLI (machine-local)
if [ -d \"\$HOME/.opencode/bin\" ]; then
    export PATH=\"\$HOME/.opencode/bin:\$PATH\"
fi

# ==============================================================================
# HUGGINGFACE ENVIRONMENT VARIABLES
# ==============================================================================

# ------------------------------------------------------------------------------
# Cache & Storage Paths
# ------------------------------------------------------------------------------

# HF_HOME: Main HuggingFace cache directory
# Default: ~/.cache/huggingface (or \$XDG_CACHE_HOME/huggingface if XDG_CACHE_HOME is set)
export HF_HOME=\"\$HOME/.cache/huggingface\"

# HF_HUB_CACHE: Where repositories from the Hub are cached
# Default: \$HF_HOME/hub
export HF_HUB_CACHE=\"\$HF_HOME/hub\"

# TRANSFORMERS_CACHE: Alias for HF_HUB_CACHE (for backward compatibility)
# Default: \$HF_HOME/hub
# export TRANSFORMERS_CACHE=\"\$HF_HOME/hub\"

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
# export HF_INFERENCE_ENDPOINT=\"https://api-inference.huggingface.co\"

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
# export HF_HUB_VERBOSITY=\"warning\"

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
# OAUTH_SCOPES: OAuth scopes (default: \"openid profile\")
EOF"
    run "chmod 600 \"$ZDOT_LOCAL\""
    ok "Created $ZDOT_LOCAL"
  else
    note "Local overrides already exist (left unchanged)"
  fi

  local kitty_local="$HOME/.config/kitty/local.conf"
  if [[ ! -f "$kitty_local" ]]; then
    step "Creating machine-local kitty overrides: $kitty_local"
    mkdir -p "$(dirname "$kitty_local")"
    local os_type
    os_type="$(detect_os)"
    {
      echo "# Machine-local Kitty overrides"
      echo "# Auto-generated by local.sh -- edit freely"
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

main "$@"
