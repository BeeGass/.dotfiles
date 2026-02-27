#!/usr/bin/env bash
# ~/.dotfiles/scripts/setup_gpg_ssh.sh
# Idempotent GPG+SSH bootstrap.
# Config files (gpg-agent.conf, gpg.conf, dirmngr.conf) are deployed by chezmoi.
# This script handles operations that require a YubiKey physically inserted:
# - Imports GPG public keys from GitHub
# - Probes smartcard and loads key stubs
# - Exports SSH public key from auth subkey
# - Verifies gpg-agent SSH socket is working
# - Configures macOS sshd port (40822) if needed
# - TTY-aware colored output; no emojis

set -euo pipefail

# -------- config (overridable via env) ----------------------------------------
: "${GITHUB_GPG_URL:=https://github.com/beegass.gpg}"
: "${STAMP_DIR:=$HOME/.cache/gpg-setup}"
: "${STAMP_FILE:=$STAMP_DIR/github-beegass.imported}"
: "${SSH_PUB_OUT:=$HOME/.ssh/id_gpg_yubikey.pub}"
: "${QUIET:=1}"             # 1=minimal output, 0=verbose
: "${AUTO_GIT_CONFIG:=0}"   # 1 to set git signing key automatically if discoverable

# -------- colors / log --------------------------------------------------------
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
log()     { [[ "${QUIET}" = "1" ]] && return 0 || note "$*"; }

# -------- utils ---------------------------------------------------------------
have(){ command -v "$1" >/dev/null 2>&1; }

is_raspberry_pi() {
  [[ -f /proc/cpuinfo ]] && grep -qi "Raspberry Pi" /proc/cpuinfo && return 0
  [[ -f /sys/firmware/devicetree/base/model ]] && grep -qi "Raspberry Pi" /sys/firmware/devicetree/base/model 2>/dev/null && return 0
  return 1
}

