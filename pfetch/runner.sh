#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${TERMUX_VERSION-}" || "${PREFIX-}" == *"com.termux"* || "$(uname -o 2>/dev/null || true)" == "Android" ]]; then
  . "$HOME/.dotfiles/pfetch/termux-pfetch.sh"
else
  . "$HOME/.dotfiles/pfetch/desktop-pfetch.sh"
fi
exec pfetch
