#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Font cache"
  fonts_dir="$HOME/.local/share/fonts"
  if [[ ! -d "$fonts_dir" ]] || ! find "$fonts_dir" -maxdepth 1 -name '*Nerd*' -print -quit 2>/dev/null | grep -q .; then
    note "No Nerd Fonts found in $fonts_dir; skipping"
    exit 0
  fi
  run "fc-cache -f >/dev/null 2>&1"
  ok "Font cache rebuilt"
}

main "$@"
