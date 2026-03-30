# Docker -- container runtime with NVIDIA GPU support
#
# Enables the Docker daemon and configures it to use the NVIDIA
# container runtime, allowing GPU-accelerated workloads inside
# containers (ML training, inference, CUDA development, etc.)
#
# Users must be in the "docker" group to run containers without sudo.
# This is typically set in the user module:
#   users.users.<name>.extraGroups = [ "docker" ];
{ config, lib, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    # NVIDIA runtime is handled by hardware.nvidia-container-toolkit.enable
    # in nvidia.nix (enableNvidia is deprecated)
  };
}
