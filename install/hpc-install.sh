#!/usr/bin/env bash
# Headless shared-cluster bootstrap (no sudo, no GUI, no system packages).
# Installs user-space tools to ~/.local/bin and links dotfile configs.
set -euo pipefail
source "${BASH_SOURCE[0]%/*}/lib.sh"

# Force no-sudo mode (shared clusters never have it)
NO_SUDO=1
export NO_SUDO

# ============================================================================
# Config
# ============================================================================

LOCAL_BIN="$HOME/.local/bin"
PLUG_DIR="$HOME/.zsh/plugins"

# Packages to install from cargo (only if missing)
CARGO_PKGS=(bat fd-find ripgrep delta eza)

# ============================================================================
# Helpers
# ============================================================================

ensure_local_bin() {
    mkdir -p "$LOCAL_BIN"
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        export PATH="$LOCAL_BIN:$PATH"
    fi
}

# Try to make zsh the login shell; fall back to chsh, then .profile stub
set_default_shell() {
    local zsh_bin
    zsh_bin="$(command -v zsh 2>/dev/null || true)"
    [[ -z "$zsh_bin" ]] && { warn "zsh not found; skipping default-shell setup"; return; }

    # Already the default?
    if [[ "${SHELL:-}" == *zsh ]]; then
        note "Default shell is already zsh"
        return
    fi

    # Try chsh (often denied on shared clusters)
    if chsh -s "$zsh_bin" 2>/dev/null; then
        ok "Changed login shell to $zsh_bin"
        return
    fi

    # Fallback: exec zsh from .profile / .bash_profile so SSH sessions drop
    # into zsh even when login shell is forced to bash.
    local profile="$HOME/.bash_profile"
    local marker="# >>> dotfiles-zsh-exec >>>"
    if ! grep -Fq "$marker" "$profile" 2>/dev/null; then
        step "Adding zsh exec stub to $profile"
        cat >> "$profile" <<EOF

$marker
if [[ -x "$zsh_bin" && -z "\${ZSH_EXEC_GUARD:-}" ]]; then
    export ZSH_EXEC_GUARD=1
    exec "$zsh_bin" -l
fi
# <<< dotfiles-zsh-exec <<<
EOF
        ok "Login sessions will exec into zsh"
    else
        note "zsh exec stub already present in $profile"
    fi
}

# ============================================================================
# Sections
# ============================================================================

install_zsh() {
    section "[HPC] Zsh"

    if have zsh; then
        ok "zsh already available: $(zsh --version 2>/dev/null | head -1)"
    else
        # Some clusters expose zsh via environment modules
        if have module; then
            step "Trying 'module load zsh'"
            module load zsh 2>/dev/null || true
        fi
        if ! have zsh; then
            warn "zsh not found; some shell features will be unavailable"
            warn "Ask your sysadmin to install zsh, or build from source:"
            note "  ./configure --prefix=\$HOME/.local && make -j\$(nproc) && make install"
            return
        fi
    fi

    set_default_shell
}

setup_symlinks() {
    section "[HPC] Dotfile symlinks"

    # Core shell
    create_symlink "$DOTFILES_DIR/zsh/zshenv"      "$HOME/.zshenv"
    create_symlink "$DOTFILES_DIR/zsh/zshrc"        "$HOME/.zshrc"

    # Editor (vim only; neovim is rarely available on shared clusters)
    create_symlink "$DOTFILES_DIR/vim/vimrc"        "$HOME/.vimrc"

    # Git
    create_symlink "$DOTFILES_DIR/git/gitconfig"    "$HOME/.gitconfig"

    # Tmux
    create_symlink "$DOTFILES_DIR/tmux/tmux.conf"   "$HOME/.tmux.conf"

    # Oh-My-Posh config
    if [[ -f "$DOTFILES_DIR/oh-my-posh/config.json" ]]; then
        create_symlink "$DOTFILES_DIR/oh-my-posh/config.json" \
            "$HOME/.config/oh-my-posh/config.json"
    fi

    # Link install/refresh scripts
    create_symlink "$DOTFILES_DIR/install/install.sh"   "$LOCAL_BIN/dots-install"
    create_symlink "$DOTFILES_DIR/install/refresh.sh"   "$LOCAL_BIN/dots-refresh"
    create_symlink "$DOTFILES_DIR/install/bootstrap.sh" "$LOCAL_BIN/dots-bootstrap"
    create_symlink "$DOTFILES_DIR/install/clean.sh"     "$LOCAL_BIN/dots-clean"

    ok "Symlinks created"
}

