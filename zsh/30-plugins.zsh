# ============================================================================
# ZSH Plugins (portable: prefers user-cloned, then Termux/Homebrew/Ubuntu/Nix)
# Load order: history-substring-search → autosuggestions → syntax-highlighting (last)
# ============================================================================

: ${ZSH_PLUGIN_ROOT:="$HOME/.local/share/zsh"}

# Cache brew prefix once
local __brew_prefix=""
if command -v brew >/dev/null 2>&1; then
  __brew_prefix="$(brew --prefix 2>/dev/null)"
fi

# Build candidate paths helper
_plugin_candidates() {
  # $1 = plugin name; $2 = plugin file (relative)
  local name="$1" file="$2"
  local -a out

  # user-cloned first
  [[ -f "$ZSH_PLUGIN_ROOT/$name/$file" ]] && out+="$ZSH_PLUGIN_ROOT/$name/$file"

  # Termux prefix safely (don’t explode if PREFIX is unset)
  local termux_prefix="${PREFIX:-/data/data/com.termux/files/usr}"
  [[ -f "$termux_prefix/share/$name/$file" ]] && out+="$termux_prefix/share/$name/$file"
  [[ -f "$termux_prefix/share/zsh/plugins/$name/$file" ]] && out+="$termux_prefix/share/zsh/plugins/$name/$file"

  # Homebrew (cached)
  if [[ -n "$__brew_prefix" ]]; then
    [[ -f "$__brew_prefix/share/$name/$file" ]] && out+="$__brew_prefix/share/$name/$file"
    [[ -f "$__brew_prefix/share/zsh/plugins/$name/$file" ]] && out+="$__brew_prefix/share/zsh/plugins/$name/$file"
  fi

  # Ubuntu/Debian common
  [[ -f "/usr/share/$name/$file" ]] && out+="/usr/share/$name/$file"
  [[ -f "/usr/share/zsh/plugins/$name/$file" ]] && out+="/usr/share/zsh/plugins/$name/$file"

  # Nix profiles
  [[ -f "$HOME/.nix-profile/share/$name/$file" ]] && out+="$HOME/.nix-profile/share/$name/$file"
  [[ -f "/run/current-system/sw/share/$name/$file" ]] && out+="/run/current-system/sw/share/$name/$file"

  # XDG data dirs (best-effort)
  local IFS=':' pfx
  for pfx in $XDG_DATA_DIRS; do
    [[ -f "$pfx/$name/$file" ]] && out+="$pfx/$name/$file"
    [[ -f "$pfx/zsh/plugins/$name/$file" ]] && out+="$pfx/zsh/plugins/$name/$file"
  done

  print -r -- "${out[@]}"
}

# Source-first helper with guard
_plugin_source_first() {
  # $1 = guard var; $2.. = candidate files
  local guard="$1"; shift
  local f
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    if [[ -z "${(P)guard}" ]]; then
      source "$f"
      typeset -g "${guard}=1"
      return 0
    fi
  done
  return 1
}

# Optional: augment fpath for completions if present under plugin dirs
_add_completions_if_present() {
  local dir
  for dir in "$ZSH_PLUGIN_ROOT"/*/completions(N); do
    [[ -d "$dir" ]] && fpath=("$dir" $fpath)
  done
}
_add_completions_if_present

# Load plugins in correct order
_plugin_source_first __ZPLUG_HIST_SUBSTR  $(_plugin_candidates "zsh-history-substring-search" "zsh-history-substring-search.zsh")
_plugin_source_first __ZPLUG_AUTOSUGGESTIONS $(_plugin_candidates "zsh-autosuggestions" "zsh-autosuggestions.zsh")
_plugin_source_first __ZPLUG_HIGHLIGHT $(_plugin_candidates "zsh-syntax-highlighting" "zsh-syntax-highlighting.zsh")

# Soft fallbacks if distro preloads functions (no double-source)
(( $+functions[_zsh_autosuggest_start] )) && typeset -g __ZPLUG_AUTOSUGGESTIONS=1
(( $+functions[_zsh_highlight] )) && typeset -g __ZPLUG_HIGHLIGHT=1

# zmodload niceties
zmodload -i zsh/complist 2>/dev/null || true
