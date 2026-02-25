#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  # Alias for refresh.sh compatibility
  DOT="$DOTFILES_DIR"
  LOCAL_BIN="$HOME/.local/bin"

  section "PATH & loader stubs"
  mkdir -p "$LOCAL_BIN"
  if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    export PATH="$LOCAL_BIN:$PATH"; ok "Temporarily added $LOCAL_BIN to PATH"
  else
    note "PATH already includes $LOCAL_BIN"
  fi

  # Link dotfiles scripts to PATH
  if [[ -f "$DOT/install/install.sh" ]]; then
    run "ln -sf \"$DOT/install/install.sh\" \"$LOCAL_BIN/dots-install\""
    ok "Linked dots-install"
  fi
  if [[ -f "$DOT/install/refresh.sh" ]]; then
    run "ln -sf \"$DOT/install/refresh.sh\" \"$LOCAL_BIN/dots-refresh\""
    ok "Linked dots-refresh"
  fi
  if [[ -f "$DOT/install/bootstrap.sh" ]]; then
    run "ln -sf \"$DOT/install/bootstrap.sh\" \"$LOCAL_BIN/dots-bootstrap\""
    ok "Linked dots-bootstrap"
  fi
  if [[ -f "$DOT/install/clean.sh" ]]; then
    run "ln -sf \"$DOT/install/clean.sh\" \"$LOCAL_BIN/dots-clean\""
    ok "Linked dots-clean"
  fi

  # Ensure .zshrc loader stub unless ~/.zshrc is a symlink
  touch "$HOME/.zshrc"
  if [[ -L "$HOME/.zshrc" ]]; then
    note "~/.zshrc is a symlink; not touching"
  else
    local START="# >>> BeeGass dotfiles >>>"
    local END="# <<< BeeGass dotfiles <<<"
    if ! grep -Fq "$START" "$HOME/.zshrc"; then
      backup_file "$HOME/.zshrc"
      run "printf '\n%s\n%s\n%s\n' '$START' 'if [ -f \"$DOT/zsh/zshrc\" ]; then source \"$DOT/zsh/zshrc\"; fi' '$END' >> \"$HOME/.zshrc\""
      ok "Appended loader stub to ~/.zshrc"
    else
      note "Loader stub already present"
    fi
  fi
}

main "$@"
