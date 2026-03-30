# Nix daemon settings: flakes, binary caches, garbage collection, nix-ld.
{ pkgs, ... }:
{
  # -- Core Nix Settings --
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];

    # Binary caches and their signing keys.
    substituters = [
      "https://cache.nixos.org"
      "https://niri.cachix.org"
      "https://cache.nixos-cuda.org"
      "https://cache.flox.dev"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "cache.nixos-cuda.org-1:DC0qO5MIvJksJVE4dYvz/2bMqEOIxIIS41mMjpJtMnI="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
  };

  # -- Unfree packages --
  nixpkgs.config.allowUnfree = true;

  # -- Garbage Collection --
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # -- nix-ld: run unpatched dynamic binaries --
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      openssl
      curl
      libGL
      glib
    ];
  };
}
