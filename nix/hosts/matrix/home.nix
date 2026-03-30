# Matrix - macOS home-manager configuration
# Base modules imported by darwinModules.home-manager in flake.nix.
# This file only contains macOS-specific overrides.
{ config, pkgs, lib, vars, ... }:
{
  home.username = vars.username;
  home.homeDirectory = "/Users/${vars.username}";

  # macOS-specific packages (GNU coreutils for consistent CLI behavior)
  home.packages = with pkgs; [
    coreutils
    findutils
    gnugrep
    gnused
  ];

  # Homebrew paths
  home.sessionVariables = {
    HOMEBREW_PREFIX = "/opt/homebrew";
  };

  home.sessionPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];
}
