# Tmux configuration.
# Loads the existing tmux.conf (432 lines) via extraConfig.
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

    extraConfig = builtins.readFile ../../../tmux/tmux.conf;
  };

  # Bootstrap TPM (tmux plugin manager)
  home.activation.installTpm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
  '';
}
