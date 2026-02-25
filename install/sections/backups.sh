#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  # Alias for refresh.sh compatibility
  DOT="$DOTFILES_DIR"
  CLEAN_BACKUPS="${CLEAN_BACKUPS:-0}"

  section "Backup file cleanup"

  # Search ALL locations where backups are created by install/refresh scripts
  # Covers: symlink destinations, modified configs, and dotfiles repo itself
  backup_files=()
  search_paths=(
    # Root level dotfiles
    "$HOME"                           # .zshrc, .zshenv, .vimrc, .gitconfig, .tmux.conf (maxdepth 1)

    # XDG and standard config directories
    "$HOME/.config"                   # nvim, kitty, wezterm, ghostty, claude, gemini, oh-my-posh, picom, neofetch, gtk-3.0, fontconfig, systemd
    "$HOME/.local"                    # bin, share, state

    # Tool-specific directories
    "$HOME/.ssh"                      # config, config.d/
    "$HOME/.gnupg"                    # gpg-agent.conf, gpg.conf, dirmngr.conf
    "$HOME/.tmux"                     # plugins/tpm
    "$HOME/.nvm"                      # Node Version Manager
    "$HOME/.zsh"                      # plugins (autosuggestions, syntax-highlighting)
    "$HOME/.termux"                   # Termux configs (Android only)
    "$HOME/.opencode"                 # OpenCode CLI installation

    # Dotfiles repo and all subdirectories
    "$DOT"                            # All dotfiles source files
  )

  for search_path in "${search_paths[@]}"; do
    [[ ! -d "$search_path" ]] && continue

    depth_limit="-maxdepth 1"
    # Search recursively everywhere except $HOME root (to avoid Documents, Downloads, etc.)
    [[ "$search_path" != "$HOME" ]] && depth_limit=""

    # Exclude snap directories (managed by snap system, includes trash)
    while IFS= read -r -d '' file; do
      [[ "$file" == "$HOME/snap/"* ]] && continue
      backup_files+=("$file")
    done < <(find "$search_path" $depth_limit -type f -name "*.backup.*" -print0 2>/dev/null)
  done

  if (( ${#backup_files[@]} == 0 )); then
    note "No backup files found"
    exit 0
  fi

  # Group by location for better reporting
  by_location=()
  for file in "${backup_files[@]}"; do
    loc="other"
    [[ "$file" == "$HOME/.config/"* ]] && loc=".config"
    [[ "$file" == "$HOME/.local/"* ]] && loc=".local"
    [[ "$file" == "$HOME/.ssh/"* ]] && loc=".ssh"
    [[ "$file" == "$HOME/.gnupg/"* ]] && loc=".gnupg"
    [[ "$file" == "$HOME/.tmux/"* ]] && loc=".tmux"
    [[ "$file" == "$HOME/.nvm/"* ]] && loc=".nvm"
    [[ "$file" == "$HOME/.zsh/"* ]] && loc=".zsh"
    [[ "$file" == "$HOME/.termux/"* ]] && loc=".termux"
    [[ "$file" == "$HOME/.opencode/"* ]] && loc=".opencode"
    [[ "$file" == "$DOT/"* ]] && loc="dotfiles"
    [[ "$file" == "$HOME/"* && "$file" != "$HOME/"*"/"* ]] && loc="home"
    by_location+=("$loc:$file")
  done

  if [[ $CLEAN_BACKUPS -eq 0 ]]; then
    warn "Found ${#backup_files[@]} backup file(s) (use --clean-backups to remove)"
    if (( VERBOSE > 0 )); then
      printf "  ${DIM}Search locations: home, .config, .local, .ssh, .gnupg, .tmux, .nvm, .zsh, .termux, .opencode, dotfiles${RESET}\n"
      for item in "${by_location[@]}"; do
        note "  - ${item#*:}"
      done
    fi
    exit 0
  fi

  step "Removing ${#backup_files[@]} backup file(s)"
  removed=0
  for file in "${backup_files[@]}"; do
    if (( VERBOSE > 0 )); then
      note "Removing: $file"
    fi
    if (( DRYRUN )); then
      printf "  %s[dry]%s would remove: %s\n" "${BLU}${BOLD}" "${RESET}" "$file"
    else
      rm -f "$file" && removed=$((removed + 1)) || warn "Failed to remove: $file"
    fi
  done

  ok "Removed $removed backup file(s)"
}

main "$@"
