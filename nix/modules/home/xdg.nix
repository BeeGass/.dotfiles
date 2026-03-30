# XDG base directories and user directories.
{ config, pkgs, lib, ... }:
{
  xdg.enable = true;

  # userDirs is Linux-only (uses xdg-user-dirs package)
  xdg.userDirs = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    createDirectories = true;
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
    music = "${config.home.homeDirectory}/Music";
    desktop = "${config.home.homeDirectory}/Desktop";
  };
}
