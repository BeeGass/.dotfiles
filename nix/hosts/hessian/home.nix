# Hessian - RPi 5 (monitoring)
# Standalone home-manager on Ubuntu (not NixOS).
# User: ubuntu
# Usage: home-manager switch --flake ~/.dotfiles#ubuntu@hessian
{ config, pkgs, vars, ... }:
{
  home.username = "ubuntu";
  home.homeDirectory = "/home/ubuntu";
}
