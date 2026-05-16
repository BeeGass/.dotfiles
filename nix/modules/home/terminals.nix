# Terminal emulator configurations.
# Source-of-truth lives in ghostty/, kitty/, wezterm/ at the repo root.
# All three are symlinked via mkOutOfStoreSymlink so edits are live without
# a home-manager rebuild.
{ config, pkgs, lib, ... }:
{
  # Ghostty from nixpkgs on Linux; on macOS it's installed via Homebrew cask
  home.packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.ghostty ];

  xdg.configFile."ghostty/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/ghostty/config";

  xdg.configFile."kitty/kitty.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/kitty/kitty.conf";

  xdg.configFile."wezterm/wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/wezterm/wezterm.lua";
}
