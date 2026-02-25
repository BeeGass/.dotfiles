#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  DO_NODE="${DO_NODE:-1}"

  [[ $DO_NODE -eq 1 ]] || { note "Node disabled via flag"; exit 0; }
  section "Node LTS + globals"
  export NVM_DIR="$HOME/.nvm"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    run "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
  fi
  # shellcheck source=/dev/null
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
  if have nvm; then
    run "nvm install --lts"
    run "nvm alias default 'lts/*'"
    run "nvm use default >/dev/null || true"
    # Globals (customize via NPM_GLOBALS env)
    GLOBALS="${NPM_GLOBALS:-@google/gemini-cli @openai/codex typescript typescript-language-server}"
    run "npm install -g ${GLOBALS} || true"
    ok "Node $(node -v 2>/dev/null || echo '-')"
  else
    warn "nvm not available after install; skipping Node section"
  fi
}

main "$@"
