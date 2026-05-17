# Tensor - DECOMMISSIONED. Hardware (RTX Pro 6000, several SSDs) moved into
# Manifold. The flake.nix nixosConfigurations.tensor entry is commented out.
#
# This file is kept as a stub for potential reuse on a future host with the
# same hostname. Original spec: Ryzen 9 3900X, 32GB RAM, RTX 3080.
#
# Roles (per the commented flake entry): nvidia, cuda, datasets, niri,
# greetd, audio, steam, tailscale, flatpak, docker, filesystems-btrfs.
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
