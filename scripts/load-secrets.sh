#!/usr/bin/env bash
# scripts/load-secrets.sh - Hybrid secrets loader (pass with SSH fallback)
#
# Usage:
#   eval "$(load-secrets)"       # Export API keys into current shell
#   load-secrets --check         # Verify connectivity to pass store and/or secrets server
#   load-secrets --init          # Initialize a new pass store
#   load-secrets --push          # Sync local pass store to git remote
#   load-secrets --pull          # Pull latest from git remote

set -euo pipefail

# === Source lib.sh ===
_lib="${BASH_SOURCE[0]%/*}/../install/lib.sh"
if [[ -f "$_lib" ]]; then
  # shellcheck source=../install/lib.sh
  source "$_lib"
else
  # Fallback: minimal logging to stderr
  section() { printf "==> %s\n" "$*" >&2; }
  step()    { printf "  -> %s\n" "$*" >&2; }
  ok()      { printf "  [ok] %s\n" "$*" >&2; }
  warn()    { printf "  [warn] %s\n" "$*" >&2; }
  err()     { printf "  [err ] %s\n" "$*" >&2; }
  note()    { printf "  %s\n" "$*" >&2; }
  have()    { command -v "$1" >/dev/null 2>&1; }
fi

# === Configuration ===
SECRETS_HOST="${SECRETS_HOST:-Jacobian}"
SECRETS_PATH="${SECRETS_PATH:-.secrets/env}"
PASS_STORE="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
GPG_KEY_ID="0xA34200D828A7BB26"

# === Helper functions ===

pass_store_exists() {
  [[ -f "$PASS_STORE/.gpg-id" ]]
}

can_decrypt_pass() {
  # Try to decrypt a test entry (or any entry) to verify GPG is working
  if ! have pass; then
    return 1
  fi
  if ! pass_store_exists; then
    return 1
  fi
  # Try to list entries; if gpg-agent can't decrypt, this will fail
  pass show "api/" >/dev/null 2>&1 || pass ls "api/" >/dev/null 2>&1 || return 1
  return 0
}

