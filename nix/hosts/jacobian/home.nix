# Jacobian - RPi 5 (secrets server, backup)
# Standalone home-manager on Ubuntu (not NixOS).
# User: ubuntu
# Usage: home-manager switch --flake ~/.dotfiles#ubuntu@jacobian
#
# Base modules (shell, git, gpg, etc.) are imported by mkHome in flake.nix.
# This file only contains host-specific overrides.
{ config, pkgs, vars, ... }:
{
  home.username = "ubuntu";
  home.homeDirectory = "/home/ubuntu";
}
