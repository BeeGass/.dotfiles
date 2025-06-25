# ============================================================================
# Key Bindings
# ============================================================================

# Enable vi-mode
bindkey -v

# Better vi-mode search
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# Better history search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down