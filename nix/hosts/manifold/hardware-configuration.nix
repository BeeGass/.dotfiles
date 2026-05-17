# Manifold hardware/filesystem layout.
#
# This file mirrors the disk layout in docs/nixos/manifold-install-plan.md.
# All six drives are encoded here; the install plan covers Phase 0/A/B
# operational steps (data pre-migration, install, drop Ubuntu).
#
#   /boot      nvme0n1p1  vfat   (label NIXBOOT, 1 GiB)
#   system     nvme0n1p2  LUKS (partlabel cryptnixos) -> btrfs label `nixos`
#                         subvols: @root @home @nix @log
#                         (no @swap -- swap is zram-only)
#   /library   nvme1n1p1  btrfs  (label library, compress=zstd:1) -- T705 4 TB
#   /work      nvme2n1p1  btrfs  (label work,    compress=zstd:1) -- SN850X 2 TB
#   /cache     nvme3n1p1  btrfs  (label cache)                    -- 980 1 TB
#   /games     sdb1       ext4   (label games)                    -- 860 QVO 1 TB
#   /pad       sda1       ext4   (label pad)                      -- 750 EVO 250 GB
#
# Semantic model:
#   /library = read-mostly reference (datasets, HF cache, external models)
#   /work    = active outputs       (runs, checkpoints, logs, notes, projects)
#   /cache   = rebuildable          (docker, uv, pip, triton, jax, ccache)
#   /pad     = scratchpad           (ideas, scripts, probes, snippets)
#
# `boot.initrd.{availableKernelModules,kernelModules}` and the AMD microcode
# line are stubs replaced by `nixos-generate-config --root /mnt` output during
# install. The fileSystems block + LUKS device + swap config are authoritative
# and should be preserved when merging the generated probe.
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
    options = [ "subvol=@root" "compress=zstd" "noatime" "ssd" "space_cache=v2" ];
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

  # ESP
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
  };

  # Bulk filesystems (unencrypted; machine assumed physically secure)
  fileSystems."/library" = {
    device = "/dev/disk/by-label/library";
    fsType = "btrfs";
    options = [ "compress=zstd:1" "noatime" "nofail" ];
  };
  fileSystems."/work" = {
    device = "/dev/disk/by-label/work";
    fsType = "btrfs";
    options = [ "compress=zstd:1" "noatime" "nofail" ];
  };
  fileSystems."/cache" = {
    device = "/dev/disk/by-label/cache";
    fsType = "btrfs";
    options = [ "compress=zstd:1" "noatime" "nofail" ];
  };
  fileSystems."/games" = {
    device = "/dev/disk/by-label/games";
    fsType = "ext4";
    options = [ "noatime" "nofail" ];
  };
  fileSystems."/pad" = {
    device = "/dev/disk/by-label/pad";
    fsType = "ext4";
    options = [ "noatime" "nosuid" "nodev" "nofail" ];
  };

  # No disk swap -- zram-only. The 9100 PRO has an optional p3 reserved for
  # future disk swap (zram backing-device or plain swap) but is unused by
  # default.
  swapDevices = [ ];
  zramSwap.enable = true;

  hardware.cpu.amd.updateMicrocode = true;
}
