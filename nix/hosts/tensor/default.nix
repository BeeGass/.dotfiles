# Tensor - Secondary ML server
# Currently runs Ubuntu. This NixOS config is for future migration.
# RTX 3080, 32GB RAM
{ config, pkgs, vars, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "tensor";

  # Static IP (uncomment after first boot, set correct interface name)
  # networking.interfaces.INTERFACE.ipv4.addresses = [{
  #   address = "192.168.68.11";
  #   prefixLength = 24;
  # }];

  system.stateVersion = "25.05";
}
