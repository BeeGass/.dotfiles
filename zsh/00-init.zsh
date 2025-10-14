# ============================================================================
# Initial Setup - Required for all tools
# ============================================================================

# Flags/helpers (no heuristics; use installer-written flags)
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${DOTFILES_FLAGS_DIR:=$XDG_STATE_HOME/dotfiles/flags}"
is_termux() { [[ -e "$DOTFILES_FLAGS_DIR/IS_TERMUX" ]]; }

# Keep PATH nudge early but minimal
export PATH="/usr/local/bin:$PATH"

# GPU probe (sets presence flag)
if command -v nvidia-smi >/dev/null 2>&1; then
  export BEEGASS_GPU_ENABLED=1
fi

# Homebrew shellenv early (required for some tools)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# --- Smart banner with images when supported ---------------------------------
_banner_can_inline_images() {
  # Kitty or WezTerm on the *local* side
  if [[ -n "$WEZTERM_EXECUTABLE" || "$TERM" == "xterm-kitty" ]]; then
    # If inside tmux, require tmux >= 3.4 + allow-passthrough on
    if [[ -n "$TMUX" ]]; then
      local v pass
      v="$(tmux -V 2>/dev/null | awk '{print $2}')"   # e.g. 3.2a or 3.4
      pass="$(tmux show -gv allow-passthrough 2>/dev/null || true)"
      if print -r -- "$v" | awk -F. '{
            m=$1; sub(/[^0-9].*$/,"",$2); n=$2+0;
            exit ! (m>3 || (m==3 && n>=4))
          }' >/dev/null && [[ "$pass" == "on" || -z "$TMUX" ]]; then
        return 0
      fi
      return 1
    fi
    return 0
  fi
  return 1
}

_banner_show() {
  if _banner_can_inline_images && [[ -x "$HOME/.dotfiles/scripts/neofetch_random.sh" ]]; then
    "$HOME/.dotfiles/scripts/neofetch_random.sh"
  elif command -v neofetch >/dev/null 2>&1; then
    neofetch
  elif command -v pfetch >/dev/null 2>&1; then
    "$HOME/.dotfiles/pfetch/runner.sh" 2>/dev/null || pfetch
  else
    print -P "%F{cyan}%n@%m%f  %D{%a %b %d, %I:%M %p}  %~"
  fi
}

# Call banner only in interactive shells
[[ -o interactive ]] && _banner_show

# Autostart tmux in Termux only (interactive, not already in tmux)
if is_termux && [[ -o interactive ]] && [[ -z "$TMUX" ]] && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s main
fi

# Initialize completion system early (required by oh-my-posh)
autoload -Uz compinit
# Use dump if < 24h; else regenerate
if [[ $HOME/.zcompdump(#qNmh-24) ]]; then
  compinit -C
else
  compinit
fi

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY

# Colored output
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd
