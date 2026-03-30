# User accounts and shell configuration.
{ pkgs, vars, ... }:
{
  # -- Primary user --
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "video"
      "docker"
      "networkmanager"
      "input"
    ];
  };

  # Default shell for new users and login
  users.defaultUserShell = pkgs.zsh;

  # Zsh must be enabled system-wide so NixOS adds it to /etc/shells.
  programs.zsh.enable = true;

  # Allow wheel group to sudo without a password.
  security.sudo.wheelNeedsPassword = false;
}
