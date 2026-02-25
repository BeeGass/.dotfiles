#!/usr/bin/env bash
# ~/.dotfiles/install/refresh.sh
# Fast, idempotent environment refresh for macOS/Ubuntu/Termux.
# - Updates: PATH stubs, local overrides, Oh-My-Posh, Zsh plugins, uv+Python tools, Node LTS+globals, tmux plugins
# - Controls: --fast, --dry-run, --only <section>, --no-{python,node,omp}, -v
# - Safe: never overwrites symlinks/files unless explicitly a managed link

set -euo pipefail

# Source shared library (provides colors, logging, paths, helpers)
source "${BASH_SOURCE[0]%/*}/lib.sh"

# ----------------------------- CLI/flags ---------------------------------------
# These override lib.sh defaults
DO_PY=1; DO_NODE=1; DO_OMP=1; ONLY=""; CLEAN_BACKUPS=0
while (( $# )); do
  case "${1}" in
    --dry-run) DRYRUN=1 ;;
    --fast) FAST=1 ;;
    --clean-backups) CLEAN_BACKUPS=1 ;;
    --only) shift; ONLY="${1:-}";;
    --no-python) DO_PY=0 ;;
    --no-node) DO_NODE=0 ;;
    --no-omp) DO_OMP=0 ;;
    --no-sudo) NO_SUDO=1 ;;
    -v|--verbose) VERBOSE=$((VERBOSE+1)) ;;
    -h|--help)
      cat <<'EOF'
Usage: refresh.sh [OPTIONS]

Options:
  --fast              Skip time-consuming updates (Python installs, Flatpak/tmux updates)
  --dry-run           Show what would be done without making changes
  --clean-backups     Remove all *.backup.* files found in home and dotfiles
  --only SECTION      Run only the specified section
  --no-python         Skip Python/uv toolchain section
  --no-node           Skip Node.js/npm section
  --no-omp            Skip Oh-My-Posh updates
  --no-sudo           Skip commands that require sudo
  -v, --verbose       Increase verbosity (can be repeated)

Sections:
  Core:     path, local, directories, cleanup, backups
  Tools:    omp, zsh, python, node, tmux
  System:   ssh, git, tailscale, sf, fonts
  Apps:     snap, claude, gemini, opencode, flatpak
  Doctor:   doctor
  Special:  all (runs all sections)
EOF
      exit 0
      ;;
  esac; shift
done
[[ -z "${ONLY}" ]] && ONLY="all"

# ----------------------------- env/context -------------------------------------
# DOT is an alias for DOTFILES_DIR (provided by lib.sh)
DOT="$DOTFILES_DIR"
LOCAL_BIN="$HOME/.local/bin"
ZDOT_LOCAL="$DOT/zsh/90-local.zsh"

# Export variables that section scripts need
export NO_SUDO DRYRUN FAST VERBOSE CLEAN_BACKUPS DO_PY DO_NODE DO_OMP DOTFILES_DIR

# in_scope helper for section dispatch
in_scope(){ [[ "$ONLY" == "all" || "$ONLY" == "$1" ]]; }

# run_section helper to execute section scripts
run_section() {
  local name="$1"
  local script="${BASH_SOURCE[0]%/*}/sections/${name}.sh"
  if [[ -x "$script" ]]; then
    bash "$script"
  else
    warn "Section script not found: $script"
  fi
}

# ----------------------------- dispatch ----------------------------------------

in_scope path       && run_section path
in_scope local      && run_section local
in_scope directories && run_section directories
in_scope cleanup    && run_section cleanup
in_scope backups    && run_section backups
in_scope omp        && run_section omp
in_scope zsh        && run_section zsh
in_scope python     && run_section python
in_scope node       && run_section node
in_scope tmux       && run_section tmux
in_scope ssh        && run_section ssh
in_scope snap       && run_section snap
in_scope claude     && run_section claude
in_scope gemini     && run_section gemini
in_scope opencode   && run_section opencode
in_scope flatpak    && run_section flatpak
in_scope tailscale  && run_section tailscale
in_scope sf         && run_section sf
in_scope git        && run_section git
in_scope fonts      && run_section fonts

# Doctor runs inline (it's a separate script already)
in_scope doctor     && {
  section "Doctor"
  DOC="$DOTFILES_DIR/scripts/doctor.sh"
  if [[ -x "$DOC" ]]; then
    if (( DRYRUN )); then
      printf "  %s[dry]%s would run: %s\n" "${BLUE}${BOLD}" "${RESET}" "$DOC"
    else
      "$DOC" || true
    fi
  else
    note "No doctor script at $DOC"
  fi
}

section "Done"
note "Open a new shell or: source ~/.zshrc"
