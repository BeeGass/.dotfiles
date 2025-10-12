# ============================================================================
# Environment Variables
# ============================================================================

# GPU env (portable: NVIDIA, AMD, Termux/Android Adreno)
if command -v nvidia-smi >/dev/null 2>&1; then
  export BEEGASS_GPU_ENABLED=1 GPU_VENDOR=nvidia
elif command -v rocm-smi >/dev/null 2>&1; then
  export BEEGASS_GPU_ENABLED=1 GPU_VENDOR=amd
elif [[ -n "${TERMUX_VERSION-}" || "${PREFIX-}" == *"com.termux"* ]]; then
  # Adreno usually exposes /dev/kgsl-3d0; Vulkan prop hints GPU availability
  if [[ -c /dev/kgsl-3d0 ]] || getprop ro.hardware.vulkan >/dev/null 2>&1; then
    export BEEGASS_GPU_ENABLED=1 GPU_VENDOR=adreno
  else
    export BEEGASS_GPU_ENABLED=0 GPU_VENDOR=none
  fi
fi

# GPG/GPG-Agent Configuration
if command -v gpgconf &> /dev/null; then
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    export GPG_TTY=$(tty)
    gpgconf --launch gpg-agent >/dev/null 2>&1 || true
fi
export KEYID=0xA34200D828A7BB26
export S_KEYID=0xACC3640C138D96A2
export E_KEYID=0x21691AE75B0463CC
export A_KEYID=0x27D667E55F655FD2

# Node Version Manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Path Configuration
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
if [ -d "$HOME/.opencode/bin" ]; then
  export PATH="$HOME/.opencode/bin:$PATH"
fi

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
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000

# Quick Directory Bookmarks
hash -d projects=~/Projects
hash -d pm=~/Projects/PM
hash -d ludo=~/Projects/Ludo
hash -d ludie=~/Projects/ludie-ai
hash -d downloads=~/Downloads
hash -d docs=~/Documents
hash -d dots=~/.dotfiles
