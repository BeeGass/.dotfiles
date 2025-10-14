#!/usr/bin/env bash
# ~/.dotfiles/install/refresh.sh
# Fast, idempotent environment refresh for macOS/Ubuntu/Termux.
# - Updates: PATH stubs, local overrides, Oh-My-Posh, Zsh plugins, uv+Python tools, Node LTS+globals, tmux plugins
# - Controls: --fast, --dry-run, --only <section>, --no-{python,node,omp}, -v
# - Safe: never overwrites symlinks/files unless explicitly a managed link

set -euo pipefail

# ----------------------------- CLI/flags ---------------------------------------
DRYRUN=0; FAST=0; VERBOSE=0
DO_PY=1; DO_NODE=1; DO_OMP=1; ONLY=""
while (( $# )); do
  case "${1}" in
    --dry-run) DRYRUN=1 ;;
    --fast) FAST=1 ;;
    --only) shift; ONLY="${1:-}";;
    --no-python) DO_PY=0 ;;
    --no-node) DO_NODE=0 ;;
    --no-omp) DO_OMP=0 ;;
    -v|--verbose) VERBOSE=$((VERBOSE+1)) ;;
    -h|--help)
      cat <<'EOF'
Usage: refresh.sh [--fast] [--dry-run] [--only SECTION] [--no-python] [--no-node] [--no-omp] [-v]
Sections: path, local, omp, zsh, python, node, tmux, doctor, all
EOF
      exit 0
      ;;
  esac; shift
done
[[ -z "${ONLY}" ]] && ONLY="all"

# ----------------------------- logging -----------------------------------------
_use_color=1; [[ ! -t 1 || -n "${NO_COLOR:-}" ]] && _use_color=0
if [[ $_use_color -eq 1 ]] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
  BOLD=$(tput bold); RESET=$(tput sgr0); DIM=$(tput dim)
  GRN=$(tput setaf 2); YEL=$(tput setaf 3); RED=$(tput setaf 1); BLU=$(tput setaf 4); CYA=$(tput setaf 6)
else
  BOLD=$'\033[1m'; RESET=$'\033[0m'; DIM=$'\033[2m'
  GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; BLU=$'\033[34m'; CYA=$'\033[36m'
fi
section(){ printf "%s==>%s %s%s%s\n" "${CYA}${BOLD}" "${RESET}" "${BOLD}" "$*" "${RESET}"; }
note(){ [[ $VERBOSE -gt 0 ]] && printf "  %s%s%s\n" "${DIM}" "$*" "${RESET}" || true; }
ok(){ printf "  %s[ok]%s %s\n" "${GRN}${BOLD}" "${RESET}" "$*"; }
warn(){ printf "  %s[warn]%s %s\n" "${YEL}${BOLD}" "${RESET}" "$*"; }
err(){ printf "  %s[err ]%s %s\n" "${RED}${BOLD}" "${RESET}" "$*"; }

run(){ if (( DRYRUN )); then printf "  %s[dry]%s %s\n" "${BLU}${BOLD}" "${RESET}" "$*"; else eval "$@"; fi; }
have(){ command -v "$1" >/dev/null 2>&1; }

# ----------------------------- env/context -------------------------------------
DOT="${DOTFILES_DIR:-$HOME/.dotfiles}"
LOCAL_BIN="$HOME/.local/bin"
ZDOT_LOCAL="$DOT/zsh/90-local.zsh"
OS(){
  if [[ -n "${TERMUX_VERSION-}" || "${PREFIX-}" == *"com.termux"* ]]; then echo "Termux"; return; fi
  case "$(uname -s)" in Darwin) echo "macOS";; Linux) echo "Linux";; *) echo "Unknown";; esac
}
OS_NAME="$(OS)"

# ----------------------------- helpers -----------------------------------------
backup_file(){ local f="$1"; [[ -f "$f" && ! -L "$f" ]] && cp -a "$f" "${f}.backup.$(date +%Y%m%d_%H%M%S)"; }
append_once(){ local file="$1" line="$2"; grep -Fqx "$line" "$file" 2>/dev/null || printf "%s\n" "$line" >> "$file"; }

