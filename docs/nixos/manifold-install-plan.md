# NixOS install on Manifold — disk layout & phased migration

## Context

Tensor has been decommissioned. Its RTX PRO 6000 Blackwell GPU and several SSDs are now in Manifold. Manifold currently boots Ubuntu 25.10 on the WD_BLACK SN850X (`nvme2n1`). The goal is to land on NixOS as the primary Linux, with a multi-drive layout that maps workload to the right tier of storage — **capacity where it's needed, encryption where it matters, each drive in a role that matches its quality.** Ubuntu is preserved temporarily for dual-boot during the transition, then removed.

The semantic model on top of the drives:

- **`/library`** — read-mostly reference (datasets, HF cache, external models). Highest-capacity drive (T705 4 TB).
- **`/work`** — active outputs (runs, checkpoints, logs, notes, projects). Second-best drive (SN850X 2 TB).
- **`/cache`** — rebuildable tool caches (docker, uv, pip, triton, jax, ccache). Mid-tier drive (Samsung 980 1 TB).
- **`/games`** — Steam library and friends. SATA SSD (860 QVO 1 TB).
- **`/pad`** — scratchpad: ideas, scripts, probes, snippets. Smallest SATA SSD (750 EVO 250 GB).

Key principles:

- **Capacity > peak speed for `/library`** — datasets grow, and 14,100 vs 14,700 MB/s is meaningless when neither workload saturates either drive. T705 (4 TB) belongs on `/library`, not on `/`.
- **Best-after-system drive for active outputs** — `/work` lives on the SN850X. Checkpoints + run artifacts churn the most.
- **Tool caches on the mid-tier NVMe** — the Samsung 980 (PCIe 3.0, 1 TB) is too fast for cold archive and too small for `/library`; perfect for `/cache` where rebuild cost is low if the drive ever dies.
- **Don't overuse the bottom tier** — the 750 EVO (SATA, 250 GB) is `/pad` (loose snippets), not primary scratch.

## Decisions (locked)

- **System filesystem:** LUKS → btrfs with subvols (`@root`, `@home`, `@nix`, `@log`). No `/persist`. No `@swap`.
- **Bulk filesystems:** btrfs on `/library`, `/work`, `/cache` (compress=zstd:1). Ext4 on `/games` and `/pad`.
- **Encryption:** **System drive only (LUKS).** Everything else unencrypted for simplicity. Machine assumed physically secure. (Revisit `/work` encryption once it holds anything material — see Open items.)
- **Swap:** **zram-only.** No disk swap, no swapfile, no hibernation. An optional unused p3 on the 9100 PRO is reserved for future disk swap (zram backing device or plain swap) but is not created by default.
- **Bootloader:** systemd-boot on a new 1 GB ESP on the 9100 PRO. Ubuntu's existing ESP on `nvme2n1p1` is left untouched during Phase A; its UEFI entry is removed in Phase B.
- **Dual-boot mechanism:** UEFI firmware boot menu, not GRUB chain-loading.
- **`nvme3n1` (Samsung 980):** wiped and used as `/cache` (rebuildable tool caches).
- **`nvme2n1` (SN850X):** wiped in Phase B and used as `/work` (active outputs).
- **`sdb` (Samsung 860 QVO):** wiped and used as `/games` (ext4).
- **`sda` (750 EVO):** wiped and used as `/pad` (ext4 scratchpad).
- **NVIDIA driver:** `hardware.nvidia.open = true` — Blackwell mandates open kernel modules.
- **LUKS device reference:** `/dev/disk/by-partlabel/cryptnixos` (GPT partition label), not `/dev/disk/by-label` (which is the inner filesystem label).

## Final layout

