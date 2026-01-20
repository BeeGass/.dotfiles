# Homelab Hardware Environment

All nodes connected via 2.5GbE switch.

## Manifold (192.168.68.10) - Primary Workstation

- **CPU**: AMD Ryzen 9 9950X3D (16 cores / 32 threads)
- **GPU**: NVIDIA GeForce RTX 5090 (32GB VRAM)
- **RAM**: 64GB DDR5
- **Motherboard**: MSI MAG X870E TOMAHAWK WIFI
- **Storage**:
  - Samsung SSD 9100 PRO 2TB (NVMe)
  - WD_BLACK SN850X 2TB (NVMe)
- **OS**: Ubuntu 25.10 (Questing Quokka)
- **Role**: Primary ML training and development workstation

## Tensor (192.168.68.11) - Secondary Workstation

- **CPU**: AMD Ryzen 9 3900X 12-Core Processor
- **GPU**: NVIDIA GeForce RTX 3080 (GA102)
- **RAM**: 32GB DDR4
- **OS**: Ubuntu 25.10
- **Role**: Secondary ML training and compute node

## Jacobian (192.168.68.30) - Raspberry Pi Node

- **Hardware**: Raspberry Pi 5
- **RAM**: 16GB
- **Storage**: 931.5GB NVMe
- **OS**: Ubuntu
- **User**: ubuntu
- **Role**: Lightweight compute and orchestration

## Hessian (192.168.68.31) - Raspberry Pi Node

- **Hardware**: Raspberry Pi 4B
- **Storage**: microSD
- **OS**: Ubuntu
- **Role**: Support services and monitoring
