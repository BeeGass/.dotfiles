# Home-manager entry point.
# Imports base modules (shell, git, etc.) that work on ALL platforms.
# Desktop modules (niri, waybar, etc.) are in desktop.nix and imported
# separately by hosts that have a desktop environment.
{ ... }:
{
  imports = [
    # Base modules (cross-platform: Linux, macOS, headless servers)
    ./shell.nix
    ./prompt.nix
    ./environment.nix
    ./git.nix
    ./gpg.nix
    ./ssh.nix
    ./terminals.nix
    ./editor.nix
    ./tmux.nix
    ./cli-tools.nix
    ./dev-tools.nix
    ./fonts.nix
    ./xdg.nix
    ./claude.nix
    ./scripts.nix
    ./secrets.nix
  ];

  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}
