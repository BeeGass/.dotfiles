# ============================================================================
# Completion Configuration
# ============================================================================

# Configure completion menu highlighting
zstyle ':completion:*' menu select

# Safe LS_COLORS → list-colors
local _ls_colors="${LS_COLORS-}"
if [[ -z "$_ls_colors" ]] && command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b 2>/dev/null)" || true
  _ls_colors="${LS_COLORS-}"
fi
[[ -n "$_ls_colors" ]] && zstyle ':completion:*' list-colors ${(s.:.)_ls_colors}

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Partial completion suggestions
zstyle ':completion:*' list-suffixes
zstyle ':completion:*' expand prefix suffix

# Highlight the current selection in menu
zmodload zsh/complist