in_scope(){ [[ "$ONLY" == "all" || "$ONLY" == "$1" ]]; }

# ----------------------------- sections ----------------------------------------

section_path(){
  section "PATH & loader stubs"
  mkdir -p "$LOCAL_BIN"
  if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    export PATH="$LOCAL_BIN:$PATH"; ok "Temporarily added $LOCAL_BIN to PATH"
  else
    note "PATH already includes $LOCAL_BIN"
  fi
  # Ensure .zshrc loader stub unless ~/.zshrc is a symlink
  touch "$HOME/.zshrc"
  if [[ -L "$HOME/.zshrc" ]]; then
    note "~/.zshrc is a symlink; not touching"
  else
    local START="# >>> BeeGass dotfiles >>>"
    local END="# <<< BeeGass dotfiles <<<"
    if ! grep -Fq "$START" "$HOME/.zshrc"; then
      backup_file "$HOME/.zshrc"
      run "printf '\n%s\n%s\n%s\n' '$START' 'if [ -f \"$DOT/zsh/zshrc\" ]; then source \"$DOT/zsh/zshrc\"; fi' '$END' >> \"$HOME/.zshrc\""
      ok "Appended loader stub to ~/.zshrc"
    else
      note "Loader stub already present"
    fi
  fi
}

section_local(){
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
# export GEMINI_API_KEY="__SET_ME_SECURELY__"

# HF_TOKEN: User Access Token for HuggingFace Hub authentication
# Default: None
# Usage: Set to your personal access token from https://huggingface.co/settings/tokens
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
EOF"
    run "chmod 600 \"$ZDOT_LOCAL\""
    ok "Created $ZDOT_LOCAL"
  else
    note "Local overrides already exist (left unchanged)"
  fi
}

section_omp(){
  [[ $DO_OMP -eq 1 ]] || { note "OMP disabled via flag"; return; }
  section "Oh-My-Posh + config"
  if [[ "$OS_NAME" == "macOS" ]] && have brew; then
    run "brew update"
    run "brew upgrade jandedobbeleer/oh-my-posh/oh-my-posh || brew upgrade oh-my-posh || true"
  elif have apt; then
    run "curl -s https://ohmyposh.dev/install.sh | bash -s -- -d \"$LOCAL_BIN\""
  else
    run "curl -s https://ohmyposh.dev/install.sh | bash -s -- -d \"$LOCAL_BIN\""
  fi
  # Link config if repo has it
  if [[ -f "$DOT/oh-my-posh/config.json" ]]; then
    run "mkdir -p \"$HOME/.config/oh-my-posh\""
    run "ln -sfn \"$DOT/oh-my-posh/config.json\" \"$HOME/.config/oh-my-posh/config.json\""
    ok "Linked OMP config"
  else
    warn "No repo OMP config found; skipping link"
  fi
}