| Mount | Device | Model | FS | Encrypted |
|---|---|---|---|---|
| `/boot` | `nvme0n1p1` | Samsung 9100 PRO 2 TB (PCIe 5.0) | vfat (1 GiB), label `NIXBOOT` | no |
| `/`, `/home`, `/nix`, `/var/log` | `nvme0n1p2` | Samsung 9100 PRO 2 TB | LUKS (partlabel `cryptnixos`) → btrfs (label `nixos`, subvols `@root`/`@home`/`@nix`/`@log`) | **yes** |
| `/library` | `nvme1n1p1` | **Crucial T705 4 TB (PCIe 5.0)** | btrfs (label `library`, `compress=zstd:1`) | no |
| `/work` | `nvme2n1p1` | WD_BLACK SN850X 2 TB (PCIe 4.0) | btrfs (label `work`, `compress=zstd:1`) | no (revisit) |
| `/cache` | `nvme3n1p1` | Samsung 980 1 TB (PCIe 3.0) | btrfs (label `cache`, `compress=zstd:1`) | no |
| `/games` | `sdb1` | Samsung 860 QVO 1 TB (SATA) | ext4 (label `games`) | no |
| `/pad` | `sda1` | Samsung 750 EVO 250 GB (SATA) | ext4 (label `pad`) | no |

All NixOS `fileSystems.*` entries use `/dev/disk/by-label/<label>` (or `by-partlabel` for the LUKS device) — drives can be reseated without reconfig.

**Authoritative Nix source-of-truth:** `nix/hosts/manifold/hardware-configuration.nix` encodes all seven mounts + LUKS + swap config. When `nixos-generate-config` runs during install (A.6 / A.7) preserve that file's `fileSystems` block and `boot.initrd.luks.devices.cryptroot` line; merge only the auto-probed `boot.initrd.availableKernelModules` / `boot.kernelModules` / `hardware.cpu.amd.updateMicrocode` parts from the generated output.

## Directory policy (post-install)

This is the intended subtree under each mount. The actual `systemd.tmpfiles.rules` lives in `nix/modules/nixos/optional/datasets.nix` and creates these dirs on first activation; if you reorganize, edit that module.

```
/library/datasets               /work/runs                  /cache/docker
/library/hf-cache               /work/checkpoints           /cache/containers
/library/corpora                /work/logs                  /cache/uv
/library/tokenized              /work/notes                 /cache/pip
/library/benchmarks             /work/reports               /cache/cargo
/library/models-external        /work/samples               /cache/ccache
/library/models-local-promoted  /work/lineages              /cache/triton
/library/reference              /work/projects              /cache/jax
                                                            /cache/tmp
                                                            /cache/downloads
                                                            /cache/preprocess

/pad/ideas       /pad/scripts       /pad/probes
/pad/loose-logs  /pad/snippets      /pad/inbox
```

Environment variables (set by `nix/modules/nixos/optional/datasets.nix` as system `environment.sessionVariables`):

```sh
export LIBRARY_ROOT=/library
export DATASETS_ROOT=/library/datasets
export HF_HOME=/library/hf-cache
export HF_HUB_CACHE=/library/hf-cache/hub
export TRANSFORMERS_CACHE=/library/hf-cache
export MODELS_ROOT=/library/models-external

export WORK_ROOT=/work
export RUNS_ROOT=/work/runs
export CHECKPOINTS_ROOT=/work/checkpoints

export CACHE_ROOT=/cache
export UV_CACHE_DIR=/cache/uv
export PIP_CACHE_DIR=/cache/pip
export TRITON_CACHE_DIR=/cache/triton
export JAX_COMPILATION_CACHE_DIR=/cache/jax

export PAD_ROOT=/pad
```

## Critical ordering wrinkle

The 9100 PRO currently holds `/data` (122 GB: `freectrl`, `huggingface_cache`, `mqar`, `ppm`) under Ubuntu. Putting NixOS root there means **`/data` must be migrated off it before the install touches the drive.** Three-copy safety during the risky step:

1. Original on 9100 PRO (untouched until A.2 wipe)
2. Working copy on Crucial T705 (becomes the new `/library`)
3. Insurance archive on the Samsung 980 (formatted early as its final `/cache` filesystem)

**T7 Shield is explicitly out of scope** — it holds business documents and is not touched by any step of this plan. The insurance copy lives on the Samsung 980 instead. Setting up the 980 in Phase 0 (rather than Phase B) means it serves double duty: backup target now, `/cache` mount on first NixOS boot.

