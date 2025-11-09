#!/usr/bin/env bash
# Reset and refresh GPG agent for new/replaced YubiKey
set -euo pipefail

# Set GPG_TTY
export GPG_TTY=$(tty)

# Restart GPG agent
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

# Test signing with S_KEYID from environment
echo "test" | gpg --clearsign --default-key "$S_KEYID" >/dev/null

# Update git signing key if different
CURRENT_KEY=$(git config --global user.signingkey || echo "")
if [[ "$CURRENT_KEY" != "$S_KEYID" ]]; then
    git config --global user.signingkey "$S_KEYID"
fi

# Enable commit signing if not already
if [[ "$(git config --global commit.gpgsign || echo false)" != "true" ]]; then
    git config --global commit.gpgsign true
fi

echo "YubiKey GPG refresh complete. Signing key: $S_KEYID"
