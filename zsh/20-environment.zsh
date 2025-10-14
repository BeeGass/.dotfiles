# ============================================================================
# Environment Variables
# ============================================================================

: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${DOTFILES_FLAGS_DIR:=$XDG_STATE_HOME/dotfiles/flags}"
is_termux() { [[ -e "$DOTFILES_FLAGS_DIR/IS_TERMUX" ]]; }

# GPU env (portable: NVIDIA, AMD, Termux/Android Adreno)
if command -v nvidia-smi >/dev/null 2>&1; then
  export BEEGASS_GPU_ENABLED=1 GPU_VENDOR=nvidia
elif command -v rocm-smi >/dev/null 2>&1; then
  export BEEGASS_GPU_ENABLED=1 GPU_VENDOR=amd
elif is_termux; then
  if [[ -c /dev/kgsl-3d0 ]] || getprop ro.hardware.vulkan >/dev/null 2>&1; then
    export BEEGASS_GPU_ENABLED=1 GPU_VENDOR=adreno
  else
    export BEEGASS_GPU_ENABLED=0 GPU_VENDOR=none
  fi
fi

# GPG/SSH agent (interactive shells only)
if [[ -o interactive ]] && command -v gpgconf >/dev/null 2>&1; then
  export GPG_TTY="$(tty 2>/dev/null || true)"
  gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  gpgconf --launch gpg-agent >/dev/null 2>&1 || true
fi

# Key IDs
export KEYID=0xA34200D828A7BB26
export S_KEYID=0xACC3640C138D96A2
export E_KEYID=0x21691AE75B0463CC
export A_KEYID=0x27D667E55F655FD2

# Node Version Manager (single place)
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"

# Path Configuration
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
if [[ -d "$HOME/.opencode/bin" ]]; then
  export PATH="$HOME/.opencode/bin:$PATH"
fi
# OS-specific Julia path
if [[ "$OSTYPE" == "darwin"* ]]; then
  export PATH="$HOME/.julia/juliaup/bin:$PATH"
else
  export PATH="$HOME/.julia/juliaup/bin:$PATH"
fi

# Editor
export EDITOR="nvim"
export VISUAL="nvim"
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000

# Quick Directory Bookmarks
hash -d projects=~/Projects
hash -d pm=~/Projects/PM
hash -d ludo=~/Projects/Ludo
hash -d ludie=~/Projects/ludie-ai
hash -d downloads=~/Downloads
hash -d docs=~/Documents
hash -d dots=~/.dotfiles
