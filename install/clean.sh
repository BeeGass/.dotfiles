#!/usr/bin/env bash
# install/clean.sh - Remove all dotfiles-managed symlinks, configs, and user-space tools.
#
# Undoes changes made by install.sh and platform-specific install scripts so you
# can re-run the correct installer for your platform.
#
# Usage: clean.sh [OPTIONS]
#   --dry-run          Show what would be removed without making changes
#   --keep-tools       Keep user-space tools (uv, cargo, nvm, oh-my-posh, fzf)
#   --clean-git        Also remove git identity (kept by default)
#   --clean-ssh        Also remove SSH config and server setup (kept by default)
#   --no-sudo          Skip sudo operations (system symlinks, SSH server config)
#   -y, --yes          Skip confirmation prompt
#   -v, --verbose      Increase verbosity
#   -h, --help         Show this help message

set -euo pipefail
source "${BASH_SOURCE[0]%/*}/lib.sh"

# ============================================================================
# CLI
# ============================================================================

KEEP_TOOLS=0
KEEP_GIT=1
KEEP_SSH=1
SKIP_CONFIRM=0

while (( $# )); do
  case "$1" in
    --dry-run)      DRYRUN=1 ;;
    --keep-tools)   KEEP_TOOLS=1 ;;
    --clean-git)    KEEP_GIT=0 ;;
    --clean-ssh)    KEEP_SSH=0 ;;
    --no-sudo)      NO_SUDO=1 ;;
    -y|--yes)       SKIP_CONFIRM=1 ;;
    -v|--verbose)   VERBOSE=$((VERBOSE+1)) ;;
    -h|--help)
      sed -n '2,/^$/{ s/^# \?//; p; }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *) warn "Unknown flag: $1" ;;
  esac
  shift
done

# ============================================================================
# Helpers
# ============================================================================

DOT="$DOTFILES_DIR"

# Remove a symlink only if it points into the dotfiles tree (or ~/.local/bin).
# Never deletes regular files — those are the user's own data.
remove_symlink() {
  local target="$1"
  if [[ ! -L "$target" ]]; then
    note "Not a symlink (skipped): $target"
    return
  fi
  local link_dest
  link_dest="$(readlink "$target" 2>/dev/null || true)"
  if (( DRYRUN )); then
    step "[dry] would remove symlink: $target -> $link_dest"
  else
    rm -f "$target"
    ok "Removed symlink: $target"
  fi
}

# Remove a directory tree (git clones, plugin dirs, etc.)
remove_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    note "Not present (skipped): $dir"
    return
  fi
  if (( DRYRUN )); then
    step "[dry] would remove directory: $dir"
  else
    rm -rf "$dir"
    ok "Removed: $dir"
  fi
}

# Remove a regular file
remove_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    note "Not present (skipped): $file"
    return
  fi
  if (( DRYRUN )); then
    step "[dry] would remove file: $file"
  else
    rm -f "$file"
    ok "Removed: $file"
  fi
}

# Remove a block of text between markers from a file
remove_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"

  if [[ ! -f "$file" ]]; then
    note "File not found (skipped): $file"
    return
  fi
  if ! grep -Fq "$start_marker" "$file" 2>/dev/null; then
    note "Marker not found in $file (skipped)"
    return
  fi
  if (( DRYRUN )); then
    step "[dry] would remove block ($start_marker) from $file"
  else
    local tmpfile
    tmpfile="$(mktemp)"
    awk -v start="$start_marker" -v end="$end_marker" '
      $0 ~ start { skip=1; next }
      $0 ~ end   { skip=0; next }
      !skip
    ' "$file" > "$tmpfile"
    mv "$tmpfile" "$file"
    ok "Removed block from $file"
  fi
}

# Run a sudo command, respecting NO_SUDO and DRYRUN
run_sudo() {
  if (( NO_SUDO )); then
    note "[skip] $* (--no-sudo)"
    return
  fi
  if (( DRYRUN )); then
    step "[dry] would run: sudo $*"
  else
    sudo "$@"
  fi
}

# ============================================================================
# Confirmation
# ============================================================================