section_zsh(){
  section "Zsh plugins"
  # Prefer package manager upgrades where available
  if [[ "$OS_NAME" == "macOS" ]] && have brew; then
    run "brew upgrade zsh-autosuggestions zsh-syntax-highlighting || true"
  elif have apt; then
    run "sudo apt update -y || true"
    run "sudo apt install -y zsh-autosuggestions zsh-syntax-highlighting || true"
  fi
  # Ensure git-based clones exist (covers Termux/others)
  local plugroot="$HOME/.zsh/plugins"
  run "mkdir -p \"$plugroot\""
  [[ -d "$plugroot/zsh-autosuggestions" ]] || run "git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \"$plugroot/zsh-autosuggestions\""
  [[ -d "$plugroot/zsh-syntax-highlighting" ]] || run "git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \"$plugroot/zsh-syntax-highlighting\""
  # Ensure sourcing lines in ~/.zshrc (harmless if already present)
  append_once "$HOME/.zshrc" "[[ -r ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  append_once "$HOME/.zshrc" "[[ -r ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  ok "Zsh plugins ready"
}

section_python(){
  [[ $DO_PY -eq 1 ]] || { note "Python disabled via flag"; return; }
  section "uv + Python toolchain"
  # Install/update uv
  if ! have uv; then run "curl -Ls https://astral.sh/uv/install.sh | sh"; fi
  # Re-resolve uv bin after install
  local UV="$(command -v uv || true)"
  [[ -z "$UV" && -x "$HOME/.local/bin/uv" ]] && UV="$HOME/.local/bin/uv"
  if [[ -z "$UV" ]]; then warn "uv not found after install"; return; fi
  run "\"$UV\" self update || true"
  if (( FAST )); then
    note "FAST: skipping CPython re-installs"
  else
    run "\"$UV\" python install 3.11 3.12 || true"
  fi
  # CLI tools via uv tool (idempotent)
  run "\"$UV\" tool install 'python-lsp-server[all]' || true"
  run "\"$UV\" tool install ruff || true"
  run "\"$UV\" tool install mypy || true"
  run "\"$UV\" tool install pytest || true"
  run "\"$UV\" tool install pre-commit || true"
  # Optional: auto-bootstrap pre-commit in this repo (commented)
  # if [[ -f \"$DOT/.pre-commit-config.yaml\" ]]; then (cd \"$DOT\" && run \"pre-commit install\"); fi
  # Shell completions (no-op if not supported)
  run "\"$UV\" generate-shell-completion zsh >/dev/null 2>&1 || true"
  ok "uv + Python tools refreshed"
}

section_node(){
  [[ $DO_NODE -eq 1 ]] || { note "Node disabled via flag"; return; }
  section "Node LTS + globals"
  export NVM_DIR="$HOME/.nvm"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    run "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
  fi
  # shellcheck source=/dev/null
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
  if have nvm; then
    run "nvm install --lts"
    run "nvm alias default 'lts/*'"
    run "nvm use default >/dev/null || true"
    # Globals (customize via NPM_GLOBALS env)
    local GLOBALS="${NPM_GLOBALS:-@google/gemini-cli @anthropic-ai/claude-code typescript typescript-language-server}"
    run "npm install -g ${GLOBALS} || true"
    ok "Node $(node -v 2>/dev/null || echo '-')"
  else
    warn "nvm not available after install; skipping Node section"
  fi
}

section_tmux(){
  section "tmux plugins (TPM)"
  local TPM="$HOME/.tmux/plugins/tpm"
  if [[ -d "$TPM" ]]; then
    run "\"$TPM/bin/install_plugins\" || true"
    (( FAST )) || run "\"$TPM/bin/update_plugins\" all || true"
    ok "TPM plugins refreshed"
  else
    note "TPM not found; skipping"
  fi
}

section_doctor(){
  section "Doctor"
  local DOC="$DOT/scripts/doctor.sh"
  if [[ -x "$DOC" ]]; then
    if (( DRYRUN )); then
      printf "  %s[dry]%s would run: %s\n" "${BLU}${BOLD}" "${RESET}" "$DOC"
    else
      "$DOC" || true
    fi
  else
    note "No doctor script at $DOC"
  fi
}

# ----------------------------- dispatch ----------------------------------------
case "$ONLY" in
  all|path)     section_path;     [[ "$ONLY" != "all" ]] || true ;;
esac
case "$ONLY" in
  all|local)    section_local;    [[ "$ONLY" != "all" ]] || true ;;
esac
case "$ONLY" in
  all|omp)      section_omp;      [[ "$ONLY" != "all" ]] || true ;;
esac
case "$ONLY" in
  all|zsh)      section_zsh;      [[ "$ONLY" != "all" ]] || true ;;
esac
case "$ONLY" in
  all|python)   section_python;   [[ "$ONLY" != "all" ]] || true ;;
esac
case "$ONLY" in
  all|node)     section_node;     [[ "$ONLY" != "all" ]] || true ;;
esac
case "$ONLY" in
  all|tmux)     section_tmux;     [[ "$ONLY" != "all" ]] || true ;;
esac
case "$ONLY" in
  all|doctor)   section_doctor;   [[ "$ONLY" != "all" ]] || true ;;
esac

section "Done"
note "Open a new shell or: source ~/.zshrc"
