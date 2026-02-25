#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Flatpak apps"
  if ! have flatpak; then
    note "Flatpak not installed; skipping"
    exit 0
  fi

  # Ensure Flathub is configured
  if ! flatpak remote-list | grep -q flathub; then
    run "sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
    ok "Added Flathub repository"
  else
    note "Flathub already configured"
  fi

  # Update all Flatpak apps
  if (( FAST )); then
    note "FAST: skipping Flatpak update"
  else
    run "sudo flatpak update -y || true"
    ok "Flatpak apps updated"
  fi

  # Verify expected apps are installed
  expected_apps=(
    "md.obsidian.Obsidian:Obsidian"
    "com.discordapp.Discord:Discord"
    "com.valvesoftware.Steam:Steam"
    "com.google.Chrome:Google Chrome"
    "org.telegram.desktop:Telegram"
    "com.spotify.Client:Spotify"
    "com.slack.Slack:Slack"
  )

  installed_count=0
  missing_count=0
  for app in "${expected_apps[@]}"; do
    app_id="${app%%:*}"
    app_name="${app#*:}"
    if flatpak list --app | grep -q "$app_id"; then
      note "$app_name installed"
      installed_count=$((installed_count + 1))
    else
      if (( VERBOSE > 0 )); then
        warn "$app_name not found"
      fi
      missing_count=$((missing_count + 1))
    fi
  done

  if (( missing_count > 0 )); then
    warn "$missing_count apps missing (run ubuntu-install.sh to install)"
  fi
  ok "Flatpak: $installed_count/${#expected_apps[@]} apps present"
}

main "$@"
