#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Codex CLI"

  if have codex; then
    note "Codex CLI installed"
    version=$(codex --version 2>/dev/null || echo "unknown")
    ok "Codex CLI present: $version"
  else
    if have npm; then
      step "Installing Codex CLI via npm"
      run "npm install -g @openai/codex"
    else
      warn "npm not found; cannot install Codex CLI"
      note "Install Node.js first, then: npm install -g @openai/codex"
    fi
  fi
}

main "$@"
