# Neovim configuration.
# Loads the existing vimrc (534 lines) via extraConfig.
# The vimrc uses vim-plug for plugins and Colemak-DH keybindings.
{ config, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    # Relative path from this file (works regardless of home directory)
    extraConfig = builtins.readFile ../../../vim/vimrc;
  };

  home.packages = [ pkgs.vim ];
}
