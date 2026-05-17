# Manifold

Primary ML workstation. Currently runs Ubuntu 25.10. NixOS + Niri migration in progress (see `docs/nixos/manifold-install-plan.md`). Now consolidates the homelab's x86_64-linux compute — Tensor has been decommissioned and its hardware (RTX Pro 6000 + several SSDs) is in Manifold.

## Hardware

| Component | Spec |
|-----------|------|
| CPU | AMD Ryzen 9 9950X3D (16c/32t) |
| GPU | NVIDIA RTX Pro 6000 (Blackwell, 96GB VRAM) — installed |
| RAM | 64GB DDR5 |
| Motherboard | MSI MAG X870E TOMAHAWK WIFI |
| Storage | 6 drives — see Drive layout below |
| OS | NixOS + Niri planned (Phase A: dual-boot, Phase B: drop Ubuntu); Ubuntu 25.10 current |

## Drive layout (planned NixOS)

| Device | Model | Mount | FS | Encrypted |
|---|---|---|---|---|
| nvme0n1 | Samsung 9100 PRO 2TB (PCIe 5.0) | /boot + LUKS(system) | vfat + btrfs subvols (@root, @home, @nix, @log) | yes |
| nvme1n1 | Crucial T705 4TB (PCIe 5.0) | /library (datasets, HF cache, external models) | btrfs (compress=zstd:1) | no |
| nvme2n1 | WD_BLACK SN850X 2TB (PCIe 4.0) | /work (runs, checkpoints, logs, projects) | btrfs (compress=zstd:1) | no |
| nvme3n1 | Samsung 980 1TB (PCIe 3.0) | /cache (docker, uv, pip, triton, jax, ccache) | btrfs (compress=zstd:1) | no |
| sdb | Samsung 860 QVO 1TB (SATA) | /games | ext4 | no |
| sda | Samsung 750 EVO 250GB (SATA) | /pad (scratchpad: ideas, scripts, snippets) | ext4 | no |

Swap is zram-only; no on-disk swap. T7 Shield external is reserved for business documents and is explicitly not part of this layout.

## Network

| Field | Value |
|-------|-------|
| SSH | `ssh Manifold` |
| LAN IP | 192.168.68.10 |
| Tailscale | manifold.tailf7d439.ts.net |
| SSH Port | 40822 |
| User | beegass |

## Role

- Primary GPU training machine -- 96GB VRAM (Pro 6000) for large model training
- Runs Claude Code Remote Control servers (4 systemd user services)
- Nix home-manager managed (standalone). NixOS + Niri migration in progress.
- Migration path: Phase 0 = pre-migrate /data off the 9100 PRO onto T705. Phase A = install NixOS on the 9100 PRO (dual-boot with Ubuntu). Phase B = drop Ubuntu, format the remaining drives, fill out the layout. See `docs/nixos/manifold-install-plan.md`.
