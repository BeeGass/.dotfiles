# Manifold hardware/filesystem layout.
#
# This file mirrors the disk layout in docs/nixos/manifold-install-plan.md:
#
#   /boot        nvme0n1p1  vfat (label NIXBOOT, 1 GiB)
#   /, /home,
#   /nix, /var/log,
#   /swap        nvme0n1p2  LUKS (partlabel cryptnixos) -> btrfs subvols
#                           (label nixos, subvols: @ @home @nix @log @swap)
#   /data        nvme1n1p1  XFS  (label data)   -- Crucial T705 4 TB
#   /srv/ml      nvme2n1p1  XFS  (label ml)     -- WD_BLACK SN850X 2 TB
#                           (with bind mounts at /models and /checkpoints)
#   /work        nvme3n1p1  XFS  (label work)   -- Samsung 980 1 TB
#   /games       sdb1       btrfs (label games, compress=zstd) -- 860 QVO
#   /rescue      sda1       ext4 (label rescue) -- 750 EVO
#
# `boot.initrd.{availableKernelModules,kernelModules}` and the AMD microcode
# line are stubs that will be replaced by `nixos-generate-config --root /mnt`
# output during install. The fileSystems block + LUKS device declaration are
# authoritative — preserve them when merging the generated probe.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];

  # LUKS device for the system Btrfs pool. Referenced by GPT PARTLABEL (set
  # via `sgdisk -c 2:cryptnixos` during install), not by filesystem label.
  boot.initrd.luks.devices.cryptroot.device = "/dev/disk/by-partlabel/cryptnixos";

  # System Btrfs (on the unlocked cryptroot mapper)
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd" "noatime" "ssd" "space_cache=v2" ];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" "ssd" "space_cache=v2" ];
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" "ssd" "space_cache=v2" ];
  };
  fileSystems."/var/log" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@log" "compress=zstd" "noatime" "ssd" "space_cache=v2" ];
  };
  fileSystems."/swap" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@swap" "noatime" "nodatacow" ];
  };

  # ESP
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
  };

  # Bulk filesystems (unencrypted; machine assumed physically secure)
  fileSystems."/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "xfs";
    options = [ "noatime" "nofail" ];
  };
  fileSystems."/srv/ml" = {
    device = "/dev/disk/by-label/ml";
    fsType = "xfs";
    options = [ "noatime" "nofail" ];
  };
  fileSystems."/models" = {
    device = "/srv/ml/models";
    options = [ "bind" ];
  };
  fileSystems."/checkpoints" = {
    device = "/srv/ml/checkpoints";
    options = [ "bind" ];
  };
  fileSystems."/work" = {
    device = "/dev/disk/by-label/work";
    fsType = "xfs";
    options = [ "noatime" "nofail" ];
  };
  fileSystems."/games" = {
    device = "/dev/disk/by-label/games";
    fsType = "btrfs";
    options = [ "compress=zstd" "noatime" "nofail" ];
  };
  fileSystems."/rescue" = {
    device = "/dev/disk/by-label/rescue";
    fsType = "ext4";
    options = [ "noatime" "nosuid" "nodev" "nofail" ];
  };

  # 32 GiB swapfile on the @swap subvol (created via `btrfs filesystem mkswapfile`
  # during install) + zram for additional in-memory swap. No hibernation.
  swapDevices = [ { device = "/swap/swapfile"; } ];
  zramSwap.enable = true;

  hardware.cpu.amd.updateMicrocode = true;
}
