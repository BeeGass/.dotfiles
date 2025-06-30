# ============================================================================
# Key Bindings
# ============================================================================

# Enable vi-mode
bindkey -v

# Better vi-mode search
# Removed ^R binding - let fzf handle it for better history search
bindkey '^S' history-incremental-search-forward

# History substring search
# Only bind if the plugin is loaded (check if the widget exists)
if zle -l | grep -q '^history-substring-search-up$'; then
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    bindkey '^P' history-substring-search-up
    bindkey '^N' history-substring-search-down
else
    # Fallback to regular history search
    bindkey '^[[A' up-line-or-history
    bindkey '^[[B' down-line-or-history
    bindkey '^P' up-line-or-history
    bindkey '^N' down-line-or-history
fi