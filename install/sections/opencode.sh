#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "OpenCode CLI"

  if [[ -d "$HOME/.opencode" ]] || have opencode; then
    note "OpenCode CLI installed"
    if have opencode; then
      version=$(opencode --version 2>/dev/null || echo "unknown")
      ok "OpenCode CLI present: $version"
    else
      ok "OpenCode CLI present (in ~/.opencode)"
    fi
  else
    warn "OpenCode CLI not found"
    note "Install with: curl -fsSL https://opencode.ai/install | bash"
  fi
}

main "$@"
