# Homelab Hardware Environment

All nodes connected via 2.5GbE switch.

## Manifold (192.168.68.10) - Primary Workstation
- **CPU**: AMD Ryzen 9950X3D
- **GPU**: NVIDIA RTX 5090
- **RAM**: 64GB DDR5
- **Storage**: 4TB NVMe SSD
- **OS**: Ubuntu 25.10
- **Role**: Primary ML training and development workstation

## Tensor (192.168.68.11) - Secondary Workstation
- **CPU**: AMD Ryzen 9 3900X
- **GPU**: NVIDIA RTX 3080
- **RAM**: 32GB
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
