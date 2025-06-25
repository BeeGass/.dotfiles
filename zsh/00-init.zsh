# ============================================================================
# Initial Setup - Required for all tools
# ============================================================================

# Set up Homebrew path first (required for oh-my-posh and other tools)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Initialize completion system early (required by oh-my-posh)
autoload -Uz compinit
# Check if dump exists and is less than a day old
if [[ $HOME/.zcompdump(#qNmh-24) ]]; then
    compinit -C    # Skip regeneration, use cache
else
    compinit       # Regenerate completion dump
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