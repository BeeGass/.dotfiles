#!/usr/bin/env bash
# install/lib.sh - Shared library for dotfiles installation scripts
#
# Source this file to get common functions for install/refresh scripts.
# All functions are idempotent and safe to call multiple times.

# === Double-source guard ===
[[ -n "${_DOTFILES_LIB_LOADED:-}" ]] && return 0
_DOTFILES_LIB_LOADED=1

# === Flag variables (from env, overridable by CLI) ===
NO_SUDO="${NO_SUDO:-0}"
DRYRUN="${DRYRUN:-0}"
FAST="${FAST:-0}"
VERBOSE="${VERBOSE:-1}"

# === Environment detection and paths ===
resolve_dotfiles_dir() {
  if [[ -n "${DOTFILES_DIR:-}" && -d "${DOTFILES_DIR:-}" ]]; then
    printf '%s\n' "$DOTFILES_DIR"; return
  fi
  if command -v git >/dev/null 2>&1; then
    if top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      printf '%s\n' "$top"; return
    fi
  fi
  case "${BASH_SOURCE[0]-}" in
    ''|/dev/*|/proc/*) ;;
    *) ( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd ); return ;;
  esac
  printf '%s\n' "$HOME/.dotfiles"
}

DOTFILES_DIR="$(resolve_dotfiles_dir)"
SCRIPT_DIR="$DOTFILES_DIR/install"
LOCAL_BIN_DIR="$HOME/.local/bin"
XDG_STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}"
FLAGS_DIR="$XDG_STATE_ROOT/dotfiles/flags"
ENV_SNAPSHOT="$XDG_STATE_ROOT/dotfiles/os.env"
NEOFETCH_IMG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/neofetch/pics"

# === OS Detection ===
detect_os() {
  if [[ -n "${TERMUX_VERSION-}" ]] || [[ "${PREFIX-}" == *"com.termux"* ]] || [[ "$(uname -o 2>/dev/null || true)" == "Android" ]]; then
    echo "Termux"
  elif [[ "$(uname -s)" == "Linux" ]]; then
    echo "Linux"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macOS"
  else
    echo "Unknown"
  fi
}

OS_NAME="$(detect_os)"

# === Colors and Logging ===
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
step()    { printf "  %s->%s %s\n" "$BLUE$BOLD" "$RESET" "$*"; }
ok()      { printf "  %s[ok]%s %s\n" "$GREEN$BOLD" "$RESET" "$*"; }
warn()    { printf "  %s[warn]%s %s\n" "$YELLOW$BOLD" "$RESET" "$*"; }
err()     { printf "  %s[err ]%s %s\n" "$RED$BOLD" "$RESET" "$*"; }
note()    { [[ $VERBOSE -gt 0 ]] && printf "  %s%s%s\n" "$DIM" "$*" "$RESET" || true; }

# === Command execution helpers ===
run() {
  if (( DRYRUN )); then
    printf "  %s[dry]%s %s\n" "${BLUE}${BOLD}" "${RESET}" "$*"
  elif (( NO_SUDO )) && [[ "$*" == *sudo* ]]; then
    printf "  %s[skip]%s %s (--no-sudo)\n" "${MAGENTA}${BOLD}" "${RESET}" "$*"
  else
    eval "$@"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

have_apt() { have apt-get || have apt; }

# === Symlink and file helpers ===
create_symlink() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local bak="${dst}.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$dst" "$bak"
    warn "Backed up existing: $dst -> $bak"
  fi
  ln -sfn "$src" "$dst"
  ok "$src -> $dst"
}

backup_file() {
  local f="$1"
  [[ -f "$f" && ! -L "$f" ]] && cp -a "$f" "${f}.backup.$(date +%Y%m%d_%H%M%S)"
}

append_once() {
  local file="$1" line="$2"
  grep -Fqx "$line" "$file" 2>/dev/null || printf "%s\n" "$line" >> "$file"
}

# === Claude config helpers ===
# These functions manage symlinks for Claude Code configuration.
# They use run() for operations that might be affected by DRYRUN/NO_SUDO.

_symlink_claude_file() {
  local src_name="$1"
  local dst_name="$2"
  local claude_dotfiles="${DOTFILES_DIR}/claude"
  local claude_dir="$HOME/.claude"
  local src="$claude_dotfiles/$src_name"
  local dst="$claude_dir/$dst_name"

  [[ ! -e "$src" ]] && return

  if [[ -L "$dst" ]]; then
    local current_target expected_target
    current_target="$(readlink "$dst" 2>/dev/null)"
    expected_target="$src"
    if [[ "$current_target" != "$expected_target" ]]; then
      warn "$dst_name symlink points to wrong location"
      run "rm -f \"$dst\" && ln -s \"$src\" \"$dst\""
      ok "Fixed $dst_name symlink"
    else
      note "$dst_name symlink correct"
    fi
  elif [[ -e "$dst" ]]; then
    warn "$dst_name exists but is not a symlink"
    run "mv \"$dst\" \"${dst}.backup.\$(date +%Y%m%d_%H%M%S)\" && ln -s \"$src\" \"$dst\""
    ok "Replaced $dst_name with symlink (backed up original)"
  else
    run "mkdir -p \"$claude_dir\" && ln -s \"$src\" \"$dst\""
    ok "Created $dst_name symlink"
  fi
}

_symlink_claude_dir() {
  local dir="$1"
  local claude_dotfiles="${DOTFILES_DIR}/claude"
  local claude_dir="$HOME/.claude"
  local src="$claude_dotfiles/$dir"
  local dst="$claude_dir/$dir"

  [[ ! -d "$src" ]] && return

  if [[ -L "$dst" ]]; then
    local current_target expected_target
    current_target="$(readlink "$dst" 2>/dev/null)"
    expected_target="$src"
    if [[ "$current_target" != "$expected_target" ]]; then
      warn "$dir/ symlink points to wrong location"
      run "rm -f \"$dst\" && ln -s \"$src\" \"$dst\""
      ok "Fixed $dir/ symlink"
    else
      note "$dir/ symlink correct"
    fi
  elif [[ -d "$dst" ]]; then
    warn "$dir/ exists but is not a symlink"
    run "mv \"$dst\" \"${dst}.backup.\$(date +%Y%m%d_%H%M%S)\" && ln -s \"$src\" \"$dst\""
    ok "Replaced $dir/ with symlink (backed up original)"
  else
    run "mkdir -p \"$claude_dir\" && ln -s \"$src\" \"$dst\""
    ok "Created $dir/ symlink"
  fi
}

# === SSH server setup ===
# Unified SSH server configuration for Ubuntu/Raspberry Pi.
# Accepts a label parameter for the section header (e.g., "[Ubuntu]", "[RaspberryPi]").

setup_ssh_server_common() {
  local label="${1:-}"
  section "${label} Configure SSH server"

  if (( NO_SUDO )); then
    warn "Skipping SSH server configuration (--no-sudo)"
    return
  fi

  # Check if openssh-server is installed
  if ! have sshd && ! [[ -x /usr/sbin/sshd ]]; then
    warn "sshd not found; ensure openssh-server is installed"
    if have_apt; then
      note "Install with: sudo apt install -y openssh-server"
    fi
    return 1
  fi

  ok "openssh-server installed"

  # Create drop-in directory
  step "Creating SSH config drop-in directory"
  run "sudo mkdir -p /etc/ssh/sshd_config.d"

  # Symlink YubiKey SSH configuration
  local ssh_config_source="$DOTFILES_DIR/ssh/99-yubikey-only.conf"
  local ssh_config_target="/etc/ssh/sshd_config.d/99-yubikey-only.conf"

  if [[ ! -f "$ssh_config_source" ]]; then
    warn "Source SSH config not found: $ssh_config_source"
    return 0
  fi

  step "Symlinking YubiKey SSH configuration"
  local needs_restart=0

  if [[ -L "$ssh_config_target" ]]; then
    local current_target expected_target
    current_target="$(readlink -f "$ssh_config_target" 2>/dev/null)"
    expected_target="$(readlink -f "$ssh_config_source" 2>/dev/null)"

    if [[ "$current_target" == "$expected_target" ]]; then
      note "SSH config symlink correct"
    else
      warn "SSH config symlink points to wrong location"
      run "sudo ln -sf \"$ssh_config_source\" \"$ssh_config_target\""
      ok "Fixed SSH config symlink"
      needs_restart=1
    fi
  elif [[ -f "$ssh_config_target" ]]; then
    warn "SSH config exists but is not a symlink (replacing)"
    run "sudo rm -f \"$ssh_config_target\""
    run "sudo ln -sf \"$ssh_config_source\" \"$ssh_config_target\""
    ok "Created SSH config symlink"
    needs_restart=1
  else
    run "sudo ln -sf \"$ssh_config_source\" \"$ssh_config_target\""
    ok "Symlinked SSH config to /etc/ssh/sshd_config.d/"
    needs_restart=1
  fi

  # Check if main sshd_config has Include directive
  step "Verifying main sshd_config has Include directive"
  if [[ -f /etc/ssh/sshd_config ]] && ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
    warn "Include directive not found in sshd_config; may need manual configuration"
  else
    ok "Include directive present"
  fi

  # Disable SSH socket activation (conflicts with custom port)
  step "Disabling SSH socket activation (conflicts with custom port)"
  if systemctl is-enabled ssh.socket >/dev/null 2>&1; then
    run "sudo systemctl stop ssh.socket"
    run "sudo systemctl disable ssh.socket"
    ok "Disabled ssh.socket"
    needs_restart=1
  else
    note "ssh.socket not enabled"
  fi

  # Add YubiKey SSH public key to authorized_keys
  step "Adding YubiKey SSH public key to authorized_keys"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if [[ -f "$HOME/.ssh/id_gpg_yubikey.pub" ]]; then
    if ! grep -qF "$(cat "$HOME/.ssh/id_gpg_yubikey.pub")" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
      cat "$HOME/.ssh/id_gpg_yubikey.pub" >> "$HOME/.ssh/authorized_keys"
      chmod 600 "$HOME/.ssh/authorized_keys"
      ok "Added YubiKey SSH public key to authorized_keys"
    else
      note "YubiKey SSH key already in authorized_keys"
    fi
  else
    warn "YubiKey SSH public key not found; run GPG setup first"
  fi

  # Enable SSH service if not already
  step "Enabling SSH service"
  if systemctl is-enabled ssh >/dev/null 2>&1 || systemctl is-enabled sshd >/dev/null 2>&1; then
    note "SSH service enabled"
  else
    run "sudo systemctl enable ssh || sudo systemctl enable sshd"
    ok "Enabled SSH service"
  fi

  # Start or restart SSH service
  if systemctl is-active ssh >/dev/null 2>&1 || systemctl is-active sshd >/dev/null 2>&1; then
    note "SSH service running"
    if (( needs_restart )); then
      step "Restarting SSH due to config changes"
      run "sudo systemctl restart ssh || sudo systemctl restart sshd"
      ok "Restarted SSH service"
    fi
  else
    step "Starting SSH service"
    run "sudo systemctl start ssh || sudo systemctl start sshd"
    ok "Started SSH service"
  fi

  # Verify listening on port 40822
  step "Verifying SSH is listening on port 40822"
  if sudo ss -tlnp 2>/dev/null | grep -q ":40822"; then
    ok "SSH server listening on port 40822"
  else
    warn "SSH may not be listening on port 40822; check configuration"
  fi

  setup_fail2ban
}

setup_fail2ban() {
  section "Configure fail2ban"

  if (( NO_SUDO )); then
    warn "Skipping fail2ban setup (--no-sudo)"
    return
  fi

  local os_type
  os_type="$(detect_os)"
  local src="$DOTFILES_DIR/fail2ban/jail.local"

  if [[ ! -f "$src" ]]; then
    warn "fail2ban jail config not found at $src; skipping"
    return
  fi

  if [[ "$os_type" == "macOS" ]]; then
    # macOS: install via Homebrew, manage with brew services
    if ! have fail2ban-client; then
      if have brew; then
        step "Installing fail2ban via Homebrew"
        brew install fail2ban
      else
        warn "Homebrew not found; cannot install fail2ban"
        return
      fi
    fi

    local brew_prefix
    brew_prefix="$(brew --prefix)"
    local dst="$brew_prefix/etc/fail2ban/jail.local"
    mkdir -p "$brew_prefix/etc/fail2ban"

    if [[ -f "$dst" ]] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      note "fail2ban jail.local already up to date"
    else
      step "Deploying fail2ban jail.local"
      cp "$src" "$dst"
      ok "Copied $src -> $dst"
    fi

    step "Enabling fail2ban via brew services"
    sudo brew services start fail2ban 2>/dev/null || sudo brew services restart fail2ban
    ok "fail2ban configured (macOS)"
  else
    # Linux: install via apt, manage with systemctl
    if ! have fail2ban-client; then
      if have_apt; then
        step "Installing fail2ban"
        run "sudo apt install -y fail2ban"
      else
        warn "fail2ban not found and no apt available; skipping"
        return
      fi
    fi

    local dst="/etc/fail2ban/jail.local"

    if [[ -f "$dst" ]] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      note "fail2ban jail.local already up to date"
    else
      step "Deploying fail2ban jail.local"
      run "sudo cp \"$src\" \"$dst\""
      ok "Copied $src -> $dst"
    fi

    step "Enabling and restarting fail2ban"
    run "sudo systemctl enable fail2ban"
    run "sudo systemctl restart fail2ban"
    ok "fail2ban configured (Linux)"
  fi
}
