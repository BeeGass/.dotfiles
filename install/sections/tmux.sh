#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "tmux + plugins"

  # Check/update tmux itself
  if ! have tmux; then
    warn "tmux not installed"
    if [[ "$OS_NAME" == "macOS" ]] && have brew; then
      note "Install with: brew install tmux"
    elif have_apt; then
      note "Install with: sudo apt install -y tmux"
    fi
    exit 0
  fi

  # Update tmux if possible
  if (( ! FAST )); then
    if [[ "$OS_NAME" == "macOS" ]] && have brew; then
      run "brew upgrade tmux || true"
    elif have_apt; then
      run "sudo apt-get update -y && sudo apt-get install -y --only-upgrade tmux || true"
    fi
  fi

  tmux_version=$(tmux -V 2>/dev/null || echo "unknown")
  ok "tmux present: $tmux_version"

  # Handle TPM (Tmux Plugin Manager)
  TPM="$HOME/.tmux/plugins/tpm"
  if [[ -d "$TPM" ]]; then
    run "\"$TPM/bin/install_plugins\" || true"
    (( FAST )) || run "\"$TPM/bin/update_plugins\" all || true"
    ok "TPM plugins refreshed"
  else
    note "TPM not found; skipping plugin updates"
  fi
}

main "$@"
