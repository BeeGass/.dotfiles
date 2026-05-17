# NixOS install on Manifold — disk layout & phased migration

## Context

Tensor is being decommissioned. Its RTX PRO 6000 Blackwell GPU and several SSDs are now in Manifold. Manifold currently boots Ubuntu 25.10 on the WD_BLACK SN850X (`nvme2n1`). The goal is to land on NixOS as the primary Linux, with a multi-drive layout that maps workload to the right tier of storage — **capacity where it's needed, encryption where it matters, and each drive in a role that matches its quality.** Ubuntu is preserved temporarily for dual-boot during the transition, then removed.

Key principles (refined through iteration):
- **Capacity > peak speed for `/data`** — datasets grow, and 14,100 vs 14,700 MB/s is meaningless when neither workload saturates either drive. T705 (4 TB) belongs on `/data`, not on `/`.
- **Don't underuse the mid-tier NVMe** — the Samsung 980 (PCIe 3.0, 1 TB) is too fast for cold archive; assign it to `/work` (containers, VMs, builds, scratch) where its speed matters and the data is rebuildable.
- **Don't overuse the bottom tier** — the 750 EVO (SATA, 250 GB) is rescue/staging only, not primary `/scratch`.

## Decisions (locked)

- **System filesystem:** LUKS → btrfs with subvols (`@`, `@home`, `@nix`, `@log`, `@swap`). No `/persist` for now — impermanence may come later.
- **Bulk filesystems:** XFS for `/data`, `/srv/ml`, `/work` (large files, high throughput, no need for snapshots there).
- **Games:** btrfs on the QVO with `compress=zstd`.
- **Encryption:** **System drive only (LUKS).** Everything else unencrypted for simplicity. Machine assumed physically secure. (Revisit `/work` encryption once it actually holds container/VM secrets — see Open items.)
- **Swap:** 32 GB swapfile on the `@swap` subvol + zram. No hibernation.
- **Bootloader:** systemd-boot on a new 1 GB ESP on the 9100 PRO. Ubuntu's existing ESP on `nvme2n1p1` is left untouched during Phase A; its UEFI entry is removed in Phase B.
- **Dual-boot mechanism:** UEFI firmware boot menu, not GRUB chain-loading.
- **`/models` + `/checkpoints`:** one XFS filesystem on the SN850X mounted at `/srv/ml`, exposed at `/models` and `/checkpoints` via bind mounts.
- **`nvme3n1` (Samsung 980):** wiped and used as `/work` (containers, VMs, builds, scratch, staging).
- **`sda` (750 EVO):** wiped and used as `/rescue` (ISOs, transfer staging, low-trust ad-hoc storage).
- **NVIDIA driver:** `hardware.nvidia.open = true` — Blackwell mandates open kernel modules.
- **LUKS device reference:** `/dev/disk/by-partlabel/cryptnixos` (GPT partition label), not `/dev/disk/by-label` (which is the inner filesystem label).

## Final layout

| Mount | Device | Model | FS | Encrypted |
|---|---|---|---|---|
| `/boot` | `nvme0n1p1` | Samsung 9100 PRO 2 TB (PCIe 5.0) | vfat (1 GiB), label `NIXBOOT` | no |
| `/`, `/home`, `/nix`, `/var/log`, `/swap` | `nvme0n1p2` | Samsung 9100 PRO 2 TB | LUKS (partlabel `cryptnixos`) → btrfs (label `nixos`, subvols `@`/`@home`/`@nix`/`@log`/`@swap`) | **yes** |
| `/data` | `nvme1n1p1` | **Crucial T705 4 TB (PCIe 5.0)** | XFS, label `data` | no |
| `/srv/ml` → `/models`, `/checkpoints` | `nvme2n1p1` | WD_BLACK SN850X 2 TB (PCIe 4.0) | XFS, label `ml`, bind mounts | no |
| `/work` | `nvme3n1p1` | Samsung 980 1 TB (PCIe 3.0) | XFS, label `work` | no (revisit) |
| `/games` | `sdb1` | Samsung 860 QVO 1 TB (SATA) | btrfs, label `games`, `compress=zstd` | no |
| `/rescue` | `sda1` | Samsung 750 EVO 250 GB (SATA) | ext4, label `rescue` | no |

