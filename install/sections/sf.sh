#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  # Alias for refresh.sh compatibility
  LOCAL_BIN="$HOME/.local/bin"

  section "SF Compute CLI"
  if have sf; then
    ok "sf CLI present"
    exit 0
  fi

  tmp="$(mktemp -d)"
  note "Installing sf CLI to $LOCAL_BIN"
  run "mkdir -p \"$LOCAL_BIN\""
  if run "curl -fsSL -o \"$tmp/sf.zip\" https://github.com/sfcompute/cli/releases/latest/download/sf-x86_64-unknown-linux-gnu.zip" &&
     run "unzip -o \"$tmp/sf.zip\" -d \"$tmp/dist\" >/dev/null 2>&1" &&
     [[ -f "$tmp/dist/sf-x86_64-unknown-linux-gnu" ]]; then
    run "mv \"$tmp/dist/sf-x86_64-unknown-linux-gnu\" \"$LOCAL_BIN/sf\""
    run "chmod +x \"$LOCAL_BIN/sf\""
    ok "Installed sf CLI"
  else
    warn "Failed to install sf CLI"
  fi
  run "rm -rf \"$tmp\""
}

main "$@"
