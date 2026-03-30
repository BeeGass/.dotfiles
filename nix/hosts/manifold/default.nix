{ config, pkgs, vars, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "manifold";

  # Static IP can be configured after first boot when interface name is known.
  # Use `ip link` to find the interface name (typically enp* for PCIe Ethernet).
  # networking.interfaces.INTERFACE.ipv4.addresses = [{
  #   address = "192.168.68.10";
  #   prefixLength = 24;
  # }];

  system.stateVersion = "25.05";
}
