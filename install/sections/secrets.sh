#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "Secrets management"

  # Check for HPC environment (no pass available, SSH fallback)
  is_hpc=0
  if [[ -f "$FLAGS_DIR/IS_HPC" ]]; then
    is_hpc=1
  fi

  # Check if pass is installed
  step "Checking pass installation"
  if have pass; then
    ok "pass is installed"
  else
    if (( is_hpc )); then
      note "pass not available on HPC; SSH fallback will be used for secrets"
    elif [[ "$OS_NAME" == "Linux" ]]; then
      warn "pass not installed"
      note "Install with: sudo apt install pass"
    elif [[ "$OS_NAME" == "macOS" ]]; then
      warn "pass not installed"
      note "Install with: brew install pass"
    else
      warn "pass not installed"
    fi
  fi

  # Check if pass store is initialized
  step "Checking pass store initialization"
  pass_store="$HOME/.password-store"
  if [[ -f "$pass_store/.gpg-id" ]]; then
    ok "pass store initialized"
  else
    if (( is_hpc )); then
      note "pass store not initialized (expected on HPC)"
    else
      warn "pass store not initialized"
      note "Initialize with: load-secrets --init"
    fi
  fi

  # Check if load-secrets script is available
  step "Checking load-secrets script"
  if have load-secrets; then
    ok "load-secrets available in PATH"
  elif [[ -x "$HOME/.local/bin/load-secrets" ]]; then
    ok "load-secrets available at ~/.local/bin/load-secrets"
  elif [[ -x "$DOTFILES_DIR/scripts/load-secrets" ]]; then
    note "load-secrets available in dotfiles but not in PATH"
    note "Run path section to fix: just refresh path"
  else
    warn "load-secrets script not found"
  fi

  # Test connectivity to secrets server (Jacobian)
  step "Testing connectivity to secrets server (Jacobian)"
  if ssh -o ConnectTimeout=3 -o BatchMode=yes Jacobian true 2>/dev/null; then
    ok "Jacobian reachable via SSH"
  else
    warn "Cannot reach Jacobian (secrets server)"
    note "Ensure SSH config and network are properly configured"
  fi

  # Sync pass store if initialized and not in FAST mode
  if [[ -f "$pass_store/.gpg-id" ]] && have pass; then
    step "Syncing pass store"
    if (( FAST )); then
      note "Skipping pass sync (--fast mode)"
    elif (( DRYRUN )); then
      note "[dry] pass git pull"
    else
      if pass git pull 2>/dev/null; then
        ok "pass store synced"
      else
        warn "pass git pull failed (check GPG agent and network)"
      fi
    fi
  fi
}

main "$@"
