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
    # Non-standard slots — registered as extras so xdg-user-dir can resolve them.
    extraConfig = {
      XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projects";
      XDG_PAPERS_DIR = "${config.home.homeDirectory}/Papers";
    };
  };

  # xdg.userDirs.createDirectories handles the standard slots; extras don't get
  # auto-created. Activate them explicitly.
  home.activation.createExtraUserDirs = lib.mkIf pkgs.stdenv.isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${config.home.homeDirectory}/Projects" "${config.home.homeDirectory}/Papers"
    ''
  );
}
