#!/usr/bin/env bash
set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "  ✅ %s\n" "$*"; }
warn() { printf "  ⚠️  %s\n" "$*"; }
err()  { printf "  ❌ %s\n" "$*"; }

# Always point to gpg-agent’s SSH socket for the check (doesn't change your shell)
GPG_SSH_SOCK="$(gpgconf --list-dirs agent-ssh-socket 2>/dev/null || true)"
CUR_SSH_SOCK="${SSH_AUTH_SOCK:-}"

bold "--- Agent sockets ---"
if [[ -n "$CUR_SSH_SOCK" && -S "$CUR_SSH_SOCK" ]]; then
  echo "SSH_AUTH_SOCK: $CUR_SSH_SOCK"
else
  warn "SSH_AUTH_SOCK not set or not a socket."
fi
if [[ -n "$GPG_SSH_SOCK" && -S "$GPG_SSH_SOCK" ]]; then
  echo "GPG agent SSH socket: $GPG_SSH_SOCK"
else
  err "gpg-agent SSH socket not found (is enable-ssh-support set?)"
fi

if [[ "$CUR_SSH_SOCK" == "$GPG_SSH_SOCK" ]]; then
  ok "Using gpg-agent as SSH agent"
else
  warn "Your shell may not be using gpg-agent (try: export SSH_AUTH_SOCK=\"$(gpgconf --list-dirs agent-ssh-socket)\")"
fi

bold "--- YubiKey / card ---"
if serial=$(gpg-connect-agent 'scd serialno' /bye 2>/dev/null | awk '/^S/ {print $2}'); then
  ok "Card present (serial: $serial)"
else
  warn "No card detected by scdaemon"
fi

bold "--- Keys exposed to SSH (ssh-add -L) ---"
if out=$(ssh-add -L 2>&1); then
  echo "$out" | sed 's/^/  /'
  count=$(ssh-add -L | wc -l | tr -d ' ')
  ok "$count public key(s) advertised"
else
  warn "$out"
fi

bold "--- gpg-agent ssh list (keygrips) ---"
if keyinfo=$(gpg-connect-agent 'keyinfo --ssh-list' /bye 2>/dev/null); then
  echo "$keyinfo" | sed 's/^/  /'
else
  warn "No ssh-list from gpg-agent"
fi

if [[ -f "$HOME/.gnupg/sshcontrol" ]]; then
  bold "--- ~/.gnupg/sshcontrol (allowed keygrips) ---"
  grep -E '^[0-9A-F]{40}' "$HOME/.gnupg/sshcontrol" | sed 's/^/  /' || true
fi

# Optional: quick non-interactive test if you pass a host (e.g., yk-status Tensor)
if [[ "${1-}" != "" ]]; then
  bold "--- BatchMode test: $1 ---"
  if ssh -o BatchMode=yes "$1" true 2>/dev/null; then
    ok "Batch SSH to '$1' works (PIN likely cached)"
  else
    warn "Batch SSH to '$1' failed (no PIN cached or wrong authorized_keys)"
  fi
fi

bold "--- Tips ---"
echo "  • Update pinentry TTY in this shell:  export GPG_TTY=\$(tty); gpg-connect-agent updatestartuptty /bye"
echo "  • Hard lock (clear PIN cache):       yk-lock"
