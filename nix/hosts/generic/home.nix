# Generic fallback configuration.
# Used for testing or unknown hosts. Minimal, works anywhere.
# Usage: home-manager switch --flake ~/.dotfiles#beegass
{ config, pkgs, vars, ... }:
{
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";
}
