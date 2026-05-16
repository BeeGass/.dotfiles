# Manifold

Primary ML workstation. Currently runs Ubuntu 25.10. NixOS + Niri migration in progress (see `docs/nixos/manifold-migration-plan.md`).

## Hardware

| Component | Spec |
|-----------|------|
| CPU | AMD Ryzen 9 9950X3D (16c/32t) |
| GPU | NVIDIA RTX Pro 6000 (Blackwell, 96GB VRAM) planned; RTX 5090 (32GB) current |
| RAM | 64GB DDR5 |
| Motherboard | MSI MAG X870E TOMAHAWK WIFI |
| Storage | Samsung SSD 9100 PRO 2TB (system, Btrfs) + 4TB NVMe (/data, XFS) planned; WD_BLACK SN850X 2TB current |
| OS | NixOS + Niri planned (Phase 8); Ubuntu 25.10 current |

## Network

| Field | Value |
|-------|-------|
| SSH | `ssh Manifold` |
| LAN IP | 192.168.68.10 |
| Tailscale | manifold.tailf7d439.ts.net |
| SSH Port | 40822 |
| User | beegass |

## Role

- Primary GPU training machine -- 96GB VRAM (Pro 6000) planned for large model training
- Runs Claude Code Remote Control servers (4 systemd user services)
- Nix home-manager managed (standalone). NixOS + Niri migration in progress.
- During the migration: data stages to Tensor (Phase 7), Manifold gets wiped + reinstalled (Phase 8), data flows back (Phase 9), GPU swapped to Pro 6000 (Phase 10).
