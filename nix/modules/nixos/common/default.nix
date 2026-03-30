# Common NixOS modules imported by every host.
# Each sub-module receives `vars` from the top-level flake via specialArgs.
{ ... }:
{
  imports = [
    ./boot.nix
    ./nix-settings.nix
    ./networking.nix
    ./users.nix
    ./security.nix
    ./services.nix
  ];
}
