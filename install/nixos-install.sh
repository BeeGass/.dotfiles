#!/usr/bin/env bash
set -euo pipefail

cat <<'NIX'

[NixOS] Add this to configuration.nix, then: sudo nixos-rebuild switch

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    zsh tmux fzf ripgrep bat fd jq curl wget unzip git gh gnupg delta
    oh-my-posh
    zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search
    eza lsd nodejs
  ];

# Optional: Home Manager for per-user config
# home.packages = [
#   pkgs.uv
# ];

# After rebuild:
#   - Install uv:  curl -Ls https://astral.sh/uv/install.sh | sh && uv self update
#   - Install CLIs: npm i -g @google/gemini-cli@latest @anthropic-ai/claude-code@latest

NIX