All NixOS `fileSystems.*` entries use `/dev/disk/by-label/<label>` (or `by-partlabel` for the LUKS device) — drives can be reseated without reconfig.

## Directory policy (post-install)

```
/data/datasets          /models/hf                  /work/docker
/data/hf-cache          /models/ollama              /work/containers
/data/tokenized         /models/llama.cpp           /work/vms
/data/corpora           /models/vllm                /work/build
/data/benchmarks        /models/checkpoints-imported /work/scratch
                                                    /work/downloads
/checkpoints/runs                                   /work/staging
/checkpoints/sweeps                                 /work/cache
/checkpoints/manual

/rescue/isos
/rescue/staging
```

Environment variables (in `home-manager` or shell rc):
```sh
export HF_HOME=/data/hf-cache
export HF_HUB_CACHE=/data/hf-cache/hub
export TRANSFORMERS_CACHE=/data/hf-cache
export DATASETS_ROOT=/data/datasets
export MODELS_ROOT=/models
export CHECKPOINTS_ROOT=/checkpoints
export SCRATCH_ROOT=/work/scratch
```

## Critical ordering wrinkle

The 9100 PRO currently holds `/data` (122 GB: `freectrl`, `huggingface_cache`, `mqar`, `ppm`) under Ubuntu. Putting NixOS root there means **`/data` must be migrated off it before the install touches the drive.** Three-copy safety during the risky step:

1. Original on 9100 PRO (untouched until A.2 wipe)
2. Working copy on Crucial T705 (becomes the new `/data`)
3. Insurance archive on the Samsung 980 (formatted early as its final `/work` filesystem)

**T7 Shield is explicitly out of scope** — it holds business documents and is not touched by any step of this plan. The insurance copy lives on the Samsung 980 instead. Setting up the 980 in Phase 0 (rather than Phase B) means it serves double duty: backup target now, `/work` mount on first NixOS boot.

---

## Phase 0 — Pre-migration of `/data` (still running Ubuntu)

### P0.1 Partition + format the Crucial T705 as the future `/data`
```sh
sudo sgdisk --zap-all /dev/nvme1n1
sudo wipefs -a /dev/nvme1n1
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:data /dev/nvme1n1
sudo mkfs.xfs -L data /dev/nvme1n1p1
```

### P0.2 Partition + format the Samsung 980 as the future `/work` (insurance copy lives here first)
```sh
sudo sgdisk --zap-all /dev/nvme3n1
sudo wipefs -a /dev/nvme3n1
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:work /dev/nvme3n1
sudo mkfs.xfs -L work /dev/nvme3n1p1
```

### P0.3 Insurance backup to the Samsung 980
XFS supports full POSIX semantics, so `rsync -aHAX` preserves everything cleanly.
```sh
sudo mkdir -p /mnt/work
sudo mount /dev/disk/by-label/work /mnt/work
sudo mkdir -p /mnt/work/migration-backup-$(date +%F)
sudo rsync -aHAXxv --info=progress2 /data/ /mnt/work/migration-backup-$(date +%F)/
sync
```

### P0.4 Copy `/data` to new T705
```sh
sudo mkdir -p /mnt/new-data
sudo mount /dev/disk/by-label/data /mnt/new-data
sudo rsync -aHAXxv --info=progress2 /data/ /mnt/new-data/
sync
```

### P0.5 Verify byte-for-byte (all three copies match)
```sh
sudo du -sb /data /mnt/new-data /mnt/work/migration-backup-$(date +%F)
sudo diff -qr /data /mnt/new-data | head -20    # should be empty
sudo diff -qr /data /mnt/work/migration-backup-$(date +%F) | head -20    # should be empty
```