The current Ubuntu `/data/*` (freectrl/huggingface_cache/mqar/ppm) will be staged on `/library` under a holding directory; final sorting into `/library/hf-cache`, `/work/projects/freectrl`, etc. happens post-install once you've confirmed everything's intact.

---

## Phase 0 — Pre-migration of `/data` (still running Ubuntu)

### P0.1 Partition + format the Crucial T705 as the future `/library`
```sh
sudo sgdisk --zap-all /dev/nvme1n1
sudo wipefs -a /dev/nvme1n1
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:library /dev/nvme1n1
sudo mkfs.btrfs -L library /dev/nvme1n1p1
```

### P0.2 Partition + format the Samsung 980 as the future `/cache` (insurance copy lives here first)
```sh
sudo sgdisk --zap-all /dev/nvme3n1
sudo wipefs -a /dev/nvme3n1
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:cache /dev/nvme3n1
sudo mkfs.btrfs -L cache /dev/nvme3n1p1
```

### P0.3 Insurance backup to the Samsung 980 (future `/cache`)
btrfs supports full POSIX semantics; `rsync -aHAX` preserves everything cleanly.
```sh
sudo mkdir -p /mnt/cache
sudo mount -o compress=zstd:1,noatime /dev/disk/by-label/cache /mnt/cache
sudo mkdir -p /mnt/cache/migration-backup-$(date +%F)
sudo rsync -aHAXxv --info=progress2 /data/ /mnt/cache/migration-backup-$(date +%F)/
sync
```

### P0.4 Copy `/data` to new T705 (future `/library`)
Stage under a holding directory so the final `/library/*` layout (datasets/hf-cache/etc.) stays clean.
```sh
sudo mkdir -p /mnt/library
sudo mount -o compress=zstd:1,noatime /dev/disk/by-label/library /mnt/library
sudo mkdir -p /mnt/library/imported-from-ubuntu
sudo rsync -aHAXxv --info=progress2 /data/ /mnt/library/imported-from-ubuntu/
sync
```

### P0.5 Verify byte-for-byte (all three copies match)
```sh
sudo du -sb /data /mnt/library/imported-from-ubuntu /mnt/cache/migration-backup-$(date +%F)
sudo diff -qr /data /mnt/library/imported-from-ubuntu | head -20    # should be empty
sudo diff -qr /data /mnt/cache/migration-backup-$(date +%F) | head -20    # should be empty
```

### P0.6 Switch Ubuntu's `/data` to the new T705 (interim, until NixOS boots)
- Edit Ubuntu's `/etc/fstab`: replace the existing `nvme0n1pX` `/data` line with:
  ```
  LABEL=library /data btrfs defaults,noatime,compress=zstd:1,subvol=imported-from-ubuntu 0 2
  ```
  (Mounting the holding subvol directly so Ubuntu sees the same paths it had before.)
- `sudo umount /data && sudo umount /mnt/library && sudo umount /mnt/cache && sudo mount /data`
- Confirm `findmnt /data` shows `/dev/nvme1n1p1` and the four subdirs are present
- **Reboot once** and confirm `/data` mounts cleanly from the T705
- Original data on `nvme0n1` is now orphaned but intact — wiped in A.2
- The insurance copy on the 980 stays in place until Phase B verification (B.6) confirms NixOS is solid, then `rm -rf /cache/migration-backup-*`

> Note: the `imported-from-ubuntu` subvol is created implicitly by the directory layout above; if you want it as a real btrfs subvol (so it can be snapshotted/deleted independently), `sudo btrfs subvolume create /mnt/library/imported-from-ubuntu` before P0.4.

---

## Phase A — Install NixOS on 9100 PRO (dual-boot with Ubuntu)

### A.1 Boot the installer
Boot from USB (e.g. SanDisk, `nixos-graphical-25.11-x86_64`) via UEFI boot menu. Open a root terminal.

