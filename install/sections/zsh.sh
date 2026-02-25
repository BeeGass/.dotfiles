#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Zsh plugins"
  # Prefer package manager upgrades where available
  if [[ "$OS_NAME" == "macOS" ]] && have brew; then
    run "brew upgrade zsh-autosuggestions zsh-syntax-highlighting || true"
  elif have apt; then
    run "sudo apt update -y || true"
    run "sudo apt install -y zsh-autosuggestions zsh-syntax-highlighting || true"
  fi
  # Ensure git-based clones exist (covers Termux/others)
  plugroot="$HOME/.zsh/plugins"
  run "mkdir -p \"$plugroot\""
  [[ -d "$plugroot/zsh-autosuggestions" ]] || run "git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \"$plugroot/zsh-autosuggestions\""
  [[ -d "$plugroot/zsh-syntax-highlighting" ]] || run "git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \"$plugroot/zsh-syntax-highlighting\""
  # Ensure sourcing lines in ~/.zshrc (harmless if already present)
  append_once "$HOME/.zshrc" "[[ -r ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  append_once "$HOME/.zshrc" "[[ -r ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  ok "Zsh plugins ready"
}

main "$@"
