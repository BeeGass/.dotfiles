#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  # Alias for refresh.sh compatibility
  DOT="$DOTFILES_DIR"

  section "SSH server configuration"
  if (( NO_SUDO )); then
    warn "Skipping SSH server configuration (--no-sudo)"
    exit 0
  fi

  # Check if openssh-server is installed
  if ! have sshd && ! [[ -x /usr/sbin/sshd ]]; then
    warn "openssh-server not installed"
    if have_apt; then
      note "Install with: sudo apt install -y openssh-server"
    fi
    exit 0
  fi

  ok "openssh-server installed"

  # Check if drop-in directory exists
  if [[ ! -d /etc/ssh/sshd_config.d ]]; then
    note "Creating /etc/ssh/sshd_config.d"
    run "sudo mkdir -p /etc/ssh/sshd_config.d"
  fi

  # Check if source config exists
  ssh_config_source="$DOT/ssh/99-yubikey-only.conf"
  ssh_config_target="/etc/ssh/sshd_config.d/99-yubikey-only.conf"

  if [[ ! -f "$ssh_config_source" ]]; then
    warn "Source SSH config not found: $ssh_config_source"
    exit 0
  fi

  # Check if symlink exists and points to correct location
  needs_restart=0
  if [[ -L "$ssh_config_target" ]]; then
    current_target="$(readlink -f "$ssh_config_target")"
    expected_target="$(readlink -f "$ssh_config_source")"

    if [[ "$current_target" == "$expected_target" ]]; then
      note "SSH config symlink correct"
    else
      warn "SSH config symlink points to wrong location"
      note "Current: $current_target"
      note "Expected: $expected_target"
      run "sudo ln -sf \"$ssh_config_source\" \"$ssh_config_target\""
      ok "Fixed SSH config symlink"
      needs_restart=1
    fi
  elif [[ -f "$ssh_config_target" ]]; then
    warn "SSH config exists but is not a symlink (replacing)"
    run "sudo rm -f \"$ssh_config_target\""
    run "sudo ln -sf \"$ssh_config_source\" \"$ssh_config_target\""
    ok "Created SSH config symlink"
    needs_restart=1
  else
    note "Creating SSH config symlink"
    run "sudo ln -sf \"$ssh_config_source\" \"$ssh_config_target\""
    ok "Created SSH config symlink"
    needs_restart=1
  fi

  # Check if main sshd_config has Include directive
  if [[ -f /etc/ssh/sshd_config ]] && ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
    warn "Include directive not found in /etc/ssh/sshd_config"
    note "Drop-in configs may not be loaded"
  fi

  # Check and disable SSH socket activation (conflicts with custom port)
  if systemctl is-enabled ssh.socket >/dev/null 2>&1; then
    warn "ssh.socket is enabled (conflicts with custom port config)"
    note "Disabling socket activation"
    run "sudo systemctl stop ssh.socket"
    run "sudo systemctl disable ssh.socket"
    ok "Disabled ssh.socket"
    needs_restart=1
  else
    note "ssh.socket not enabled (good)"
  fi

  # Check if SSH service is enabled and running
  if systemctl is-enabled ssh >/dev/null 2>&1 || systemctl is-enabled sshd >/dev/null 2>&1; then
    note "SSH service enabled"
  else
    warn "SSH service not enabled"
    run "sudo systemctl enable ssh || sudo systemctl enable sshd"
    ok "Enabled SSH service"
  fi

  if systemctl is-active ssh >/dev/null 2>&1 || systemctl is-active sshd >/dev/null 2>&1; then
    note "SSH service running"
    if (( needs_restart )); then
      note "Restarting SSH due to config changes"
      run "sudo systemctl restart ssh || sudo systemctl restart sshd"
      ok "Restarted SSH service"
    fi
  else
    warn "SSH service not running"
    run "sudo systemctl start ssh || sudo systemctl start sshd"
    ok "Started SSH service"
  fi

  # Check if listening on port 40822
  if sudo ss -tlnp 2>/dev/null | grep -q ":40822"; then
    ok "SSH listening on port 40822"
  else
    warn "SSH not listening on port 40822 (check configuration)"
  fi
}

main "$@"