### A.2 Wipe + partition the 9100 PRO
```sh
sgdisk --zap-all /dev/nvme0n1
wipefs -a /dev/nvme0n1
sgdisk -n 1:0:+1G -t 1:EF00 -c 1:NIXBOOT    /dev/nvme0n1
sgdisk -n 2:0:0   -t 2:8309 -c 2:cryptnixos /dev/nvme0n1
# Optional p3 (zram backing or future disk swap) intentionally NOT created.
```

### A.3 LUKS + btrfs + subvols
```sh
mkfs.vfat -F32 -n NIXBOOT /dev/nvme0n1p1

cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot
mkfs.btrfs -L nixos /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
umount /mnt
```

### A.4 Mount everything under `/mnt`
```sh
MNTOPTS="compress=zstd,noatime,ssd,space_cache=v2"
mount -o $MNTOPTS,subvol=@root  /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,var/log,boot,library,cache}
mount -o $MNTOPTS,subvol=@home  /dev/mapper/cryptroot /mnt/home
mount -o $MNTOPTS,subvol=@nix   /dev/mapper/cryptroot /mnt/nix
mount -o $MNTOPTS,subvol=@log   /dev/mapper/cryptroot /mnt/var/log

mount /dev/nvme0n1p1 /mnt/boot
mount -o compress=zstd:1,noatime /dev/disk/by-label/library /mnt/library
mount -o compress=zstd:1,noatime /dev/disk/by-label/cache   /mnt/cache
```

### A.5 No swapfile — zram-only
This step intentionally empty. zram is configured in `configuration.nix` (`zramSwap.enable = true`); no on-disk swap is created.

### A.6 Generate base config
```sh
nixos-generate-config --root /mnt
```

### A.7 Edit `/mnt/etc/nixos/configuration.nix`
See snippets below. Critical bits:
- systemd-boot
- LUKS device by **partlabel**, not by `/dev/disk/by-label`
- `hardware.nvidia.open = true` for Blackwell
- All Phase-A filesystem entries (`/`, `/home`, `/nix`, `/var/log`, `/boot`, `/library`, `/cache`)
- `zramSwap.enable = true`; `swapDevices = [ ]`
- User account, hostname `manifold`, flakes

The post-install state will use the committed `nix/hosts/manifold/hardware-configuration.nix` as the source of truth. For Phase A's traditional-`configuration.nix` install, copy the relevant blocks from that file into the generated `configuration.nix`.

### A.8 Install + reboot
```sh
nixos-install
reboot
```
At POST, pick **NixOS** from the UEFI boot menu. Confirm Ubuntu still boots from the same menu.

### A.9 Phase A smoke-test
- `nvidia-smi` sees the RTX PRO 6000
- LUKS prompts at boot, only once (for `cryptroot`)
- `findmnt /library` shows T705 (label `library`); `findmnt /cache` shows the 980 (label `cache`)
- All four subdirs (`freectrl`, `huggingface_cache`, `mqar`, `ppm`) present and intact under `/library/imported-from-ubuntu`
- Insurance backup still present at `/cache/migration-backup-*/` — do **not** delete yet
- `swapon --show` shows zram only (no on-disk swap)
- `lspci -vv | grep -A20 NVIDIA | grep -E 'LnkCap|LnkSta'` — GPU at expected x16 width
- `nixos-rebuild dry-build` clean
- Reboot once into Ubuntu to confirm dual-boot still works

---

## Phase B — Drop Ubuntu, fill out the remaining mounts

Trigger only after at least a week of comfortable NixOS use, `configuration.nix` (or the flake) committed to a repo, and `/home` snapshot pushed to T7 Shield.

### B.1 Backup + capture state
- Snapshot `@home` → `/cache/home-snapshot-$(date +%F)/` via `btrfs send` piped to a file (or `rsync -aHAX`). The 980 (`/cache`) has plenty of headroom alongside the migration backup.
- Push `/etc/nixos` (or the flake) to GitHub
- `efibootmgr -v` — record current Ubuntu entry numbers (e.g. `Boot0001` and `Boot0004`; verify before deleting)

