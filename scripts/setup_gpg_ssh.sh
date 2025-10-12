#!/usr/bin/env bash
# ~/.dotfiles/scripts/setup_gpg_ssh.sh
# Fast, idempotent bootstrap for GPG+SSH via gpg-agent.
# Default behavior: import https://github.com/beegass.gpg (public keys),
# ensure pinentry + agent ssh socket, pull smartcard stubs, export SSH pubkey.

set -euo pipefail

# -------- config (can be overridden via env) ---------------------------------
: "${GITHUB_GPG_URL:=https://github.com/beegass.gpg}"
: "${STAMP_DIR:=$HOME/.cache/gpg-setup}"
: "${STAMP_FILE:=$STAMP_DIR/github-beegass.imported}"
: "${SSH_PUB_OUT:=$HOME/.ssh/id_gpg_yubikey.pub}"
: "${QUIET:=1}"          # 1=minimal output, 0=verbose
: "${AUTO_GIT_CONFIG:=0}" # 1 to set git signing key automatically if discoverable

# -------- utils --------------------------------------------------------------
log() { [[ "${QUIET}" = "1" ]] && return 0 || printf "[gpg-ssh] %s\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
err() { echo "ERROR: $*" >&2; exit 1; }

require_bins() {
  local miss=(); for b in gpg gpgconf ssh; do have "$b" || miss+=("$b"); done
  if (( ${#miss[@]} )); then
    echo "Missing tools: ${miss[*]}"
    echo "Install on macOS:  brew install gnupg pinentry-mac"
    echo "Install on Ubuntu: sudo apt install -y gnupg pinentry-curses"
    echo "Install on Termux: pkg install -y gnupg pinentry-curses"
    exit 1
  fi
}

pinentry_path() {
  if [[ "$OSTYPE" == "darwin"* ]] && have pinentry-mac; then command -v pinentry-mac
  elif have pinentry-curses; then command -v pinentry-curses
  elif have pinentry; then command -v pinentry
  else echo ""; fi
}

ensure_dirs() {
  mkdir -p "$STAMP_DIR" "$HOME/.gnupg" "$HOME/.ssh"
  chmod 700 "$HOME/.gnupg" "$HOME/.ssh"
}

write_agent_conf() {
  local conf="$HOME/.gnupg/gpg-agent.conf"
  local pin; pin="$(pinentry_path || true)"
  # Only rewrite if content would change
  local desired="enable-ssh-support
default-cache-ttl 1800
default-cache-ttl-ssh 1800
max-cache-ttl 7200
max-cache-ttl-ssh 7200
${pin:+pinentry-program $pin}"
  if [[ ! -f "$conf" ]] || ! diff -q <(echo "$desired") "$conf" >/dev/null 2>&1; then
    log "writing $conf"
    printf "%s\n" "$desired" > "$conf"
    chmod 600 "$conf"
  fi
}

launch_agent_env() {
  export GPG_TTY="$(tty || echo /dev/tty)"
  gpgconf --launch gpg-agent >/dev/null 2>&1 || true
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  [[ -S "$SSH_AUTH_SOCK" ]] || err "gpg-agent ssh socket not found at $SSH_AUTH_SOCK"
}

ensure_login_snippet() {
  local f="$HOME/.dotfiles/zsh/90-local.zsh"
  mkdir -p "$(dirname "$f")"; touch "$f"; chmod 600 "$f"
  grep -q 'agent-ssh-socket' "$f" 2>/dev/null || cat >>"$f" <<'EOF'

# --- gpg-agent as ssh-agent (managed by setup_gpg_ssh.sh) ---
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
export GPG_TTY="$(tty || echo /dev/tty)"
gpgconf --launch gpg-agent >/dev/null 2>&1 || true
# -------------------------------------------------------------
EOF
}

import_from_github() {
  [[ -f "$STAMP_FILE" ]] && { log "github keys already imported (stamp)"; return; }
  if have curl; then
    log "importing public keys from $GITHUB_GPG_URL"
    # Import is idempotent; stamp only on success
    curl -fsSL "$GITHUB_GPG_URL" | gpg --import || return 0
    date +%s > "$STAMP_FILE"
  else
    log "curl not found; skipping GitHub key import"
  fi
}

touch_smartcard() {
  # Force creation of stubs for card-resident keys
  gpg --card-status >/dev/null 2>&1 || true
}

find_auth_fpr() {
  # Returns first auth-capable subkey fingerprint on stdout (if any), else empty.
  # Parse --list-keys --with-colons: 'sub' line with 'a' in cap field; next 'fpr' line is fingerprint.
  gpg --list-keys --with-colons 2>/dev/null \
    | awk -F: '
      $1=="sub" && $12 ~ /a/ { want=1; next }
      want && $1=="fpr" { print $10; exit }'
}

export_ssh_pubkey() {
  local fpr="$1"
  [[ -z "$fpr" ]] && { log "no auth subkey fingerprint found; skipping export"; return; }
  if [[ -f "$SSH_PUB_OUT" ]]; then
    # Only regenerate if content differs
    if ! gpg --export-ssh-key "$fpr" | diff -q - "$SSH_PUB_OUT" >/dev/null 2>&1; then
      log "updating $SSH_PUB_OUT"
      gpg --export-ssh-key "$fpr" > "$SSH_PUB_OUT"
      chmod 644 "$SSH_PUB_OUT"
    else
      log "ssh pubkey already up-to-date"
    fi
  else
    log "writing $SSH_PUB_OUT"
    gpg --export-ssh-key "$fpr" > "$SSH_PUB_OUT"
    chmod 644 "$SSH_PUB_OUT"
  fi
}

maybe_configure_git_signing() {
  [[ "$AUTO_GIT_CONFIG" = "1" ]] || return 0
  have git || return 0
  # Prefer a signing-capable primary/subkey in your keyring whose uid matches git user.email, else first key
  local email; email="$(git config --global user.email || true)"
  local key=""
  if [[ -n "$email" ]]; then
    key="$(gpg --list-keys --with-colons 2>/dev/null | awk -F: -v e="$email" '
      $1=="uid" && tolower($10) ~ tolower(e) { hit=1 }
      hit && ($1=="pub" || $1=="sub") && $12 ~ /s/ { print $5; exit }')"
  fi
  [[ -z "$key" ]] && key="$(gpg --list-keys --with-colons 2>/dev/null | awk -F: '$1=="pub"{print $5; exit}')"
  [[ -z "$key" ]] && return 0
  git config --global user.signingkey "$key"
  git config --global gpg.program gpg
  git config --global commit.gpgsign true
  log "git signing configured to $key"
}

verify_agent_keys() {
  # Trigger agent to enumerate keys; tolerate empty
  ssh-add -L >/dev/null 2>&1 || true
}

main() {
  require_bins
  ensure_dirs
  write_agent_conf
  launch_agent_env
  ensure_login_snippet
  import_from_github
  touch_smartcard
  local auth_fpr; auth_fpr="$(find_auth_fpr || true)"
  export_ssh_pubkey "$auth_fpr"
  maybe_configure_git_signing
  verify_agent_keys
  [[ "${QUIET}" = "1" ]] || {
    echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
    echo "Auth subkey: ${auth_fpr:-<none found>}"
    [[ -f "$SSH_PUB_OUT" ]] && echo "SSH pubkey: $SSH_PUB_OUT"
  }
}

# Flags:
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
