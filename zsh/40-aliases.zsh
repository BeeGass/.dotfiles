# ============================================================================
# 40-aliases.zsh — single source of truth for ls/bat/cat/etc.
# ============================================================================

# --- Helpers -----------------------------------------------------------------
_is_termux() {
  # Prefer explicit flag, then heuristics
  local flag_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/flags"
  [[ -f "$flag_dir/IS_TERMUX" ]] && return 0
  [[ -n "${TERMUX_VERSION-}" ]] && return 0
  [[ "${PREFIX-}" == *"com.termux"* ]] && return 0
  [[ "$(uname -o 2>/dev/null || true)" == "Android" ]] && return 0
  return 1
}

_is_macos() {
  local flag_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/flags"
  [[ -f "$flag_dir/IS_MACOS" ]] && return 0
  [[ "${OSTYPE-}" == darwin* ]] && return 0
  [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]] && return 0
  return 1
}

# --- Safer navigation ---------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# --- Editors / Dotfiles ------------------------------------------------------
alias n='nvim'
alias zshfig='nvim ~/.dotfiles/zsh/zshrc'
alias zshconfig='cd ~/.dotfiles && nvim'

# --- Security / GPG ----------------------------------------------------------
alias yubioath='ykman oath accounts list'
alias update-pin='export GPG_TTY=$(tty); gpg-connect-agent updatestartuptty /bye'
alias keyconfirm='gpg-connect-agent updatestartuptty /bye; export GPG_TTY=$(tty); export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket); gpgconf --launch gpg-agent; ssh-add -l'
alias gpgmesg='gpg -se -r recipient_userid'

# --- Bare "config" for managing $HOME as a repo (portable) -------------------
# Avoid alias/function collisions from frameworks or prior files.
unalias config 2>/dev/null || true
unset -f config 2>/dev/null || true
config() { command git --git-dir="$HOME/.cfg/" --work-tree="$HOME" "$@"; }

# --- UV / Python -------------------------------------------------------------
alias mkuv='uv venv'
alias activateuv='source .venv/bin/activate'
alias uvrun='uv run'
alias uvsync='uv sync'
alias uvlock='uv lock'
alias uvtool='uv tool'

# --- YubiKey helpers ---------------------------------------------------------
alias yk='yk-status'
alias yklock='yk-lock'

# --- Neofetch wrapper is defined in scripts; avoid alias/function conflicts ---
# If there's no `nf` command in PATH but the script exists, provide a soft alias.
if ! command -v nf >/dev/null 2>&1 && [[ -x "$HOME/.dotfiles/scripts/neofetch_random.sh" ]]; then
  alias nf="$HOME/.dotfiles/scripts/neofetch_random.sh"
fi

# --- Smart ls fallback: prefer eza → lsd → coreutils ls ----------------------
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --classify --group-directories-first'
  alias ll='eza -lgh --icons --group-directories-first'
  alias la='eza -lgha --icons --group-directories-first'
  alias lt='eza --tree --icons'
elif command -v lsd >/dev/null 2>&1; then
  alias ls='lsd --classify'
  alias ll='lsd -l --group-dirs=first'
  alias la='lsd -la --group-dirs=first'
  command -v tree >/dev/null 2>&1 && alias lt='tree -C'
else
  # Coreutils/BSD ls: color + sensible long/hidden variants
  if _is_macos; then
    alias ls='ls -G'
  else
    alias ls='ls --color=auto'
  fi
  alias ll='ls -l'
  alias la='ls -la'
  command -v tree >/dev/null 2>&1 && alias lt='tree -C'
fi

# --- cat → bat centralization (supports Debian's batcat) ---------------------
# Normalize "bat" command name
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
fi
# Make cat behave like cat (no pager, plain style) while using bat for niceties
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never --style=plain'
  : "${BAT_THEME:=TwoDark}"
  export BAT_THEME
fi

# --- Grep family (prefer ripgrep if available) -------------------------------
if command -v rg >/dev/null 2>&1; then
  alias grep='rg -n --color=auto'
  alias egrep='rg -n -E --color=auto'
  alias fgrep='rg -n -F --color=auto'
else
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# --- Termux-specific conveniences -------------------------------------------
if _is_termux; then
  export KEYTIMEOUT=1
  command -v termux-open >/dev/null 2>&1 && alias open='termux-open'
  command -v termux-clipboard-set  >/dev/null 2>&1 && alias clip='termux-clipboard-set'
  command -v termux-clipboard-get  >/dev/null 2>&1 && alias paste='termux-clipboard-get'
  # Conservative TERM tweak (only if empty or generic)
  if [[ -z "${TERM-}" || "${TERM-}" == "dumb" ]]; then
    export TERM='xterm-256color'
  fi
fi

# --- macOS-specific helpers --------------------------------------------------
if _is_macos; then
  # Tailscale CLI inside app bundle
  [[ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]] && \
    alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi
