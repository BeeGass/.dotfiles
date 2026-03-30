# Boot configuration: systemd-boot, latest kernel.
# NVIDIA-specific kernel params are in optional/nvidia.nix (not here).
{ pkgs, ... }:
{
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 20;
    editor = false;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
}