detect_os() {
  if [[ -n "${TERMUX_VERSION-}" ]] || [[ "${PREFIX-}" == *"com.termux"* ]] || [[ "$(uname -o 2>/dev/null || true)" == "Android" ]]; then
    echo "Termux"
  elif [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
    echo "macOS"
  elif is_raspberry_pi; then
    echo "RaspberryPi"
  else
    echo "Linux"
  fi
}

require_bins() {
  local miss=(); for b in gpg gpgconf ssh awk sed; do have "$b" || miss+=("$b"); done
  if (( ${#miss[@]} )); then
    err "Missing tools: ${miss[*]}
  Install on macOS     : brew install gnupg pinentry-mac
  Install on Ubuntu    : sudo apt install -y gnupg pinentry-curses pinentry-gnome3
  Install on RaspberryPi: sudo apt install -y gnupg pinentry-curses
  Install on Termux    : pkg install -y gnupg pinentry-curses"
  fi
}

ensure_dirs() {
  section "Preparing ~/.gnupg and ~/.ssh"
  mkdir -p "$STAMP_DIR" "$HOME/.gnupg" "$HOME/.ssh" "$HOME/.ssh/config.d"
  chmod 700 "$HOME/.gnupg" "$HOME/.ssh"
  [[ -d "$HOME/.gnupg/private-keys-v1.d" ]] && chmod 700 "$HOME/.gnupg/private-keys-v1.d" || true
  ok "Directories exist and are secure"
}


verify_configs() {
  section "Verifying GnuPG configs (deployed by chezmoi)"
  local reload_needed=0

  if [[ -f "$HOME/.gnupg/gpg-agent.conf" ]]; then
    ok "gpg-agent.conf present"
  else
    warn "gpg-agent.conf missing -- run 'chezmoi apply' first"
    reload_needed=1
  fi

  if [[ -f "$HOME/.gnupg/gpg.conf" ]]; then
    ok "gpg.conf present"
  else
    warn "gpg.conf missing -- run 'chezmoi apply' first"
  fi

  if [[ -f "$HOME/.gnupg/dirmngr.conf" ]]; then
    ok "dirmngr.conf present"
  else
    warn "dirmngr.conf missing -- run 'chezmoi apply' first"
  fi

  step "Reloading gpg-agent"
  gpgconf --kill gpg-agent || true
}

launch_agent_env() {
  section "Launching gpg-agent and wiring SSH"
  export GPG_TTY="$(tty || echo /dev/tty)"
  gpgconf --launch gpg-agent >/dev/null 2>&1 || true
  local sock; sock="$(gpgconf --list-dirs agent-ssh-socket)"
  export SSH_AUTH_SOCK="$sock"
  [[ -S "$SSH_AUTH_SOCK" ]] || err "gpg-agent SSH socket not found at $SSH_AUTH_SOCK"
  ok "SSH agent socket: $SSH_AUTH_SOCK"
}

ensure_login_snippet() {
  section "Verifying zsh GPG/SSH snippet"
  local f="$HOME/.dotfiles/zsh/90-local.zsh"
  if [[ -f "$f" ]] && grep -q "gpgconf" "$f" 2>/dev/null; then
    ok "GPG/SSH wiring present in ${f/#$HOME/~} (deployed by chezmoi)"
  else
    warn "GPG/SSH wiring missing from ${f/#$HOME/~} -- run 'chezmoi apply' first"
  fi
}

ensure_ssh_identityagent() {
  section "Verifying ssh IdentityAgent"
  local drop="$HOME/.ssh/config.d/10-gpg-agent.conf"
  if [[ -f "$drop" ]]; then
    ok "IdentityAgent drop-in present (deployed by chezmoi)"
  else
    warn "IdentityAgent drop-in missing at ${drop/#$HOME/~}"
    warn "Run 'chezmoi apply' to create it, or generating fallback now"
    mkdir -p "$HOME/.ssh/config.d"
    local sock; sock="$(gpgconf --list-dirs agent-ssh-socket)"
    printf "# GPG agent as SSH agent -- generated by setup_gpg_ssh.sh fallback\nHost *\n  IdentityAgent %s\n" "$sock" > "$drop"
    chmod 600 "$drop"
    ok "Wrote fallback ${drop/#$HOME/~}"
  fi

  local sshconf="$HOME/.ssh/config"
  if [[ -f "$sshconf" ]]; then
    if grep -qE '^\s*Include\s+~/.ssh/config\.d/\*\.conf' "$sshconf"; then
      ok "~/.ssh/config includes config.d"
    else
      warn "~/.ssh/config missing Include directive for config.d"
    fi
  fi
}

import_from_github() {
  section "Importing public keys (GitHub)"
  [[ -z "${GITHUB_GPG_URL}" ]] && { note "Skipping GitHub import (disabled)"; return; }
  [[ -f "$STAMP_FILE" ]] && { note "GitHub keys already imported (stamp)"; return; }
  if have curl; then
    step "Fetching $GITHUB_GPG_URL"
    if curl -fsSL "$GITHUB_GPG_URL" | gpg --import; then
      date +%s > "$STAMP_FILE"
      ok "Imported public keys"
    else
      warn "Import failed (continuing)"
    fi
  else
    warn "curl not found; skipping GitHub key import"
  fi
}

touch_smartcard() {
  section "Probing smartcard"
  gpg --card-status >/dev/null 2>&1 || true
  ok "Card stubs (if any) loaded"
}

find_auth_fpr() {
  gpg --list-keys --with-colons 2>/dev/null \
    | awk -F: '
      $1=="sub" && $12 ~ /a/ { want=1; next }
      want && $1=="fpr" { print $10; exit }'
}

export_ssh_pubkey() {
  section "Exporting SSH public key from auth subkey"
  local fpr="$1"
  [[ -z "$fpr" ]] && { warn "No auth-capable subkey found; skipping export"; return; }
  if [[ -f "$SSH_PUB_OUT" ]]; then
    if ! gpg --export-ssh-key "$fpr" | diff -q - "$SSH_PUB_OUT" >/dev/null 2>&1; then
      gpg --export-ssh-key "$fpr" > "$SSH_PUB_OUT"
      chmod 644 "$SSH_PUB_OUT"
      ok "Updated ${SSH_PUB_OUT/#$HOME/~}"
    else
      note "SSH pubkey already up-to-date"
    fi
  else
    gpg --export-ssh-key "$fpr" > "$SSH_PUB_OUT"
    chmod 644 "$SSH_PUB_OUT"
    ok "Wrote ${SSH_PUB_OUT/#$HOME/~}"
  fi
}

maybe_configure_git_signing() {
  [[ "$AUTO_GIT_CONFIG" = "1" ]] || return 0
  have git || return 0
  section "Configuring Git commit signing"
  local email; email="$(git config --global user.email || true)"
  local key=""
  if [[ -n "$email" ]]; then
    key="$(gpg --list-keys --with-colons 2>/dev/null | awk -F: -v e="$email" '
      $1=="uid" && tolower($10) ~ tolower(e) { hit=1 }
      hit && ($1=="pub" || $1=="sub") && $12 ~ /s/ { print $5; exit }')"
  fi
  [[ -z "$key" ]] && key="$(gpg --list-keys --with-colons 2>/dev/null | awk -F: '$1=="pub"{print $5; exit}')"
  [[ -z "$key" ]] && { warn "No key found to configure Git signing"; return 0; }
  git config --global user.signingkey "$key"
  git config --global gpg.program gpg
  git config --global commit.gpgsign true
  ok "Git signing set to $key"
}

verify_agent_keys() {
  section "Verifying agent enumeration"
  ssh-add -L >/dev/null 2>&1 || true
  ok "Agent enumerated (may be empty if no keys yet)"
}

configure_macos_sshd_port() {
  [[ "$1" != "macOS" ]] && return 0
  section "Configuring macOS sshd port"

  local services="/etc/services"
  local target_port="40822"

  # Check if already configured
  if grep -qE "^ssh[[:space:]]+${target_port}/" "$services" 2>/dev/null; then
    ok "sshd already configured for port $target_port"
    return 0
  fi

  step "Patching $services to use port $target_port for ssh"
  note "This requires sudo access"

  if sudo sed -i '' "s/^ssh[[:space:]]*22\//ssh              ${target_port}\//" "$services"; then
    ok "Updated ssh port in $services"

    step "Reloading sshd to apply changes"
    sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
    sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
    ok "sshd reloaded on port $target_port"
  else
    warn "Failed to patch $services (may need manual intervention)"
  fi
}

# -------- main ----------------------------------------------------------------
main() {
  section "GPG + SSH bootstrap"
  require_bins
  ensure_dirs
  local os; os="$(detect_os)"
  verify_configs
  launch_agent_env
  ensure_login_snippet
  ensure_ssh_identityagent
  configure_macos_sshd_port "$os"
  import_from_github
  touch_smartcard
  local auth_fpr; auth_fpr="$(find_auth_fpr || true)"
  export_ssh_pubkey "$auth_fpr"
  maybe_configure_git_signing
  verify_agent_keys

  [[ "${QUIET}" = "1" ]] || {
    echo
    note "OS: $os"
    note "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
    note "Auth subkey: ${auth_fpr:-<none found>}"
    [[ -f "$SSH_PUB_OUT" ]] && note "SSH pubkey: $SSH_PUB_OUT"
  }
  ok "Done"
}

# -------- flags ----------------------------------------------------------------
#   --verbose     : noisy logs
#   --no-fetch    : skip GitHub key import
#   --regen       : force re-import + re-export
#   --git         : AUTO_GIT_CONFIG=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) QUIET=0 ;;
    --no-fetch) GITHUB_GPG_URL="";;
    --regen) rm -f "$STAMP_FILE" "$SSH_PUB_OUT" ;;
    --git) AUTO_GIT_CONFIG=1 ;;
    *) ;; # ignore unknowns to be startup-safe
  esac; shift
done

main