### B.2 Wipe Ubuntu + remove its UEFI entries
From running NixOS:
```sh
sudo efibootmgr -b 0001 -B          # Ubuntu (shimx64 on nvme2n1p1)
sudo efibootmgr -b 0004 -B          # stale ubuntu entry
sudo wipefs -a /dev/nvme2n1
sudo sgdisk --zap-all /dev/nvme2n1
```

### B.3 Format the SN850X for `/work`
```sh
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:work /dev/nvme2n1
sudo mkfs.btrfs -L work /dev/nvme2n1p1
```

The NixOS `fileSystems."/work"` block is already in `nix/hosts/manifold/hardware-configuration.nix` — no edit needed if you're on the flake. If you're still on traditional `configuration.nix`, add:
```nix
fileSystems."/work" = {
  device = "/dev/disk/by-label/work";
  fsType = "btrfs";
  options = [ "compress=zstd:1" "noatime" "nofail" ];
};
```

### B.4 Wipe + format the remaining drives
(The Samsung 980 was already formatted as `/cache` in P0.2 — skip here.)
```sh
# Samsung 860 QVO → /games
sudo wipefs -a /dev/sdb
sudo sgdisk --zap-all /dev/sdb
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:games /dev/sdb
sudo mkfs.ext4 -L games /dev/sdb1

# Samsung 750 EVO → /pad
sudo wipefs -a /dev/sda
sudo sgdisk --zap-all /dev/sda
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:pad /dev/sda
sudo mkfs.ext4 -L pad /dev/sda1
```

### B.5 Confirm mounts + directory policy
The `fileSystems."/games"`, `fileSystems."/pad"`, and the full `systemd.tmpfiles.rules` for the `/library`, `/work`, `/cache`, `/pad` subtrees are already in:
- `nix/hosts/manifold/hardware-configuration.nix` (mounts)
- `nix/modules/nixos/optional/datasets.nix` (tmpfiles + env vars)

If on the flake: `sudo nixos-rebuild switch`. If still on traditional `configuration.nix`, copy those blocks across.

Optional — if Docker is used, move its data root off `/`:
```nix
virtualisation.docker = {
  enable = true;
  daemon.settings.data-root = "/cache/docker";
};
```

### B.6 Phase B smoke-test
- `findmnt` shows: `/`, `/home`, `/nix`, `/var/log`, `/boot`, `/library`, `/work`, `/cache`, `/games`, `/pad`
- `/library/imported-from-ubuntu/` contents still intact
- Only NixOS entries in UEFI boot menu (`efibootmgr -v`)
- `nix-store --verify --check-contents` passes
- `lspci -vv | grep -A20 NVIDIA | grep -E 'LnkCap|LnkSta'` — GPU still at x16 after the extra NVMe is populated
- `docker info | grep 'Docker Root Dir'` shows `/cache/docker` (if Docker enabled)
- A `nixos-rebuild switch` + rollback works
- All env vars from datasets.nix exported in a fresh shell: `env | grep -E '^(LIBRARY|WORK|CACHE|PAD)_ROOT='`

### B.7 Release the insurance copy + sort `imported-from-ubuntu`
Only after every check in B.6 passes:
```sh
# Verify the imported data is where you want it before deleting backups.
ls /library/imported-from-ubuntu

# Sort into the new layout. Examples — adjust to your taste:
#   huggingface_cache → /library/hf-cache/
#   freectrl / mqar / ppm → /work/projects/{freectrl,mqar,ppm}/
sudo mv /library/imported-from-ubuntu/huggingface_cache/* /library/hf-cache/
sudo mkdir -p /work/projects
sudo mv /library/imported-from-ubuntu/freectrl /work/projects/
sudo mv /library/imported-from-ubuntu/mqar     /work/projects/
sudo mv /library/imported-from-ubuntu/ppm      /work/projects/

# Once sorted and verified:
sudo rmdir /library/imported-from-ubuntu          # only if empty
sudo rm -rf /cache/migration-backup-*             # release the insurance
sudo rm -rf /cache/home-snapshot-*                # only if /home is healthy
```
This reclaims ~250 GB on the 980 and leaves it as a clean `/cache` mount.