### P0.6 Switch Ubuntu's `/data` to the new drive
- Edit Ubuntu's `/etc/fstab`: replace the `nvme0n1p1` line with `LABEL=data /data xfs defaults,noatime 0 2`
- `sudo umount /data && sudo umount /mnt/new-data && sudo umount /mnt/work && sudo mount /data`
- Confirm `findmnt /data` shows `/dev/nvme1n1p1` and the four subdirs are present
- **Reboot once** and confirm `/data` mounts cleanly from the T705
- Original data on `nvme0n1` is now orphaned but intact — wiped in A.2
- The insurance copy on the 980 stays in place until Phase B verification (B.6) confirms NixOS is solid, then `rm -rf /work/migration-backup-*`

---

## Phase A — Install NixOS on 9100 PRO (dual-boot with Ubuntu)

### A.1 Boot the installer
Boot from `sdc` (SanDisk USB, `nixos-graphical-25.11-x86_64`) via UEFI boot menu. Open a root terminal.

### A.2 Wipe + partition the 9100 PRO
```sh
sgdisk --zap-all /dev/nvme0n1
wipefs -a /dev/nvme0n1
sgdisk -n 1:0:+1G -t 1:EF00 -c 1:NIXBOOT    /dev/nvme0n1
sgdisk -n 2:0:0   -t 2:8309 -c 2:cryptnixos /dev/nvme0n1
```

### A.3 LUKS + btrfs + subvols
```sh
mkfs.vfat -F32 -n NIXBOOT /dev/nvme0n1p1

cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot
mkfs.btrfs -L nixos /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@swap
umount /mnt
```

### A.4 Mount everything under `/mnt`
```sh
MNTOPTS="compress=zstd,noatime,ssd,space_cache=v2"
mount -o $MNTOPTS,subvol=@      /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,var/log,swap,boot,data}
mount -o $MNTOPTS,subvol=@home  /dev/mapper/cryptroot /mnt/home
mount -o $MNTOPTS,subvol=@nix   /dev/mapper/cryptroot /mnt/nix
mount -o $MNTOPTS,subvol=@log   /dev/mapper/cryptroot /mnt/var/log
mount -o noatime,nodatacow,subvol=@swap /dev/mapper/cryptroot /mnt/swap

mount /dev/nvme0n1p1 /mnt/boot
mount /dev/disk/by-label/data /mnt/data
mkdir -p /mnt/work
mount /dev/disk/by-label/work /mnt/work
```

### A.5 Swapfile (btrfs-aware)
```sh
btrfs filesystem mkswapfile --size 32g /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
```

### A.6 Generate base config
```sh
nixos-generate-config --root /mnt
```

### A.7 Edit `/mnt/etc/nixos/configuration.nix`
See snippets below. Critical bits:
- systemd-boot
- LUKS device by **partlabel**, not by `/dev/disk/by-label`
- `hardware.nvidia.open = true` for Blackwell
- All filesystem entries (`/`, `/home`, `/nix`, `/var/log`, `/swap`, `/boot`, `/data`, `/work`)
- Swap + zram
- User account, hostname `manifold`, flakes

### A.8 Install + reboot
```sh
nixos-install
reboot
```
At POST, pick **NixOS** from the UEFI boot menu. Confirm Ubuntu still boots from the same menu.

### A.9 Phase A smoke-test
- `nvidia-smi` sees the RTX PRO 6000
- LUKS prompts at boot, only once (for `cryptroot`)
- `findmnt /data` shows T705 (label `data`); `findmnt /work` shows the 980 (label `work`)
- All four subdirs (`freectrl`, `huggingface_cache`, `mqar`, `ppm`) present and intact under `/data`
- Insurance backup still present at `/work/migration-backup-*/` — do **not** delete yet
- `swapon --show` shows zram + swapfile
- `lspci -vv | grep -A20 NVIDIA | grep -E 'LnkCap|LnkSta'` — GPU at expected x16 width
- `nixos-rebuild dry-build` clean
- Reboot once into Ubuntu to confirm dual-boot

---

## Phase B — Drop Ubuntu, fill out the remaining mounts

Trigger only after at least a week of comfortable NixOS use, `configuration.nix` committed to a repo, and `/home` snapshot pushed to T7 Shield.

### B.1 Backup + capture state
- Snapshot `@home` → `/work/home-snapshot-$(date +%F)/` via `btrfs send` piped to a file (or `rsync -aHAX`). The 980 has plenty of headroom alongside the `/data` insurance copy.
- Push `/etc/nixos` to GitHub
- `efibootmgr -v` — record current Ubuntu entry numbers (currently `Boot0001` and `Boot0004`, verify before deleting)

