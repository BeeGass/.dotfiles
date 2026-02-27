#!/bin/bash
set -euo pipefail

# Dotfiles bootstrap script
# Usage: curl -fsLS https://raw.githubusercontent.com/BeeGass/.dotfiles/main/bootstrap.sh | bash

# Install git if missing
if ! command -v git >/dev/null 2>&1; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    xcode-select --install 2>/dev/null || true
    until command -v git >/dev/null 2>&1; do sleep 5; done
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y git
  elif command -v pkg >/dev/null 2>&1; then
    pkg install -y git
  fi
fi

# Install chezmoi and apply dotfiles in one step
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply BeeGass/.dotfiles