install_user_tools() {
    section "[HPC] User-space tools"

    # uv (Python)
    if ! have uv; then
        step "Installing uv"
        curl -Ls https://astral.sh/uv/install.sh | sh
        ensure_local_bin
    fi
    ok "uv: $(uv --version 2>/dev/null || echo 'installed')"

    # Python versions via uv
    local UV_BIN
    UV_BIN="$(command -v uv || echo "$LOCAL_BIN/uv")"
    step "Installing Python toolchain"
    "$UV_BIN" python install 3.11 3.12 3.13 || true

    # Python CLI tools
    "$UV_BIN" tool install ruff 2>/dev/null || true
    "$UV_BIN" tool install mypy 2>/dev/null || true
    "$UV_BIN" tool install pytest 2>/dev/null || true

    # oh-my-posh (single binary prompt)
    if ! have oh-my-posh; then
        step "Installing oh-my-posh"
        curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$LOCAL_BIN"
    fi
    ok "oh-my-posh: $(oh-my-posh --version 2>/dev/null || echo 'installed')"

    # Rust toolchain (needed for cargo packages)
    if ! have cargo; then
        step "Installing Rust via rustup"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        source "$HOME/.cargo/env" 2>/dev/null || true
    fi
    ok "cargo: $(cargo --version 2>/dev/null || echo 'installed')"

    # Cargo packages (bat, fd, rg, delta, eza)
    for pkg in "${CARGO_PKGS[@]}"; do
        local bin_name="$pkg"
        # Map crate names to binary names
        case "$pkg" in
            fd-find) bin_name="fd" ;;
            ripgrep) bin_name="rg" ;;
            git-delta|delta) bin_name="delta" ;;
        esac
        if ! have "$bin_name"; then
            step "Installing $pkg via cargo"
            cargo install "$pkg" 2>/dev/null || warn "Failed to install $pkg"
        else
            note "$bin_name already available"
        fi
    done

    # fzf
    if ! have fzf; then
        step "Installing fzf"
        if [[ -d "$HOME/.fzf" ]]; then
            git -C "$HOME/.fzf" pull --ff-only || true
        else
            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        fi
        "$HOME/.fzf/install" --bin --no-update-rc --no-key-bindings --no-completion
        ln -sf "$HOME/.fzf/bin/fzf" "$LOCAL_BIN/fzf"
    fi
    ok "fzf: $(fzf --version 2>/dev/null | head -1 || echo 'installed')"
}

install_zsh_plugins() {
    section "[HPC] Zsh plugins"
    mkdir -p "$PLUG_DIR"

    if [[ ! -d "$PLUG_DIR/zsh-autosuggestions" ]]; then
        step "Cloning zsh-autosuggestions"
        git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
            "$PLUG_DIR/zsh-autosuggestions"
    else
        note "zsh-autosuggestions already present"
    fi

    if [[ ! -d "$PLUG_DIR/zsh-syntax-highlighting" ]]; then
        step "Cloning zsh-syntax-highlighting"
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
            "$PLUG_DIR/zsh-syntax-highlighting"
    else
        note "zsh-syntax-highlighting already present"
    fi

    ok "Zsh plugins ready"
}

