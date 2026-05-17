# Btrfs filesystem management -- snapshots, scrubbing, and maintenance
#
# Configures:
#   1. btrbk -- automated Btrfs snapshots with retention policies
#   2. A top-level Btrfs mount for snapshot access
#   3. Periodic scrubbing to detect and repair data corruption
#
# Expected subvolume layout (created during install per
# docs/nixos/manifold-install-plan.md):
#   @root   -> mounted at /
#   @home   -> mounted at /home
#   @nix    -> mounted at /nix
#   @log    -> mounted at /var/log
#
# Swap is zram-only on this host; no @swap subvol, no swapfile.
#
# btrbk snapshots are stored alongside the subvolumes on the same
# Btrfs filesystem. For off-site backups, configure btrbk send/receive
# targets separately.
#
# This module covers ONLY the system Btrfs pool (label `nixos`) on the
# encrypted system drive. The /library, /work, /cache btrfs filesystems on
# the bulk drives are NOT snapshotted by this module — they hold rebuildable
# or external-source data, and snapshotting their volume of churn would be
# expensive. Add per-mount btrbk targets if a specific bulk subtree needs it.
{ config, lib, pkgs, ... }:

{
  # btrbk -- snapshot-based backup tool for Btrfs
  services.btrbk.instances.default = {
    onCalendar = "hourly";

    settings = {
      snapshot_preserve_min = "2d";
      snapshot_preserve = "7d 4w";

      # The Btrfs volume to snapshot. This is the top-level (subvolid=5)
      # mount, which gives btrbk access to all subvolumes.
      volume."/mnt/btrfs-root" = {
        subvolume."@root" = {};
        subvolume."@home" = {};
      };
    };
  };

  # Mount the top-level Btrfs volume (subvolid=5) so btrbk and
  # administrative tools can access all subvolumes and snapshots.
  # This is NOT the root filesystem -- it is a separate mountpoint
  # for management purposes only.
  fileSystems."/mnt/btrfs-root" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "subvolid=5"   # top-level volume (contains all subvolumes)
      "noatime"
    ];
  };

  # Periodic Btrfs scrub on the system pool.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
}
