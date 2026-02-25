#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Legacy cleanup"
  if (( NO_SUDO )); then
    warn "Skipping legacy cleanup (--no-sudo)"
    exit 0
  fi

  # Clean up Microsoft repo if it exists (no longer needed)
  if [[ "$OS_NAME" == "Linux" ]] && have_apt; then
    local ms_keyring="/etc/apt/trusted.gpg.d/microsoft.gpg"
    local ms_sourcelist="/etc/apt/sources.list.d/microsoft-prod.list"
    local removed=0

    if [[ -f "$ms_keyring" ]]; then
      note "Removing Microsoft GPG key"
      run "sudo rm -f \"$ms_keyring\""
      ok "Removed $ms_keyring"
      removed=1
    fi

    if [[ -f "$ms_sourcelist" ]]; then
      note "Removing Microsoft sources list"
      run "sudo rm -f \"$ms_sourcelist\""
      ok "Removed $ms_sourcelist"
      removed=1
    fi

    # Nuke any stray packages.microsoft.com lines
    local ms_hits
    ms_hits="$(grep -R "packages.microsoft.com" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)"
    if [[ -n "$ms_hits" ]]; then
      note "Stripping packages.microsoft.com from apt sources"
      while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        run "sudo sed -i '/packages.microsoft.com/d' \"$f\""
        removed=1
      done < <(grep -Rl "packages.microsoft.com" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)
    fi

    if (( removed )); then
      note "Refreshing package lists after cleanup"
      run "sudo apt-get update -y || sudo apt update -y"
      ok "Microsoft repo cleanup complete"
    else
      note "No legacy Microsoft repo configuration found"
    fi
  else
    note "No apt-based cleanup needed on this platform"
  fi
}

main "$@"
