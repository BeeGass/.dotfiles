# Complete Zsh configuration.
# Translates: zsh/00-init.zsh through zsh/90-local.zsh (all 12 files)
#
# NOTE: source-of-truth duplication with ../../../zsh/*.zsh pending refactor.
# Edits to ../../../zsh/* will NOT take effect on NixOS until the dead-source-files
# refactor lands. For now, edit this file directly for zsh changes on NixOS;
# the ../../../zsh/* files remain canonical for the imperative installer
# (macOS, RPi, Termux). See: docs/nixos/manifold-migration-plan.md Phase 2.6.
{ config, pkgs, lib, vars, ... }:
{
  programs.zsh = {
    enable = true;

    # Plugins (replaces zsh/30-plugins.zsh)
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    # History (replaces zsh/00-init.zsh)
    history = {
      size = 100000;
      save = 100000;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      share = true;
      extended = true;
    };

    # Vi mode (replaces zsh/70-keybindings.zsh)
    defaultKeymap = "viins";

    # Aliases (replaces zsh/40-aliases.zsh)
    # Only NixOS-relevant aliases (Termux/macOS-specific dropped)
    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      cp = "cp -i";
      mv = "mv -i";
      rm = "rm -i";

      n = "nvim";
      zshfig = "nvim ~/.dotfiles/zsh/zshrc";
      zshconfig = "cd ~/.dotfiles && nvim";

      yubioath = "ykman oath accounts list";
      "update-pin" = "export GPG_TTY=$(tty); gpg-connect-agent updatestartuptty /bye";
      keyconfirm = "gpg-connect-agent updatestartuptty /bye; export GPG_TTY=$(tty); export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket); gpgconf --launch gpg-agent; ssh-add -l";

      mkuv = "uv venv";
      activateuv = "source .venv/bin/activate";
      uvrun = "uv run";
      uvsync = "uv sync";
      uvlock = "uv lock";
      uvtool = "uv tool";

      nvtop = "uv run --project ~/.dotfiles/scripts/zen-nv zen-nv";
      zennv = "uv run --project ~/.dotfiles/scripts/zen-nv zen-nv";

      yk = "yk-status";
      yklock = "yk-lock";

      ls = "eza --classify --group-directories-first";
      ll = "eza -lgh --icons --group-directories-first";
      la = "eza -lgha --icons --group-directories-first";
      lt = "eza --tree --icons";

      cat = "bat --paging=never --style=plain";

      grep = "rg -n --color=auto";
    };

    # Environment (replaces zsh/zshenv)
    envExtra = ''
      : "''${XDG_CONFIG_HOME:=$HOME/.config}"
      : "''${XDG_DATA_HOME:=$HOME/.local/share}"
      : "''${XDG_STATE_HOME:=$HOME/.local/state}"
      : "''${XDG_CACHE_HOME:=$HOME/.cache}"
      export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME

      typeset -U path PATH

      [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
    '';

    # Completion config (replaces zsh/60-completions.zsh)
    initExtraBeforeCompInit = ''
      zstyle ':completion:*' menu select
      zstyle ':completion:*:*:*:*:*' menu select
      zstyle ':completion:*:matches' group 'yes'
      zstyle ':completion:*:options' description 'yes'
      zstyle ':completion:*:options' auto-description '%d'
      zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
      zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
      zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
      zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
      zstyle ':completion:*:default' list-prompt '%S%M matches%s'
      zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
      zstyle ':completion:*' group-name ""
      zstyle ':completion:*' verbose yes
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' list-suffixes
      zstyle ':completion:*' expand prefix suffix
      zmodload zsh/complist
    '';

    # Everything else (replaces 00-init, 20-env, 50-functions, 60-claude, 70-keys, 80-tools, 90-local)
    initExtra = ''
      # GPU probe (from 00-init.zsh)
      if command -v nvidia-smi >/dev/null 2>&1; then
        export BEEGASS_GPU_ENABLED=1
        export GPU_VENDOR=nvidia
      fi

      # Banner (from 00-init.zsh)
      if [[ -o interactive ]]; then
        if command -v pfetch >/dev/null 2>&1; then
          pfetch
        elif command -v fastfetch >/dev/null 2>&1; then
          fastfetch
        elif command -v neofetch >/dev/null 2>&1; then
          neofetch
        else
          print -P "%F{cyan}%n@%m%f  %D{%a %b %d, %I:%M %p}  %~"
        fi
      fi

      export CLICOLOR=1

      # GPG/SSH agent (from 20-environment.zsh)
      if [[ -o interactive ]] && command -v gpgconf >/dev/null 2>&1; then
        export GPG_TTY="$(tty 2>/dev/null || true)"
        gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
        export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
      fi

      # Key IDs (from 20-environment.zsh)
      export KEYID="${vars.gpgKeys.master}"
      export S_KEYID="${vars.gpgKeys.signing}"
      export E_KEYID="${vars.gpgKeys.encryption}"
      export A_KEYID="${vars.gpgKeys.authentication}"

      # NVM (from 20-environment.zsh)
      export NVM_DIR="$HOME/.nvm"
      [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

      # Directory bookmarks (from 20-environment.zsh)
      hash -d projects=~/Projects
      hash -d downloads=~/Downloads
      hash -d docs=~/Documents
      hash -d dots=~/.dotfiles

      # Functions (from 50-functions.zsh)
      uvnew() {
        if [ -z "$1" ]; then
          echo "Usage: uvnew <project-name> [python-version]"
          return 1
        fi
        local project_name="$1"
        local python_version="''${2:-3.11}"
        mkdir -p "$project_name" && cd "$project_name"
        uv init && uv venv --python "$python_version"
        echo "Created new uv project: $project_name with Python $python_version"
      }

      uvsetup() {
        if [ -f "pyproject.toml" ]; then
          uv sync && source .venv/bin/activate
          echo "Dependencies installed and virtual environment activated"
        else
          echo "No pyproject.toml found in current directory"
          return 1
        fi
      }

      uvupgrade() {
        if [ -f "pyproject.toml" ]; then
          uv sync --all-extras && uv lock --upgrade
          echo "Dependencies upgraded and synced with all extras"
        else
          echo "No pyproject.toml found in current directory"
          return 1
        fi
      }

      allbranches() {
        git for-each-ref --format='%(refname:short)' refs/remotes | \
        while read remote; do
          git switch --create "''${remote#origin/}" --track "$remote" 2>/dev/null
        done
      }

      gpgmsg() {
        if [ -z "$1" ]; then echo "Usage: gpgmsg <recipient_email>"; return 1; fi
        gpg -se -r "$1"
      }

      load-secrets() {
        local script="''${DOTFILES_DIR:-$HOME/.dotfiles}/scripts/load-secrets.sh"
        if [[ ! -x "$script" ]]; then
          script="$(command -v load-secrets 2>/dev/null || true)"
        fi
        if [[ -z "$script" ]]; then echo "load-secrets not found" >&2; return 1; fi
        if [[ "''${1:-}" == --* ]]; then
          bash "$script" "$@"
        else
          eval "$(bash "$script")"
        fi
      }

      sfssh()    { command sf vms ssh -A "$@"; }
      sftunnel() { command sftunnel "$@"; }
      config()   { command git --git-dir="$HOME/.cfg/" --work-tree="$HOME" "$@"; }

      # Claude functions (from 60-claude.zsh)
      [[ -f ~/.dotfiles/claude/claude-functions.zsh ]] && source ~/.dotfiles/claude/claude-functions.zsh
      export CLAUDE_PROJECT_ROOT="''${HOME}/Projects"
      export CLAUDE_PYTHON_VERSION="3.13"
      export UV_PYTHON_PREFERENCE="only-managed"

      # Keybindings (from 70-keybindings.zsh)
      bindkey '^S' history-incremental-search-forward
      if zle -l | grep -q '^history-substring-search-up$'; then
        bindkey '^[[A' history-substring-search-up
        bindkey '^[[B' history-substring-search-down
        bindkey '^P' history-substring-search-up
        bindkey '^N' history-substring-search-down
      fi

      # UV completions (from 80-tools.zsh)
      if command -v uv &> /dev/null; then
        eval "$(uv generate-shell-completion zsh 2>/dev/null)" || true
      fi

      # Delta pager (from 80-tools.zsh)
      if command -v delta &> /dev/null; then
        export GIT_PAGER='delta'
      fi

      # Local overrides (from 90-local.zsh)
      [[ -r ~/.zsh_local ]] && source ~/.zsh_local
    '';
  };
}
