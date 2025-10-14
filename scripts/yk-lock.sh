#!/usr/bin/env bash
set -euo pipefail

echo "🔒 Locking YubiKey usage (clear PIN cache + restart agent)…"
# Make sure agent is pointed at the current TTY (helps pinentry)
export GPG_TTY="$(tty)" || true
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true

# Kill scdaemon first so the card is fully released
gpgconf --kill scdaemon >/dev/null 2>&1 || true
# Restart gpg-agent (this clears ssh+gpg caches)
gpgconf --kill gpg-agent  >/dev/null 2>&1 || true
gpgconf --launch gpg-agent >/dev/null 2>&1 || true

# Also ask the SSH layer to forget any loaded identities (harmless with gpg-agent)
ssh-add -D >/dev/null 2>&1 || true

echo "✅ Locked. Next SSH/Git use will require the card + PIN."
echo "   Tip: run 'yk-status' or 'yk-status <host>' to verify."
