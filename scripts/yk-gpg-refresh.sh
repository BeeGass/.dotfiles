#!/usr/bin/env bash
# Refresh GPG agent and update configuration for current YubiKey
set -euo pipefail

# Determine signing key: use S_KEYID if set, otherwise detect from card
if [[ -z "${S_KEYID:-}" ]]; then
    SIGN_KEY=$(gpg --card-status 2>&1 | grep "Signature key" | grep -o '[0-9A-F]\{40\}' | head -1)
    [[ -z "$SIGN_KEY" ]] && { echo "Error: Could not detect signing key from card"; exit 1; }
    S_KEYID="0x${SIGN_KEY: -16}"
fi

# Set GPG_TTY and restart agent
export GPG_TTY=$(tty)
gpgconf --kill gpg-agent

# Regenerate private key stubs for current card
rm -f ~/.gnupg/private-keys-v1.d/*.key 2>/dev/null || true

gpgconf --launch gpg-agent
gpg-connect-agent updatestartuptty /bye >/dev/null

# Force GPG to recreate stubs for current card
gpg --card-status >/dev/null 2>&1

# Update Git configuration
CURRENT_KEY=$(git config --global user.signingkey || echo "")
[[ "$CURRENT_KEY" != "$S_KEYID" ]] && git config --global user.signingkey "$S_KEYID"
[[ "$(git config --global commit.gpgsign || echo false)" != "true" ]] && git config --global commit.gpgsign true

# Add SSH authentication keygrip to sshcontrol if present
AUTH_KEYGRIP=$(gpg --list-secret-keys --with-keygrip 2>/dev/null | awk '/Keygrip/{g=$3} /ssb>.*\[A\]/{if(g){print g; exit}}')
if [[ -n "$AUTH_KEYGRIP" ]] && ! grep -q "$AUTH_KEYGRIP" ~/.gnupg/sshcontrol 2>/dev/null; then
    echo "$AUTH_KEYGRIP" >> ~/.gnupg/sshcontrol
fi

# Final restart
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

echo "GPG agent refreshed. Signing key: $S_KEYID"
echo ""
echo "Testing YubiKey unlock (will prompt for PIN)..."
echo "test" | gpg --clearsign --default-key "$S_KEYID" >/dev/null && echo "Success: YubiKey unlocked and working"
