#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Snap apps"
  if ! have snap; then
    note "Snap not installed; skipping"
    exit 0
  fi

  # Verify VS Code is installed
  if snap list 2>/dev/null | grep -q "^code "; then
    note "VS Code installed"
    ok "Snap: VS Code present"
  else
    warn "VS Code not found (run ubuntu-install.sh to install)"
  fi
}

main "$@"