### B.2 Wipe Ubuntu + remove its UEFI entries
From running NixOS:
```sh
sudo efibootmgr -b 0001 -B          # Ubuntu (shimx64 on nvme2n1p1)
sudo efibootmgr -b 0004 -B          # stale ubuntu entry
sudo wipefs -a /dev/nvme2n1
sudo sgdisk --zap-all /dev/nvme2n1
```

### B.3 Format the SN850X for `/models` + `/checkpoints`
```sh
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:ml /dev/nvme2n1
sudo mkfs.xfs -L ml /dev/nvme2n1p1
sudo mkdir -p /srv/ml/{models,checkpoints}
```

NixOS:
```nix
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
```

### B.4 Wipe + format the remaining drives
(The Samsung 980 was already formatted as `/work` in P0.2 — skip here.)
```sh
# Samsung 860 QVO → /games
sudo wipefs -a /dev/sdb
sudo sgdisk --zap-all /dev/sdb
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:games /dev/sdb
sudo mkfs.btrfs -L games /dev/sdb1

# Samsung 750 EVO → /rescue
sudo wipefs -a /dev/sda
sudo sgdisk --zap-all /dev/sda
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:rescue /dev/sda
sudo mkfs.ext4 -L rescue /dev/sda1
```

### B.5 Add mounts + directory policy to `configuration.nix`
(`/work` mount was already added in A.7 — only add `/games` and `/rescue` here.)
```nix
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

systemd.tmpfiles.rules = [
  "d /work             0755 root    root  -"
  "d /work/docker      0711 root    root  -"
  "d /work/containers  0711 root    root  -"
  "d /work/vms         0755 beegass users -"
  "d /work/build       0755 beegass users -"
  "d /work/scratch     0755 beegass users -"
  "d /work/downloads   0755 beegass users -"
  "d /work/staging     0755 beegass users -"
  "d /work/cache       0755 beegass users -"
  "d /rescue           0755 root    root  -"
  "d /rescue/isos      0755 beegass users -"
  "d /rescue/staging   0755 beegass users -"
];
```

Optional — if Docker is used, move its data root off `/`:
```nix
virtualisation.docker = {
  enable = true;
  daemon.settings.data-root = "/work/docker";
};
```

Then `sudo nixos-rebuild switch`.

### B.6 Phase B smoke-test
- `findmnt` shows: `/`, `/home`, `/nix`, `/var/log`, `/boot`, `/data`, `/srv/ml`, `/models`, `/checkpoints`, `/work`, `/games`, `/rescue`
- `/data` contents still intact
- Only NixOS entries in UEFI boot menu
- `nix-store --verify --check-contents` passes
- `lspci -vv | grep -A20 NVIDIA | grep -E 'LnkCap|LnkSta'` — GPU still at x16 after the extra NVMe is populated
- `docker info | grep 'Docker Root Dir'` shows `/work/docker` (if Docker enabled)
- A `nixos-rebuild switch` + rollback works

### B.7 Release the insurance copy
Only after every check in B.6 passes:
```sh
sudo rm -rf /work/migration-backup-*
sudo rm -rf /work/home-snapshot-*    # only if /home is healthy and snapshots elsewhere are in place
```
This reclaims ~250 GB on the 980 and leaves it as a clean `/work` mount.

---

## NixOS configuration snippets

### Boot + LUKS
```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
boot.initrd.luks.devices.cryptroot.device = "/dev/disk/by-partlabel/cryptnixos";
```

