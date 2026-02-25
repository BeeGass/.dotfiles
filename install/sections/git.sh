#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Git credential helper"

  current_helper="$(git config --global credential.helper || echo "none")"

  if [[ "$OS_NAME" == "macOS" ]]; then
    if [[ "$current_helper" == "osxkeychain" ]]; then
      ok "Git credential helper: osxkeychain (correct for macOS)"
    else
      warn "Git credential helper is '$current_helper', should be 'osxkeychain' for macOS"
      note "Fix with: git config --global credential.helper osxkeychain"
    fi
  elif [[ "$OS_NAME" == "Linux" ]]; then
    if [[ "$current_helper" == *"libsecret"* ]]; then
      ok "Git credential helper: libsecret (secure)"
    elif [[ "$current_helper" == "store" ]]; then
      ok "Git credential helper: store (plaintext fallback)"
      note "Consider using libsecret for encrypted storage"
    elif [[ "$current_helper" == "osxkeychain" ]]; then
      warn "Git credential helper is 'osxkeychain' (macOS only, will not work on Linux)"
      note "Fix with: git config --global credential.helper store"
    else
      warn "Git credential helper is '$current_helper'"
      note "Consider setting to 'store' or 'libsecret'"
    fi
  else
    note "Unknown OS, credential helper: $current_helper"
  fi
}

main "$@"
