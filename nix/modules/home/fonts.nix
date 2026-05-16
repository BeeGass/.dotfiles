# Font packages and fontconfig.
# Source-of-truth: fontconfig/30-google-sans-mono-mono.conf at repo root.
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    # Google Sans Mono: if not in nixpkgs, use the overlay in overlays/default.nix
  ];

  # Force Google Sans Mono to be recognized as monospaced — symlinked live.
  xdg.configFile."fontconfig/conf.d/30-google-sans-mono-mono.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/fontconfig/30-google-sans-mono-mono.conf";
}
