# Tensor — DECOMMISSIONED

This host has been retired. Hardware was migrated into Manifold to consolidate the x86_64-linux compute footprint:

- **RTX Pro 6000** (Blackwell, 96GB) — now Manifold's primary GPU (replaced the RTX 5090, which was Manifold's previous GPU; 5090 disposition: TBD).
- **Samsung SSD 980 1TB (NVMe)** — now Manifold's `/work` (XFS, containers/VMs/builds/scratch).
- **Samsung SSD 860 QVO 1TB (SATA)** — now Manifold's `/games` (btrfs+zstd).
- **Samsung SSD 750 EVO 250GB (SATA)** — now Manifold's `/rescue` (ext4).
- **Samsung SSD 970 EVO 1TB (NVMe)** — not currently in use (Manifold's NVMe slots are populated by the 9100 PRO + T705 + SN850X + 980).

The hostname `tensor`, the Tailscale node, and the homeConfigurations/nixosConfigurations entries are commented out in `flake.nix` but kept in the repo as stubs for potential reuse on a future host.

## Original hardware (pre-decommission)

| Component | Spec |
|-----------|------|
| CPU | AMD Ryzen 9 3900X (12c/24t) |
| GPU | NVIDIA GeForce RTX 3080 (10GB VRAM) |
| RAM | 32GB DDR4 |
| Motherboard | Gigabyte B550I AORUS PRO AX |
| Storage | Samsung 980 1TB (NVMe) + 970 EVO 1TB (NVMe) + 860 QVO 1TB (SATA) + 750 EVO 250GB (SATA) |
| OS | Ubuntu 25.10 |

## Network

| Field | Value |
|-------|-------|
| SSH | `ssh Tensor` |
| LAN IP | 192.168.68.11 |
| Tailscale | tensor.tailf7d439.ts.net |
| SSH Port | 40822 |
| User | beegass |

## Role

Retired. See decommissioning notes at the top of this file for where each component went.
