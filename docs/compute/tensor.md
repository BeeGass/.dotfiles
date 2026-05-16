# Tensor

Interim full workstation during the Manifold NixOS migration. Becomes a permanent secondary ML/workstation after Phase 11 (5090 transplant).

## Hardware

| Component | Spec |
|-----------|------|
| CPU | AMD Ryzen 9 3900X (12c/24t) |
| GPU | NVIDIA RTX 5090 (Blackwell, 32GB VRAM) planned via transplant from Manifold (Phase 11); RTX 3080 (10GB) current. Disposition of displaced 3080: TBD. |
| RAM | 32GB DDR4 |
| Motherboard | Gigabyte B550I AORUS PRO AX |
| Storage | Samsung SSD 980 1TB (NVMe, system Btrfs) + Samsung SSD 970 EVO 1TB (NVMe, /data XFS) + Samsung SSD 860 QVO 1TB (SATA, unused/scratch) + Samsung SSD 750 EVO 250GB (SATA, unused) |
| OS | NixOS + Niri (Phase 6); was Ubuntu 25.10 |

## Network

| Field | Value |
|-------|-------|
| SSH | `ssh Tensor` |
| LAN IP | 192.168.68.11 |
| Tailscale | tensor.tailf7d439.ts.net |
| SSH Port | 40822 |
| User | beegass |

## Role

- **Interim full workstation** during the Manifold NixOS migration (Phases 6–10): NixOS + Niri, the same role set Manifold has. Holds Manifold's `/data` and `/home` content during the cutover.
- Long-term: secondary ML/workstation. Receives the RTX 5090 from Manifold in Phase 11.
- CUDA toolkit from `nix/modules/nixos/optional/cuda.nix` (system-side); per-project ML stacks via the `.#ml` devShell.
