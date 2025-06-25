# ============================================================================
# Environment Variables
# ============================================================================

# GPG Configuration
export GPG_TTY=$(tty)
export KEYID=0xA34200D828A7BB26
export S_KEYID=0xACC3640C138D96A2
export E_KEYID=0x21691AE75B0463CC
export A_KEYID=0x27D667E55F655FD2

# Node Version Manager
export NVM_DIR="$HOME/.nvm"

# Path Configuration
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# OS-specific paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific paths
    export PATH="/Users/beegass/.julia/juliaup/bin:$PATH"
else
    # Linux specific paths
    export PATH="$HOME/.julia/juliaup/bin:$PATH"
fi

# Editor
export EDITOR="nvim"
export VISUAL="nvim"

# Quick Directory Bookmarks
hash -d pm=~/Documents/Coding/PM
hash -d ludo=~/Documents/Coding/Ludo
hash -d projects=~/Projects
hash -d downloads=~/Downloads
hash -d docs=~/Documents
hash -d dots=~/.dotfiles