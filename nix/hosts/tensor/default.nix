# Tensor - Interim full workstation during the Manifold NixOS migration.
# Ryzen 9 3900X, 32GB RAM. GPU: RTX 3080 initially, RTX 5090 after Phase 11 transplant.
#
# Roles (per flake.nix): nvidia, cuda, datasets, niri, greetd, audio, steam,
# tailscale, flatpak, docker, filesystems-btrfs.
{ config, pkgs, vars, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "tensor";

  # Static IP — confirm interface name after first boot (likely enp* for PCIe Ethernet).
  # networking.interfaces.INTERFACE.ipv4.addresses = [{
  #   address = "192.168.68.11";
  #   prefixLength = 24;
  # }];

  system.stateVersion = "25.05";
}
