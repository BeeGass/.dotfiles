#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

main() {
  section "User directories & bookmarks"

  # Create standard directories
  local dirs=("$HOME/Projects" "$HOME/Papers")
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      run "mkdir -p \"$dir\""
      ok "Created $(basename "$dir") directory"
    else
      note "$(basename "$dir") directory already exists"
    fi
  done

  # Add to GTK bookmarks (for GNOME Files/Nautilus sidebar)
  if [[ "$OS_NAME" == "Linux" ]]; then
    local bookmarks_file="$HOME/.config/gtk-3.0/bookmarks"
    mkdir -p "$(dirname "$bookmarks_file")"

    # Ensure bookmarks file exists
    [[ ! -f "$bookmarks_file" ]] && touch "$bookmarks_file"

    # Add bookmarks if not already present
    local projects_bookmark="file://$HOME/Projects Projects"
    local papers_bookmark="file://$HOME/Papers Papers"

    if ! grep -Fxq "$projects_bookmark" "$bookmarks_file" 2>/dev/null; then
      echo "$projects_bookmark" >> "$bookmarks_file"
      ok "Added Projects to file manager sidebar"
    else
      note "Projects bookmark already present"
    fi

    if ! grep -Fxq "$papers_bookmark" "$bookmarks_file" 2>/dev/null; then
      echo "$papers_bookmark" >> "$bookmarks_file"
      ok "Added Papers to file manager sidebar"
    else
      note "Papers bookmark already present"
    fi
  else
    note "GTK bookmarks only apply to Linux desktop environments"
  fi
}

main "$@"
