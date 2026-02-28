#!/usr/bin/env bash
# Refresh GPG agent and update configuration for current YubiKey
# Works on both Linux and macOS
set -euo pipefail

# Logging helpers
warn() { printf "[warn] %s\n" "$*" >&2; }
info() { printf "[info] %s\n" "$*"; }

# Determine signing key: use S_KEYID if set, otherwise detect from card
if [[ -z "${S_KEYID:-}" ]]; then
  SIGN_KEY=$(gpg --card-status 2>&1 | grep "Signature key" | grep -o '[0-9A-F]\{40\}' | head -1)
  if [[ -z "$SIGN_KEY" ]]; then
    warn "Could not detect signing key from card - is YubiKey inserted?"
    exit 1
  fi
  S_KEYID="0x${SIGN_KEY: -16}"
fi

# Set GPG_TTY (with fallback for non-TTY contexts like macOS Finder launches)
if ! GPG_TTY="$(tty 2>/dev/null)"; then
  warn "No TTY detected (running outside terminal?), using /dev/tty fallback"
  GPG_TTY="/dev/tty"
fi
export GPG_TTY

# Kill scdaemon first to fully release the card (important on macOS)
if ! gpgconf --kill scdaemon 2>/dev/null; then
  warn "scdaemon not running or kill failed (may be normal)"
fi
gpgconf --kill gpg-agent

# Regenerate private key stubs for current card
info "Removing old key stubs..."
if ! rm -f ~/.gnupg/private-keys-v1.d/*.key 2>/dev/null; then
  warn "No existing key stubs to remove (may be normal on first run)"
fi

info "Launching gpg-agent..."
gpgconf --launch gpg-agent
if ! gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1; then
  warn "Failed to update startup TTY in gpg-agent"
fi

# Force GPG to recreate stubs for current card
info "Detecting card and recreating key stubs..."
if ! gpg --card-status >/dev/null 2>&1; then
  warn "gpg --card-status failed - card may not be properly detected"
fi

# Update Git configuration
info "Updating Git signing configuration..."
CURRENT_KEY=$(git config --global user.signingkey 2>/dev/null || echo "")
if [[ "$CURRENT_KEY" != "$S_KEYID" ]]; then
  info "Setting git signing key to $S_KEYID (was: ${CURRENT_KEY:-<unset>})"
  git config --global user.signingkey "$S_KEYID"
fi
if [[ "$(git config --global commit.gpgsign 2>/dev/null || echo false)" != "true" ]]; then
  info "Enabling git commit signing"
  git config --global commit.gpgsign true
fi

# Add SSH authentication keygrip to sshcontrol if present
# Note: [A] line comes before its Keygrip, so we set a flag then capture the next Keygrip
info "Checking SSH authentication keygrip..."
AUTH_KEYGRIP=$(gpg --list-secret-keys --with-keygrip 2>/dev/null | awk '/\[A\]/{found=1; next} found && /Keygrip/{print $3; exit}')
if [[ -z "$AUTH_KEYGRIP" ]]; then
  warn "No authentication subkey [A] found in GPG keys"
elif ! grep -q "$AUTH_KEYGRIP" ~/.gnupg/sshcontrol 2>/dev/null; then
  info "Adding auth keygrip to sshcontrol: $AUTH_KEYGRIP"
  echo "$AUTH_KEYGRIP" >>~/.gnupg/sshcontrol
else
  info "Auth keygrip already in sshcontrol"
fi

# Final restart (kill scdaemon too for clean state on macOS)
info "Final agent restart..."
gpgconf --kill scdaemon 2>/dev/null || warn "scdaemon kill failed on final restart"
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

echo ""
echo "GPG agent refreshed. Signing key: $S_KEYID"
echo ""
echo "Testing YubiKey unlock (will prompt for PIN)..."
if echo "test" | gpg --clearsign --default-key "$S_KEYID" >/dev/null 2>&1; then
  echo "Success: YubiKey unlocked and working"
else
  warn "Sign test failed - card may need PIN entry, touch, or may not be present"
  exit 1
fi
