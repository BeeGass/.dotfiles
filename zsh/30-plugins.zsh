# ============================================================================
# ZSH Plugins
# ============================================================================

# Detect package manager prefix
if command -v brew &> /dev/null; then
    PLUGIN_PREFIX="$(brew --prefix)"
elif [[ -d "/usr/share" ]]; then
    PLUGIN_PREFIX="/usr"
fi

# Enable syntax highlighting
if [[ -f "${PLUGIN_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "${PLUGIN_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [[ -f "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Enable autosuggestions
if [[ -f "${PLUGIN_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${PLUGIN_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [[ -f "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Enable history substring search (if available)
if [[ -f "${PLUGIN_PREFIX}/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "${PLUGIN_PREFIX}/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
elif [[ -f "/usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "/usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"
elif [[ -f "/usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "/usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
fi