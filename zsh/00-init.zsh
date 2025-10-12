# ============================================================================
# Initial Setup - Required for all tools
# ============================================================================

# Set up Homebrew path first (required for oh-my-posh and other tools)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Simple banner for interactive shells (Termux or not)
if [[ $- == *i* && -z "$TMUX" ]]; then
    if command -v pfetch >/dev/null 2>&1; then
        "$HOME/.dotfiles/pfetch/runner.sh"
    elif command -v neofetch >/dev/null 2>&1; then
        if [[ -f "$HOME/.dotfiles/scripts/neofetch_random.sh" ]]; then
            source "$HOME/.dotfiles/scripts/neofetch_random.sh"
            neofetch_random
        else
            neofetch
        fi
    else
        print -P "%F{cyan}%n@%m%f  %D{%a %b %d, %I:%M %p}  %~"
    fi
fi

if [[ -n "$TERMUX_VERSION" && -z "$TMUX" && $- == *i* ]] && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s main
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
