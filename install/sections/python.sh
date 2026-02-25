#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  DO_PY="${DO_PY:-1}"

  [[ $DO_PY -eq 1 ]] || { note "Python disabled via flag"; exit 0; }
  section "uv + Python toolchain"
  # Install/update uv
  if ! have uv; then run "curl -Ls https://astral.sh/uv/install.sh | sh"; fi
  # Re-resolve uv bin after install
  UV="$(command -v uv || true)"
  [[ -z "$UV" && -x "$HOME/.local/bin/uv" ]] && UV="$HOME/.local/bin/uv"
  if [[ -z "$UV" ]]; then warn "uv not found after install"; exit 0; fi
  run "\"$UV\" self update || true"
  if (( FAST )); then
    note "FAST: skipping CPython re-installs"
  else
    run "\"$UV\" python install 3.11 3.12 3.13 3.14 || true"
  fi
  # CLI tools via uv tool (idempotent)
  run "\"$UV\" tool install 'python-lsp-server[all]' || true"
  run "\"$UV\" tool install ruff || true"
  run "\"$UV\" tool install mypy || true"
  run "\"$UV\" tool install pytest || true"
  run "\"$UV\" tool install pre-commit || true"
  # Optional: auto-bootstrap pre-commit in this repo (commented)
  # if [[ -f \"$DOT/.pre-commit-config.yaml\" ]]; then (cd \"$DOT\" && run \"pre-commit install\"); fi
  # Shell completions (no-op if not supported)
  run "\"$UV\" generate-shell-completion zsh >/dev/null 2>&1 || true"
  ok "uv + Python tools refreshed"
}

main "$@"