---

## NixOS configuration snippets

Source-of-truth for these is `nix/hosts/manifold/hardware-configuration.nix`. Snippets here mirror that file for use during Phase A (traditional `configuration.nix`).

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
fileSystems."/boot" = {
  device = "/dev/disk/by-label/NIXBOOT";
  fsType = "vfat";
};
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

# zram-only; no on-disk swap.
swapDevices = [ ];
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
findmnt -t btrfs,ext4,vfat | grep -v snap
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT
df -h /library /work /cache /games /pad
swapon --show
nvidia-smi
cryptsetup status cryptroot
btrfs subvolume list /
btrfs filesystem df /
btrfs filesystem df /library
btrfs filesystem df /work
btrfs filesystem df /cache
efibootmgr -v
lspci -vv | grep -A20 -E 'VGA|3D|NVIDIA' | grep -E 'LnkCap|LnkSta'
nix-store --verify --check-contents
nixos-rebuild dry-build
env | grep -E '^(LIBRARY|WORK|CACHE|PAD)_ROOT='
```

## Open items / things to revisit

- **Impermanent root (`/persist` + wipe-on-boot):** out of scope for this plan; revisit once NixOS workflow is comfortable.
- **`/work` encryption:** start unencrypted per the simplicity-first decision. Revisit once `/work` actually holds material you care about (training checkpoints, sensitive notes). `/cache` is genuinely rebuildable and probably never needs encryption. Migration is easy (`cryptsetup luksFormat` + restore).
- **`/var/cache/nix` placement:** stays on `/` (under `@nix`). Small-file random I/O lives best on the 9100 PRO; don't shunt it to a slower drive.
- **PCIe lane sharing:** verify GPU stays at x16 in `LnkSta` post-install. With four NVMe drives populated, a slot may force the GPU down. If `LnkSta` shows x8, physically reshuffle.
- **Old Tensor data on `nvme3n1`, `sda`, `sdb`:** plan assumes all three are wiped (you confirmed nothing on them matters). If unsure, mount read-only before P0.2 / B.4 and inventory.
- **T7 Shield is reserved for business documents** — explicitly not touched by this plan. The insurance backup lives on the Samsung 980 (`/cache`) during the migration window and is deleted in B.7.
- **No external backup target during migration:** all three copies are internal (9100 PRO original, T705 working copy, 980 insurance). If you want a true off-machine copy before pulling the trigger on A.2, dedicate an external drive (not T7 Shield) and add a step.
- **Disk swap:** zram-only is the default. If memory pressure ever becomes real with the Pro 6000's 96 GB VRAM workloads, the optional p3 on the 9100 PRO can be created and used as either a swap partition or a zram-writeback backing device.
- **Flake migration:** plan uses traditional `configuration.nix` to keep Phase A simple. Migrate to flakes between A and B if desired — the repo's `nix/hosts/manifold/` is ready.

## Critical files

- `/etc/nixos/configuration.nix` — main config (created by `nixos-generate-config` in A.6)
- `/etc/nixos/hardware-configuration.nix` — auto-generated; merge with the repo's `nix/hosts/manifold/hardware-configuration.nix`
- `/boot/loader/entries/` — systemd-boot generations
- UEFI NVRAM boot entries (manage via `efibootmgr`)
- Ubuntu's `/etc/fstab` — edited in P0.6 to point `/data` at the T705 (interim) before NixOS install begins
- `/cache/migration-backup-<date>/` — insurance copy of `/data` on the Samsung 980 (deleted in B.7 after Phase B verification)
- `/library/imported-from-ubuntu/` — staged copy of `/data` on the T705 (sorted into the final layout in B.7)
- `nix/hosts/manifold/hardware-configuration.nix` — committed source-of-truth for the full mount + LUKS + swap config
- `nix/modules/nixos/optional/datasets.nix` — committed source-of-truth for tmpfiles + env vars