### System mounts
```nix
fileSystems."/" = {
  device = "/dev/disk/by-label/nixos";
  fsType = "btrfs";
  options = [ "subvol=@" "compress=zstd" "noatime" "ssd" ];
};
fileSystems."/home" = {
  device = "/dev/disk/by-label/nixos";
  fsType = "btrfs";
  options = [ "subvol=@home" "compress=zstd" "noatime" "ssd" ];
};
fileSystems."/nix" = {
  device = "/dev/disk/by-label/nixos";
  fsType = "btrfs";
  options = [ "subvol=@nix" "compress=zstd" "noatime" "ssd" ];
};
fileSystems."/var/log" = {
  device = "/dev/disk/by-label/nixos";
  fsType = "btrfs";
  options = [ "subvol=@log" "compress=zstd" "noatime" "ssd" ];
};
fileSystems."/swap" = {
  device = "/dev/disk/by-label/nixos";
  fsType = "btrfs";
  options = [ "subvol=@swap" "noatime" "nodatacow" ];
};
fileSystems."/boot" = {
  device = "/dev/disk/by-label/NIXBOOT";
  fsType = "vfat";
};
fileSystems."/data" = {
  device = "/dev/disk/by-label/data";
  fsType = "xfs";
  options = [ "noatime" "nofail" ];
};
fileSystems."/work" = {
  device = "/dev/disk/by-label/work";
  fsType = "xfs";
  options = [ "noatime" "nofail" ];
};

swapDevices = [ { device = "/swap/swapfile"; } ];
zramSwap.enable = true;
```

### NVIDIA (Blackwell — open modules mandatory)
```nix
services.xserver.videoDrivers = [ "nvidia" ];
hardware.nvidia = {
  modesetting.enable = true;
  open = true;                                           # Blackwell requires open kernel modules
  package = config.boot.kernelPackages.nvidiaPackages.beta;
  nvidiaSettings = true;
};
hardware.graphics.enable = true;
```

### Flakes + nix-command
```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

---

## Verification commands (run after each phase)

```sh
findmnt -t btrfs,xfs,vfat,ext4 | grep -v snap
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT
swapon --show
nvidia-smi
cryptsetup status cryptroot
btrfs subvolume list /
btrfs filesystem df /
efibootmgr -v
lspci -vv | grep -A20 -E 'VGA|3D|NVIDIA' | grep -E 'LnkCap|LnkSta'
nix-store --verify --check-contents
nixos-rebuild dry-build
```

## Open items / things to revisit

- **Impermanent root (`/persist` + wipe-on-boot):** out of scope for this plan; revisit once NixOS workflow is comfortable.
- **`/work` encryption:** start unencrypted per the simplicity-first decision. Revisit if containers/VMs land there with real secrets — `/work` is exactly the kind of mount that *should* be encrypted in a steady-state setup. Migration is easy (`cryptsetup luksFormat` + restore).
- **`/var/cache/nix` placement:** stays on `/` (under `@nix`). Small-file random I/O lives best on the 9100 PRO; don't shunt it to a slower drive.
- **PCIe lane sharing:** verify GPU stays at x16 in `LnkSta` post-install. With four NVMe drives populated, a slot may force the GPU down. If `LnkSta` shows x8, physically reshuffle.
- **Old Tensor data on `nvme3n1`, `sda`, `sdb`:** plan assumes all three are wiped (you confirmed nothing on them matters). If unsure, mount read-only before B.3/B.4 and inventory.
- **T7 Shield is reserved for business documents** — explicitly not touched by this plan. The insurance backup lives on the Samsung 980 (`/work`) during the migration window and is deleted in B.7.
- **No external backup target during migration:** all three copies are internal (9100 PRO original, T705 working copy, 980 insurance). If you want a true off-machine copy before pulling the trigger on A.2, dedicate an external drive (not T7 Shield) and add a step.
- **Flake migration:** plan uses traditional `configuration.nix` to keep Phase A simple. Migrate to flakes between A and B if desired.

## Critical files

- `/etc/nixos/configuration.nix` — main config (created by `nixos-generate-config`)
- `/etc/nixos/hardware-configuration.nix` — auto-generated, do not hand-edit
- `/swap/swapfile` — 32 GB swapfile on `@swap` subvol
- `/boot/loader/entries/` — systemd-boot generations
- UEFI NVRAM boot entries (manage via `efibootmgr`)
- Ubuntu's `/etc/fstab` — edited in P0.6 to point `/data` at the T705 before NixOS install begins
- `/work/migration-backup-<date>/` — insurance copy of `/data` on the Samsung 980 (deleted in B.7 after Phase B verification)
