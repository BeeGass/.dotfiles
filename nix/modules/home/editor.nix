# Neovim configuration.
# Sources vim/vimrc at runtime (not build time) so edits to the dotfile
# take effect on next nvim start without a home-manager rebuild.
# The vimrc uses vim-plug for plugins and Colemak-DH keybindings.
{ config, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraConfig = ''
      source ${config.home.homeDirectory}/.dotfiles/vim/vimrc
    '';
  };

  home.packages = [ pkgs.vim ];
}