confirm_clean() {
  section "Dotfiles Clean"
  warn "This will remove all dotfiles-managed symlinks, configs, and state."
  [[ $KEEP_TOOLS -eq 1 ]] && note "  --keep-tools:  user-space tools will be preserved"
  [[ $KEEP_GIT   -eq 1 ]] && note "  --keep-git:    git identity will be preserved (use --clean-git to remove)"
  [[ $KEEP_SSH   -eq 1 ]] && note "  --keep-ssh:    SSH config will be preserved (use --clean-ssh to remove)"
  [[ $NO_SUDO    -eq 1 ]] && note "  --no-sudo:     system-level changes will be skipped"
  (( DRYRUN ))            && note "  --dry-run:     no changes will be made"
  echo ""

  if (( SKIP_CONFIRM )); then
    return
  fi

  printf "  %sAre you sure you want to continue?%s [y/N] " "$BOLD" "$RESET"
  local answer
  read -r answer
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *)
      echo "  Aborted."
      exit 0
      ;;
  esac
}

# ============================================================================
# Sections
# ============================================================================

clean_symlinks() {
  section "Removing dotfile symlinks"

  # Shell config
  remove_symlink "$HOME/.zshenv"
  remove_symlink "$HOME/.zshrc"
  remove_symlink "$HOME/.vimrc"
  remove_symlink "$HOME/.gitconfig"
  remove_symlink "$HOME/.tmux.conf"

  # SSH (kept by default)
  if (( ! KEEP_SSH )); then
    remove_symlink "$HOME/.ssh/config"
  else
    note "Keeping SSH config (use --clean-ssh to remove)"
  fi

  # XDG config symlinks
  remove_symlink "$HOME/.config/nvim/init.vim"
  remove_symlink "$HOME/.config/kitty/kitty.conf"
  remove_symlink "$HOME/.config/wezterm/wezterm.lua"
  remove_symlink "$HOME/.config/ghostty/config"
  remove_symlink "$HOME/.config/claude/CLAUDE.md"
  remove_symlink "$HOME/.config/gemini/GEMINI.md"
  remove_symlink "$HOME/.config/oh-my-posh/config.json"
  remove_symlink "$HOME/.config/neofetch/config.conf"
  remove_symlink "$HOME/.config/picom/picom.conf"
  remove_symlink "$HOME/.config/systemd/user/picom.service"
  remove_symlink "$HOME/.config/fontconfig/conf.d/30-google-sans-mono-mono.conf"

  # Claude config symlinks
  remove_symlink "$HOME/.claude/CLAUDE.md"
  remove_symlink "$HOME/.claude/settings.json"
  remove_symlink "$HOME/.claude/.mcp.json"
  remove_symlink "$HOME/.claude/docs"
  remove_symlink "$HOME/.claude/hooks"
  remove_symlink "$HOME/.claude/statusline"
  remove_symlink "$HOME/.claude/templates"
  remove_symlink "$HOME/.claude/commands"

  # Platform-specific git config
  remove_symlink "$HOME/.gitconfig.local"

  # ~/.local/bin script symlinks
  local bin_link
  for bin_link in "$HOME/.local/bin"/*; do
    [[ -L "$bin_link" ]] || continue
    local dest
    dest="$(readlink "$bin_link" 2>/dev/null || true)"
    # Only remove symlinks pointing into the dotfiles directory
    if [[ "$dest" == "$DOT/"* ]]; then
      remove_symlink "$bin_link"
    fi
  done

  # SSH server config (system-level, kept by default)
  if (( ! KEEP_SSH )); then
    if [[ -L "/etc/ssh/sshd_config.d/99-yubikey-only.conf" ]]; then
      step "Removing SSH server config symlink"
      run_sudo rm -f "/etc/ssh/sshd_config.d/99-yubikey-only.conf"
    fi
  fi

  # System-level symlinks (fd, bat)
  if [[ -L "/usr/local/bin/fd" ]]; then
    run_sudo rm -f "/usr/local/bin/fd"
  fi
  if [[ -L "/usr/local/bin/bat" ]]; then
    run_sudo rm -f "/usr/local/bin/bat"
  fi
}

clean_shell_modifications() {
  section "Removing shell modifications"

  # Loader stub in ~/.zshrc (if it's a regular file, not our symlink)
  if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    remove_block "$HOME/.zshrc" \
      "# >>> BeeGass dotfiles >>>" \
      "# <<< BeeGass dotfiles <<<"
  fi

  # Zsh plugin source lines appended to ~/.zshrc
  if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    remove_block "$HOME/.zshrc" \
      "zsh-autosuggestions/zsh-autosuggestions.zsh" \
      "zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi

  # PATH additions appended to ~/.zshrc and ~/.bashrc
  for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$rcfile" && ! -L "$rcfile" ]]; then
      # Remove kitty's PATH export
      if grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$rcfile" 2>/dev/null; then
        if (( DRYRUN )); then
          step "[dry] would remove PATH export from $rcfile"
        else
          local tmpfile
          tmpfile="$(mktemp)"
          grep -Fv 'export PATH="$HOME/.local/bin:$PATH"' "$rcfile" > "$tmpfile" || true
          mv "$tmpfile" "$rcfile"
          ok "Removed PATH export from $rcfile"
        fi
      fi
    fi
  done

  # HPC zsh exec stub in .bash_profile
  if [[ -f "$HOME/.bash_profile" ]]; then
    remove_block "$HOME/.bash_profile" \
      "# >>> dotfiles-zsh-exec >>>" \
      "# <<< dotfiles-zsh-exec <<<"
  fi
}

clean_os_flags() {
  section "Removing OS flags and state"
  remove_dir "$FLAGS_DIR"
  remove_file "$ENV_SNAPSHOT"
  # Remove parent dirs if empty
  rmdir "$XDG_STATE_ROOT/dotfiles" 2>/dev/null || true
}

clean_plugins() {
  section "Removing plugins and cloned repos"

  # Zsh plugins
  remove_dir "$HOME/.zsh/plugins/zsh-autosuggestions"
  remove_dir "$HOME/.zsh/plugins/zsh-syntax-highlighting"
  remove_dir "$HOME/.zsh/zsh-autosuggestions"
  remove_dir "$HOME/.zsh/zsh-syntax-highlighting"
  # Clean up empty plugin dirs
  rmdir "$HOME/.zsh/plugins" 2>/dev/null || true
  rmdir "$HOME/.zsh" 2>/dev/null || true

  # Tmux Plugin Manager
  remove_dir "$HOME/.tmux/plugins/tpm"
  # Clean up empty tmux dirs
  rmdir "$HOME/.tmux/plugins" 2>/dev/null || true
  rmdir "$HOME/.tmux" 2>/dev/null || true
}

clean_tools() {
  if (( KEEP_TOOLS )); then
    note "Skipping tool removal (--keep-tools)"
    return
  fi

  section "Removing user-space tools"

  # oh-my-posh
  remove_file "$HOME/.local/bin/oh-my-posh"

  # fzf
  remove_dir "$HOME/.fzf"
  remove_file "$HOME/.local/bin/fzf"
  remove_file "$HOME/.fzf.zsh"
  remove_file "$HOME/.fzf.bash"

  # uv
  remove_file "$HOME/.local/bin/uv"
  remove_file "$HOME/.local/bin/uvx"
  # uv-managed Python versions and tools
  remove_dir "$HOME/.local/share/uv"

  # Rust / cargo (only the toolchain, not user projects)
  if [[ -f "$HOME/.cargo/env" ]]; then
    if (( DRYRUN )); then
      step "[dry] would run: rustup self uninstall -y"
    else
      if command -v rustup >/dev/null 2>&1; then
        step "Uninstalling Rust toolchain via rustup"
        rustup self uninstall -y 2>/dev/null || warn "rustup uninstall failed; remove ~/.cargo manually"
      else
        remove_dir "$HOME/.cargo"
        remove_dir "$HOME/.rustup"
      fi
    fi
  fi

  # nvm + Node.js
  remove_dir "$HOME/.nvm"

  # opencode
  remove_dir "$HOME/.opencode"

  # kitty (user-space install)
  remove_dir "$HOME/.local/kitty.app"
  remove_file "$HOME/.local/bin/kitty"
  remove_file "$HOME/.local/bin/kitten"
  remove_file "$HOME/.local/share/applications/kitty.desktop"
  remove_file "$HOME/.local/share/applications/kitty-open.desktop"
  remove_file "$HOME/.config/xdg-terminals.list"

  # Neofetch images
  remove_dir "$NEOFETCH_IMG_DIR"
  rmdir "${XDG_DATA_HOME:-$HOME/.local/share}/neofetch" 2>/dev/null || true

  # pfetch (system-level)
  if [[ -f "/usr/local/bin/pfetch" ]]; then
    run_sudo rm -f "/usr/local/bin/pfetch"
  fi
}

clean_fonts() {
  section "Removing fonts"

  # JetBrainsMono Nerd Font
  local font_dir="$HOME/.local/share/fonts"
  if [[ -d "$font_dir" ]]; then
    local nerd_fonts=()
    while IFS= read -r -d '' f; do
      nerd_fonts+=("$f")
    done < <(find "$font_dir" -maxdepth 1 -name "JetBrains*" -print0 2>/dev/null)

    if [[ ${#nerd_fonts[@]} -gt 0 ]]; then
      if (( DRYRUN )); then
        step "[dry] would remove ${#nerd_fonts[@]} JetBrainsMono Nerd Font files"
      else
        rm -f "${nerd_fonts[@]}"
        ok "Removed JetBrainsMono Nerd Font files"
      fi
    fi
  fi

  # Google Sans fonts
  remove_dir "$HOME/.local/share/fonts/GoogleSansMono"
  remove_dir "$HOME/.local/share/fonts/GoogleSans"

  # Termux font
  remove_file "$HOME/.termux/font.ttf"

  # Rebuild font cache if we removed anything
  if ! (( DRYRUN )) && command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f 2>/dev/null || true
  fi
}

clean_git_identity() {
  section "Git identity"

  if (( KEEP_GIT )); then
    note "Keeping git identity (use --clean-git to remove)"
    return
  fi

  if (( DRYRUN )); then
    step "[dry] would unset git user.name, user.email, credential.helper"
  else
    git config --global --unset user.name 2>/dev/null || true
    git config --global --unset user.email 2>/dev/null || true
    git config --global --unset credential.helper 2>/dev/null || true
    ok "Cleared git global identity and credential helper"
  fi
}

clean_local_overrides() {
  section "Removing local overrides"
  remove_file "$DOT/zsh/90-local.zsh"
}

clean_desktop_entries() {
  section "Removing desktop entries"

  # GTK bookmarks (remove our lines only)
  if [[ -f "$HOME/.config/gtk-3.0/bookmarks" ]]; then
    for bookmark in "file://$HOME/Projects Projects" "file://$HOME/Papers Papers"; do
      if grep -Fxq "$bookmark" "$HOME/.config/gtk-3.0/bookmarks" 2>/dev/null; then
        if (( DRYRUN )); then
          step "[dry] would remove bookmark: $bookmark"
        else
          local tmpfile
          tmpfile="$(mktemp)"
          grep -Fxv "$bookmark" "$HOME/.config/gtk-3.0/bookmarks" > "$tmpfile" || true
          mv "$tmpfile" "$HOME/.config/gtk-3.0/bookmarks"
          ok "Removed bookmark: $bookmark"
        fi
      fi
    done
  fi

  # macOS "Open Here in Kitty" app
  remove_dir "$HOME/Applications/Open Here in Kitty.app"

  # Picom systemd service
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-enabled picom.service 2>/dev/null | grep -q enabled; then
      if (( DRYRUN )); then
        step "[dry] would disable picom.service"
      else
        systemctl --user disable picom.service 2>/dev/null || true
        systemctl --user stop picom.service 2>/dev/null || true
        ok "Disabled picom.service"
      fi
    fi
  fi
}

clean_empty_config_dirs() {
  section "Cleaning up empty directories"

  # Only remove dirs we created that are now empty (safe)
  local dirs=(
    "$HOME/.config/nvim"
    "$HOME/.config/kitty"
    "$HOME/.config/wezterm"
    "$HOME/.config/ghostty"
    "$HOME/.config/claude"
    "$HOME/.config/gemini"
    "$HOME/.config/oh-my-posh"
    "$HOME/.config/neofetch"
    "$HOME/.config/picom"
    "$HOME/.config/systemd/user"
    "$HOME/.config/fontconfig/conf.d"
  )
  for d in "${dirs[@]}"; do
    if [[ -d "$d" ]] && [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
      if (( DRYRUN )); then
        step "[dry] would remove empty dir: $d"
      else
        rmdir "$d" 2>/dev/null && note "Removed empty dir: $d" || true
      fi
    fi
  done
}

# ============================================================================
# Main
# ============================================================================

main() {
  confirm_clean

  clean_symlinks
  clean_shell_modifications
  clean_os_flags
  clean_plugins
  clean_tools
  clean_fonts
  clean_git_identity
  clean_local_overrides
  clean_desktop_entries
  clean_empty_config_dirs

  section "Clean complete"
  if (( DRYRUN )); then
    note "Dry run: no changes were made. Re-run without --dry-run to apply."
  else
    step "All dotfiles-managed state has been removed."
    step "You can now run the correct installer for this platform."
    note "  just install-ubuntu    # Ubuntu/Debian desktop"
    note "  just install-macos     # macOS"
    note "  just install-rpi       # Raspberry Pi"
    note "  just install-hpc       # HPC cluster (no sudo)"
    note "  just install           # Auto-detect platform"
  fi
}

main "$@"
