#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Gemini CLI"

  if have gemini; then
    note "Gemini CLI installed"
    version=$(gemini --version 2>/dev/null || echo "unknown")
    ok "Gemini CLI present: $version"
  else
    warn "Gemini CLI not found"
    if have npm; then
      note "Install with: npm install -g @google/gemini-cli@latest"
    else
      warn "npm not found; cannot install Gemini CLI"
    fi
  fi
}

main "$@"
