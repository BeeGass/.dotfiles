#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  # Alias for refresh.sh compatibility
  DOT="$DOTFILES_DIR"
  LOCAL_BIN="$HOME/.local/bin"
  DO_OMP="${DO_OMP:-1}"

  [[ $DO_OMP -eq 1 ]] || { note "OMP disabled via flag"; exit 0; }
  section "Oh-My-Posh + config"
  if [[ "$OS_NAME" == "macOS" ]] && have brew; then
    run "brew update"
    run "brew upgrade jandedobbeleer/oh-my-posh/oh-my-posh || brew upgrade oh-my-posh || true"
  elif have apt; then
    run "curl -s https://ohmyposh.dev/install.sh | bash -s -- -d \"$LOCAL_BIN\""
  else
    run "curl -s https://ohmyposh.dev/install.sh | bash -s -- -d \"$LOCAL_BIN\""
  fi
  # Link config if repo has it
  if [[ -f "$DOT/oh-my-posh/config.json" ]]; then
    run "mkdir -p \"$HOME/.config/oh-my-posh\""
    run "ln -sfn \"$DOT/oh-my-posh/config.json\" \"$HOME/.config/oh-my-posh/config.json\""
    ok "Linked OMP config"
  else
    warn "No repo OMP config found; skipping link"
  fi
}

main "$@"
