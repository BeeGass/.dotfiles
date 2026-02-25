#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Tailscale"
  if (( NO_SUDO )); then
    warn "Skipping Tailscale (--no-sudo)"
    exit 0
  fi
  if [[ "$OS_NAME" != "Linux" ]] || ! have_apt; then
    note "Non-Ubuntu/apt system; skipping Tailscale enforcement"
    exit 0
  fi

  if have tailscale; then
    ok "Tailscale already installed"
    exit 0
  fi

  # Best-effort mirror of installer; safe to run multiple times
  codename="$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-}")"

  note "Tailscale missing; configuring repo for $codename (best-effort)"
  run "sudo mkdir -p /usr/share/keyrings"
  run "curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null"
  run "curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null"
  run "sudo chmod 0644 /usr/share/keyrings/tailscale-archive-keyring.gpg /etc/apt/sources.list.d/tailscale.list || true"
  run "sudo apt-get update -y || true"
  run "sudo apt-get install -y tailscale tailscale-archive-keyring || true"

  if have tailscale; then
    ok "Tailscale installed"
  else
    warn "Tailscale install failed (check logs)"
  fi
}

main "$@"