load_from_pass() {
  # List all entries under api/ and export them
  local entries
  entries=$(pass ls api/ 2>/dev/null | grep -E "^[[:space:]]*(api/)?[A-Z_]+$" | sed 's/^[[:space:]]*//; s/^api\///' || true)

  if [[ -z "$entries" ]]; then
    # Try alternative listing format
    entries=$(pass ls api 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//; s/^api\///' | grep -E "^[A-Z_]+$" || true)
  fi

  if [[ -z "$entries" ]]; then
    return 1
  fi

  local success=0
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    local value
    if value=$(pass show "api/$entry" 2>/dev/null); then
      printf 'export %s=%q\n' "$entry" "$value"
      success=1
    fi
  done <<< "$entries"

  [[ $success -eq 1 ]]
}

load_from_ssh() {
  # Fetch secrets from remote server
  ssh -o ConnectTimeout=5 -o BatchMode=yes "$SECRETS_HOST" "cat ~/$SECRETS_PATH" 2>/dev/null
}

# === Command handlers ===

cmd_load() {
  # Try pass first
  if have pass && pass_store_exists; then
    if load_from_pass; then
      return 0
    fi
    warn "Pass decryption failed (YubiKey not present?), falling back to SSH" >&2
  fi

  # SSH fallback
  if load_from_ssh; then
    return 0
  fi

  warn "Failed to load secrets from both pass and SSH" >&2
  return 1
}

cmd_check() {
  section "Checking secrets sources"

  local pass_ok=0
  local ssh_ok=0

  # Check pass store
  step "Checking pass store"
  if ! have pass; then
    warn "pass not installed"
  elif ! pass_store_exists; then
    warn "Pass store not initialized ($PASS_STORE/.gpg-id not found)"
  else
    ok "Pass store exists at $PASS_STORE"
    step "Testing pass decryption"
    if pass ls api/ >/dev/null 2>&1; then
      ok "Pass store accessible (GPG working)"
      pass_ok=1
    else
      warn "Cannot access pass store (GPG agent may need YubiKey)"
    fi
  fi

  # Check SSH connectivity
  step "Checking SSH connectivity to $SECRETS_HOST"
  if ssh -o ConnectTimeout=5 -o BatchMode=yes "$SECRETS_HOST" "test -f ~/$SECRETS_PATH" 2>/dev/null; then
    ok "SSH secrets server reachable, secrets file exists"
    ssh_ok=1
  elif ssh -o ConnectTimeout=5 -o BatchMode=yes "$SECRETS_HOST" "true" 2>/dev/null; then
    warn "SSH to $SECRETS_HOST works, but secrets file not found at ~/$SECRETS_PATH"
  else
    warn "Cannot connect to $SECRETS_HOST via SSH"
  fi

  # Summary
  section "Summary"
  if [[ $pass_ok -eq 1 ]]; then
    ok "Pass store: available"
  else
    warn "Pass store: unavailable"
  fi
  if [[ $ssh_ok -eq 1 ]]; then
    ok "SSH fallback: available"
  else
    warn "SSH fallback: unavailable"
  fi

  if [[ $pass_ok -eq 1 || $ssh_ok -eq 1 ]]; then
    return 0
  else
    err "No secrets sources available"
    return 1
  fi
}

cmd_init() {
  section "Initializing pass store"

  if ! have pass; then
    err "pass is not installed"
    note "Install with: sudo apt install pass"
    return 1
  fi

  if ! have gpg; then
    err "gpg is not installed"
    return 1
  fi

  # Check if GPG key exists
  step "Checking for GPG key $GPG_KEY_ID"
  if ! gpg --list-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
    err "GPG key $GPG_KEY_ID not found"
    note "Import your GPG key first, or insert your YubiKey"
    return 1
  fi
  ok "GPG key found"

  # Initialize pass store
  step "Initializing pass store with GPG key $GPG_KEY_ID"
  pass init "$GPG_KEY_ID"
  ok "Pass store initialized"

  # Initialize git
  step "Initializing git in pass store"
  pass git init
  ok "Git initialized"

  section "Next steps"
  note "Add your first API key with:"
  note "  pass insert api/OPENAI_API_KEY"
  note "  pass insert api/ANTHROPIC_API_KEY"
  note "  pass insert api/HF_TOKEN"
  note ""
  note "To sync with a remote, run:"
  note "  pass git remote add origin <your-repo-url>"
  note "  pass git push -u origin main"
}

cmd_push() {
  section "Pushing pass store to remote"

  if ! have pass; then
    err "pass is not installed"
    return 1
  fi

  if ! pass_store_exists; then
    err "Pass store not initialized"
    note "Run: load-secrets --init"
    return 1
  fi

  step "Pushing to git remote"
  pass git push
  ok "Pass store synced to remote"
}

cmd_pull() {
  section "Pulling pass store from remote"

  if ! have pass; then
    err "pass is not installed"
    return 1
  fi

  if ! pass_store_exists; then
    err "Pass store not initialized"
    note "Run: load-secrets --init"
    return 1
  fi

  step "Pulling from git remote"
  pass git pull
  ok "Pass store updated from remote"
}

# === Main ===

main() {
  case "${1:-}" in
    --check)
      cmd_check
      ;;
    --init)
      cmd_init
      ;;
    --push)
      cmd_push
      ;;
    --pull)
      cmd_pull
      ;;
    --help|-h)
      cat >&2 <<'USAGE'
Usage: load-secrets [OPTION]

Load API keys into the current shell from pass or SSH fallback.

Options:
  (no option)   Output export statements for eval
  --check       Verify connectivity to pass store and secrets server
  --init        Initialize a new pass store with GPG key
  --push        Sync local pass store to git remote
  --pull        Pull latest from git remote
  --help        Show this help message

Examples:
  eval "$(load-secrets)"     # Load secrets into current shell
  load-secrets --check       # Check if secrets are accessible
USAGE
      ;;
    "")
      cmd_load
      ;;
    *)
      err "Unknown option: $1"
      note "Run 'load-secrets --help' for usage"
      return 1
      ;;
  esac
}

main "$@"
