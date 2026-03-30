# Btrfs filesystem management -- snapshots, scrubbing, and maintenance
#
# Configures:
#   1. btrbk -- automated Btrfs snapshots with retention policies
#   2. A top-level Btrfs mount for snapshot access
#   3. Periodic scrubbing to detect and repair data corruption
#
# Expected subvolume layout (created during install):
#   @root   -> mounted at /
#   @home   -> mounted at /home
#   @nix    -> mounted at /nix
#   @swap   -> mounted at /swap (if applicable)
#
# btrbk snapshots are stored alongside the subvolumes on the same
# Btrfs filesystem. For off-site backups, configure btrbk send/receive
# targets separately.
{ config, lib, pkgs, ... }:

{
  # btrbk -- snapshot-based backup tool for Btrfs
  services.btrbk.instances.default = {
    # Run snapshots every hour via a systemd timer
    onCalendar = "hourly";

    settings = {
      # Minimum snapshot retention -- keep all snapshots for at least 2 days,
      # regardless of other retention rules.
      snapshot_preserve_min = "2d";

      # Retention policy:
      #   7d  -- keep one snapshot per day for 7 days
      #   4w  -- keep one snapshot per week for 4 weeks
      # Older snapshots beyond these windows are automatically deleted.
      snapshot_preserve = "7d 4w";

      # The Btrfs volume to snapshot. This is the top-level (subvolid=5)
      # mount, which gives btrbk access to all subvolumes.
      volume."/mnt/btrfs-root" = {
        # Snapshot the root subvolume (mounted at /)
        subvolume."@root" = {};

        # Snapshot the home subvolume (mounted at /home)
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
      "noatime"      # skip access time updates for better performance
    ];
  };

  # Periodic Btrfs scrub -- reads all data and metadata on the filesystem,
  # verifies checksums, and repairs corruption using redundant copies
  # (if available via RAID or DUP profiles).
  services.btrfs.autoScrub = {
    enable = true;

    # Monthly scrub interval -- balances thoroughness with disk I/O impact.
    # A full scrub of a 2TB NVMe drive typically takes 10-30 minutes.
    interval = "monthly";

    # Filesystems to scrub. Specifying "/" is sufficient -- Btrfs will
    # scrub the entire filesystem regardless of which mountpoint is given.
    fileSystems = [ "/" ];
  };
}