install_tmux() {
    section "[HPC] tmux + plugins"

    if ! have tmux; then
        if have module; then
            step "Trying 'module load tmux'"
            module load tmux 2>/dev/null || true
        fi
    fi

    if ! have tmux; then
        warn "tmux not found; skipping plugin setup"
        note "Ask your sysadmin to install tmux, or build from source"
        return
    fi

    ok "tmux: $(tmux -V 2>/dev/null || echo 'available')"

    # TPM
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        step "Installing Tmux Plugin Manager"
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "TPM plugin install failed; run prefix+I in tmux"
    else
        note "TPM already installed"
    fi
}

setup_git_identity() {
    section "[HPC] Git identity"

    if ! git config --global user.name >/dev/null 2>&1; then
        read -r -p "  Enter Git username: " git_user_name
        git config --global user.name "$git_user_name"
    fi
    if ! git config --global user.email >/dev/null 2>&1; then
        read -r -p "  Enter Git email: " git_user_email
        git config --global user.email "$git_user_email"
    fi

    # Cache credentials (no system keyring on HPC)
    git config --global credential.helper 'cache --timeout=7200'

    ok "Git identity configured"
}

setup_local_overrides() {
    section "[HPC] Local overrides"

    local zsh_local="$DOTFILES_DIR/zsh/90-local.zsh"
    if [[ -f "$zsh_local" ]]; then
        note "90-local.zsh already exists (left unchanged)"
        return
    fi

    step "Creating HPC-specific 90-local.zsh"
    umask 077
    cat > "$zsh_local" <<'LOCALEOF'
# Local Machine Settings (HPC cluster)
# This file is NOT tracked by git. Edit freely for site-specific config.

# ==============================================================================
# Environment Modules
# ==============================================================================
# Uncomment and adjust for your cluster's module system:
# if [[ -f /etc/profile.d/modules.sh ]]; then
#     source /etc/profile.d/modules.sh
# fi
# module load git tmux cuda 2>/dev/null || true

# ==============================================================================
# Conda / Mamba (if available via modules)
# ==============================================================================
# module load conda 2>/dev/null || true
# if command -v conda &>/dev/null; then
#     eval "$(conda shell.zsh hook)"
# fi

# ==============================================================================
# Slurm Aliases
# ==============================================================================
if command -v squeue &>/dev/null; then
    alias sq='squeue -u $USER'
    alias si='sinfo'
    alias sj='sacct -j'
    alias myq='squeue -u $USER -o "%.8i %.10P %.30j %.8T %.10M %.6D %R"'
fi

# ==============================================================================
# GPU / CUDA
# ==============================================================================
# Uncomment if CUDA is available:
# export CUDA_HOME="/usr/local/cuda"
# export PATH="$CUDA_HOME/bin:$PATH"
# export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

# ==============================================================================
# Scratch / Work Directories
# ==============================================================================
# export SCRATCH="/scratch/$USER"
# export WORK="/work/$USER"

# ==============================================================================
# API Keys
# ==============================================================================
# export HF_TOKEN="__SET_ME_SECURELY__"
LOCALEOF
    chmod 600 "$zsh_local"
    ok "Created $zsh_local with HPC template"
}

write_os_flags() {
    section "[HPC] OS flags"
    mkdir -p "$FLAGS_DIR"
    rm -f "$FLAGS_DIR"/{IS_*,termux,linux,macos,unknown,hpc} 2>/dev/null || true
    :> "$FLAGS_DIR/linux"
    :> "$FLAGS_DIR/IS_LINUX"
    :> "$FLAGS_DIR/hpc"
    :> "$FLAGS_DIR/IS_HPC"
    ok "OS flags written (Linux + HPC)"
}

# ============================================================================
# Main
# ============================================================================

main() {
    section "Headless Cluster Bootstrap"
    step "Repo: $DOTFILES_DIR"
    step "Tools install to: $LOCAL_BIN"

    ensure_local_bin
    write_os_flags
    install_zsh
    setup_symlinks
    install_user_tools
    install_zsh_plugins
    install_tmux
    setup_git_identity
    setup_local_overrides

    section "Done"
    step "Open a new shell or run: source ~/.zshrc"
    step "Edit ~/.dotfiles/zsh/90-local.zsh for cluster-specific modules/paths"
}

main "$@"
