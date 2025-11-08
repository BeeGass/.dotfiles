#!/usr/bin/env bash
# ~/.dotfiles/install/refresh.sh
# Fast, idempotent environment refresh for macOS/Ubuntu/Termux.
# - Updates: PATH stubs, local overrides, Oh-My-Posh, Zsh plugins, uv+Python tools, Node LTS+globals, tmux plugins
# - Controls: --fast, --dry-run, --only <section>, --no-{python,node,omp}, -v
# - Safe: never overwrites symlinks/files unless explicitly a managed link

set -euo pipefail

# ----------------------------- CLI/flags ---------------------------------------
DRYRUN=0; FAST=0; VERBOSE=0; CLEAN_BACKUPS=0
DO_PY=1; DO_NODE=1; DO_OMP=1; ONLY=""
while (( $# )); do
  case "${1}" in
    --dry-run) DRYRUN=1 ;;
    --fast) FAST=1 ;;
    --clean-backups) CLEAN_BACKUPS=1 ;;
    --only) shift; ONLY="${1:-}";;
    --no-python) DO_PY=0 ;;
    --no-node) DO_NODE=0 ;;
    --no-omp) DO_OMP=0 ;;
    -v|--verbose) VERBOSE=$((VERBOSE+1)) ;;
    -h|--help)
      cat <<'EOF'
Usage: refresh.sh [OPTIONS]

Options:
  --fast              Skip time-consuming updates (Python installs, Flatpak/tmux updates)
  --dry-run           Show what would be done without making changes
  --clean-backups     Remove all *.backup.* files found in home and dotfiles
  --only SECTION      Run only the specified section
  --no-python         Skip Python/uv toolchain section
  --no-node           Skip Node.js/npm section
  --no-omp            Skip Oh-My-Posh updates
  -v, --verbose       Increase verbosity (can be repeated)

Sections:
  Core:     path, local, directories, cleanup, backups
  Tools:    omp, zsh, python, node, tmux
  Apps:     snap, claude, gemini, opencode, flatpak
  System:   tailscale, sf, doctor
  Special:  all (runs all sections)
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
  GRN=$(tput setaf 2); YEL=$(tput setaf 3); RED=$(tput setaf 1); BLU=$(tput setaf 4); CYA=$(tput setaf 6); MAG=$(tput setaf 5)
else
  BOLD=$'\033[1m'; RESET=$'\033[0m'; DIM=$'\033[2m'
  GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; BLU=$'\033[34m'; CYA=$'\033[36m'; MAG=$'\033[35m'
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

# Helper: apt presence (Ubuntu/Debian-ish)
have_apt(){ have apt-get || have apt; }

# ----------------------------- sections ----------------------------------------

