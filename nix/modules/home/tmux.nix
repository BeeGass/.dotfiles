# Tmux configuration.
# Sources tmux/tmux.conf at runtime (not build time) so edits to the dotfile
# take effect on next `tmux source-file` without a home-manager rebuild.
{ config, pkgs, lib, ... }:
{
  programs.tmux = {
    enable = true;
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 10000;
    terminal = "tmux-256color";
    prefix = "C-Space";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      cpu
      resurrect
      continuum
      open
      sidebar
    ];

    extraConfig = ''
      source-file ${config.home.homeDirectory}/.dotfiles/tmux/tmux.conf
    '';
  };

  # Bootstrap TPM (tmux plugin manager)
  home.activation.installTpm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
  '';
}