section_path(){
  section "PATH & loader stubs"
  mkdir -p "$LOCAL_BIN"
  if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    export PATH="$LOCAL_BIN:$PATH"; ok "Temporarily added $LOCAL_BIN to PATH"
  else
    note "PATH already includes $LOCAL_BIN"
  fi

  # Link dotfiles scripts to PATH
  if [[ -f "$DOT/install/install.sh" ]]; then
    run "ln -sf \"$DOT/install/install.sh\" \"$LOCAL_BIN/dots-install\""
    ok "Linked dots-install"
  fi
  if [[ -f "$DOT/install/refresh.sh" ]]; then
    run "ln -sf \"$DOT/install/refresh.sh\" \"$LOCAL_BIN/dots-refresh\""
    ok "Linked dots-refresh"
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

section_cleanup(){
  section "Legacy cleanup"

  # Clean up Microsoft repo if it exists (no longer needed)
  if [[ "$OS_NAME" == "Linux" ]] && have_apt; then
    local ms_keyring="/etc/apt/trusted.gpg.d/microsoft.gpg"
    local ms_sourcelist="/etc/apt/sources.list.d/microsoft-prod.list"
    local removed=0

    if [[ -f "$ms_keyring" ]]; then
      note "Removing Microsoft GPG key"
      run "sudo rm -f \"$ms_keyring\""
      ok "Removed $ms_keyring"
      removed=1
    fi

    if [[ -f "$ms_sourcelist" ]]; then
      note "Removing Microsoft sources list"
      run "sudo rm -f \"$ms_sourcelist\""
      ok "Removed $ms_sourcelist"
      removed=1
    fi

    # Nuke any stray packages.microsoft.com lines
    local ms_hits
    ms_hits="$(grep -R "packages.microsoft.com" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)"
    if [[ -n "$ms_hits" ]]; then
      note "Stripping packages.microsoft.com from apt sources"
      while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        run "sudo sed -i '/packages.microsoft.com/d' \"$f\""
        removed=1
      done < <(grep -Rl "packages.microsoft.com" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)
    fi

    if (( removed )); then
      note "Refreshing package lists after cleanup"
      run "sudo apt-get update -y || sudo apt update -y"
      ok "Microsoft repo cleanup complete"
    else
      note "No legacy Microsoft repo configuration found"
    fi
  else
    note "No apt-based cleanup needed on this platform"
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

section_directories(){
  section "User directories & bookmarks"

  # Create standard directories
  local dirs=("$HOME/Projects" "$HOME/Papers")
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      run "mkdir -p \"$dir\""
      ok "Created $(basename "$dir") directory"
    else
      note "$(basename "$dir") directory already exists"
    fi
  done

  # Add to GTK bookmarks (for GNOME Files/Nautilus sidebar)
  if [[ "$OS_NAME" == "Linux" ]]; then
    local bookmarks_file="$HOME/.config/gtk-3.0/bookmarks"
    mkdir -p "$(dirname "$bookmarks_file")"

    # Ensure bookmarks file exists
    [[ ! -f "$bookmarks_file" ]] && touch "$bookmarks_file"

    # Add bookmarks if not already present
    local projects_bookmark="file://$HOME/Projects Projects"
    local papers_bookmark="file://$HOME/Papers Papers"

    if ! grep -Fxq "$projects_bookmark" "$bookmarks_file" 2>/dev/null; then
      echo "$projects_bookmark" >> "$bookmarks_file"
      ok "Added Projects to file manager sidebar"
    else
      note "Projects bookmark already present"
    fi

    if ! grep -Fxq "$papers_bookmark" "$bookmarks_file" 2>/dev/null; then
      echo "$papers_bookmark" >> "$bookmarks_file"
      ok "Added Papers to file manager sidebar"
    else
      note "Papers bookmark already present"
    fi
  else
    note "GTK bookmarks only apply to Linux desktop environments"
  fi
}

section_clean_backups(){
  section "Backup file cleanup"

  # Search ALL locations where backups are created by install/refresh scripts
  # Covers: symlink destinations, modified configs, and dotfiles repo itself
  local backup_files=()
  local search_paths=(
    # Root level dotfiles
    "$HOME"                           # .zshrc, .zshenv, .vimrc, .gitconfig, .tmux.conf (maxdepth 1)

    # XDG and standard config directories
    "$HOME/.config"                   # nvim, kitty, wezterm, ghostty, claude, gemini, oh-my-posh, picom, neofetch, gtk-3.0, fontconfig, systemd
    "$HOME/.local"                    # bin, share, state

    # Tool-specific directories
    "$HOME/.ssh"                      # config, config.d/
    "$HOME/.gnupg"                    # gpg-agent.conf, gpg.conf, dirmngr.conf
    "$HOME/.tmux"                     # plugins/tpm
    "$HOME/.nvm"                      # Node Version Manager
    "$HOME/.zsh"                      # plugins (autosuggestions, syntax-highlighting)
    "$HOME/.termux"                   # Termux configs (Android only)
    "$HOME/.opencode"                 # OpenCode CLI installation

    # Dotfiles repo and all subdirectories
    "$DOT"                            # All dotfiles source files
  )

  for search_path in "${search_paths[@]}"; do
    [[ ! -d "$search_path" ]] && continue

    local depth_limit="-maxdepth 1"
    # Search recursively everywhere except $HOME root (to avoid Documents, Downloads, etc.)
    [[ "$search_path" != "$HOME" ]] && depth_limit=""

    # Exclude snap directories (managed by snap system, includes trash)
    while IFS= read -r -d '' file; do
      [[ "$file" == "$HOME/snap/"* ]] && continue
      backup_files+=("$file")
    done < <(find "$search_path" $depth_limit -type f -name "*.backup.*" -print0 2>/dev/null)
  done

  if (( ${#backup_files[@]} == 0 )); then
    note "No backup files found"
    return
  fi

  # Group by location for better reporting
  local by_location=()
  for file in "${backup_files[@]}"; do
    local loc="other"
    [[ "$file" == "$HOME/.config/"* ]] && loc=".config"
    [[ "$file" == "$HOME/.local/"* ]] && loc=".local"
    [[ "$file" == "$HOME/.ssh/"* ]] && loc=".ssh"
    [[ "$file" == "$HOME/.gnupg/"* ]] && loc=".gnupg"
    [[ "$file" == "$HOME/.tmux/"* ]] && loc=".tmux"
    [[ "$file" == "$HOME/.nvm/"* ]] && loc=".nvm"
    [[ "$file" == "$HOME/.zsh/"* ]] && loc=".zsh"
    [[ "$file" == "$HOME/.termux/"* ]] && loc=".termux"
    [[ "$file" == "$HOME/.opencode/"* ]] && loc=".opencode"
    [[ "$file" == "$DOT/"* ]] && loc="dotfiles"
    [[ "$file" == "$HOME/"* && "$file" != "$HOME/"*"/"* ]] && loc="home"
    by_location+=("$loc:$file")
  done

  if [[ $CLEAN_BACKUPS -eq 0 ]]; then
    warn "Found ${#backup_files[@]} backup file(s) (use --clean-backups to remove)"
    if (( VERBOSE > 0 )); then
      printf "  ${DIM}Search locations: home, .config, .local, .ssh, .gnupg, .tmux, .nvm, .zsh, .termux, .opencode, dotfiles${RESET}\n"
      for item in "${by_location[@]}"; do
        note "  - ${item#*:}"
      done
    fi
    return
  fi

  step "Removing ${#backup_files[@]} backup file(s)"
  local removed=0
  for file in "${backup_files[@]}"; do
    if (( VERBOSE > 0 )); then
      note "Removing: $file"
    fi
    if (( DRYRUN )); then
      printf "  %s[dry]%s would remove: %s\n" "${BLU}${BOLD}" "${RESET}" "$file"
    else
      rm -f "$file" && removed=$((removed + 1)) || warn "Failed to remove: $file"
    fi
  done

  ok "Removed $removed backup file(s)"
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
    local GLOBALS="${NPM_GLOBALS:-@google/gemini-cli typescript typescript-language-server}"
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

section_snap(){
  section "Snap apps"
  if ! have snap; then
    note "Snap not installed; skipping"
    return
  fi

  # Verify VS Code is installed
  if snap list 2>/dev/null | grep -q "^code "; then
    note "VS Code installed"
    ok "Snap: VS Code present"
  else
    warn "VS Code not found (run ubuntu-install.sh to install)"
  fi
}

section_claude_code(){
  section "Claude Code"

  if have claude; then
    note "Claude Code installed"
    local version
    version=$(claude --version 2>/dev/null || echo "unknown")
    ok "Claude Code present: $version"
  else
    warn "Claude Code not found"
    if [[ "$OS_NAME" == "macOS" ]]; then
      if have brew; then
        note "Install with: brew install --cask claude-code"
      else
        warn "Homebrew not found; cannot install Claude Code"
      fi
    elif [[ "$OS_NAME" == "Linux" ]]; then
      note "Install with: curl -fsSL https://claude.ai/install.sh | bash"
    fi
  fi
}

section_gemini_cli(){
  section "Gemini CLI"

  if have gemini; then
    note "Gemini CLI installed"
    local version
    version=$(gemini --version 2>/dev/null || echo "unknown")
    ok "Gemini CLI present: $version"
  else
    warn "Gemini CLI not found"
    if have npm; then
      note "Install with: npm install -g @google/gemini-cli@latest"
    else
      warn "npm not found; cannot install Gemini CLI"
    fi
  fi
}

section_opencode(){
  section "OpenCode CLI"

  if [[ -d "$HOME/.opencode" ]] || have opencode; then
    note "OpenCode CLI installed"
    if have opencode; then
      local version
      version=$(opencode --version 2>/dev/null || echo "unknown")
      ok "OpenCode CLI present: $version"
    else
      ok "OpenCode CLI present (in ~/.opencode)"
    fi
  else
    warn "OpenCode CLI not found"
    note "Install with: curl -fsSL https://opencode.ai/install | bash"
  fi
}

section_flatpak(){
  section "Flatpak apps"
  if ! have flatpak; then
    note "Flatpak not installed; skipping"
    return
  fi

  # Ensure Flathub is configured
  if ! flatpak remote-list | grep -q flathub; then
    run "sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
    ok "Added Flathub repository"
  else
    note "Flathub already configured"
  fi

  # Update all Flatpak apps
  if (( FAST )); then
    note "FAST: skipping Flatpak update"
  else
    run "sudo flatpak update -y || true"
    ok "Flatpak apps updated"
  fi

  # Verify expected apps are installed
  local expected_apps=(
    "md.obsidian.Obsidian:Obsidian"
    "com.discordapp.Discord:Discord"
    "com.valvesoftware.Steam:Steam"
    "com.google.Chrome:Google Chrome"
    "org.telegram.desktop:Telegram"
    "com.spotify.Client:Spotify"
    "com.slack.Slack:Slack"
  )

  local installed_count=0
  local missing_count=0
  for app in "${expected_apps[@]}"; do
    local app_id="${app%%:*}"
    local app_name="${app#*:}"
    if flatpak list --app | grep -q "$app_id"; then
      note "$app_name installed"
      installed_count=$((installed_count + 1))
    else
      if (( VERBOSE > 0 )); then
        warn "$app_name not found"
      fi
      missing_count=$((missing_count + 1))
    fi
  done

  if (( missing_count > 0 )); then
    warn "$missing_count apps missing (run ubuntu-install.sh to install)"
  fi
  ok "Flatpak: $installed_count/${#expected_apps[@]} apps present"
}

section_tailscale(){
  section "Tailscale"
  if [[ "$OS_NAME" != "Linux" ]] || ! have_apt; then
    note "Non-Ubuntu/apt system; skipping Tailscale enforcement"
    return
  fi

  if have tailscale; then
    ok "Tailscale already installed"
    return
  fi

  # Best-effort mirror of installer; safe to run multiple times
  local codename
  codename="$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-}")"

  note "Tailscale missing; configuring repo for $codename (best-effort)"
  run "sudo mkdir -p /usr/share/keyrings"
  run "curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null"
  run "curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null"
  run "sudo chmod 0644 /usr/share/keyrings/tailscale-archive-keyring.gpg /etc/apt/sources.list.d/tailscale.list || true"
  run "sudo apt-get update -y || true"
  run "sudo apt-get install -y tailscale tailscale-archive-keyring || true"

  if have tailscale; then
    ok "Tailscale installed"
  else
    warn "Tailscale install failed (check logs)"
  fi
}

section_sf(){
  section "SF Compute CLI"
  if have sf; then
    ok "sf CLI present"
    return
  fi

  local tmp
  tmp="$(mktemp -d)"
  note "Installing sf CLI to $LOCAL_BIN"
  run "mkdir -p \"$LOCAL_BIN\""
  if run "curl -fsSL -o \"$tmp/sf.zip\" https://github.com/sfcompute/cli/releases/latest/download/sf-x86_64-unknown-linux-gnu.zip" &&
     run "unzip -o \"$tmp/sf.zip\" -d \"$tmp/dist\" >/dev/null 2>&1" &&
     [[ -f "$tmp/dist/sf-x86_64-unknown-linux-gnu" ]]; then
    run "mv \"$tmp/dist/sf-x86_64-unknown-linux-gnu\" \"$LOCAL_BIN/sf\""
    run "chmod +x \"$LOCAL_BIN/sf\""
    ok "Installed sf CLI"
  else
    warn "Failed to install sf CLI"
  fi
  run "rm -rf \"$tmp\""
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

in_scope path       && section_path
in_scope local      && section_local
in_scope directories && section_directories
in_scope cleanup    && section_cleanup
in_scope backups    && section_clean_backups
in_scope omp        && section_omp
in_scope zsh        && section_zsh
in_scope python     && section_python
in_scope node       && section_node
in_scope tmux       && section_tmux
in_scope snap       && section_snap
in_scope claude     && section_claude_code
in_scope gemini     && section_gemini_cli
in_scope opencode   && section_opencode
in_scope flatpak    && section_flatpak
in_scope tailscale  && section_tailscale
in_scope sf         && section_sf
in_scope doctor     && section_doctor

section "Done"
note "Open a new shell or: source ~/.zshrc"
