# NVIDIA RTX 5090 (Blackwell) driver configuration
#
# Uses the open-source kernel modules (required for Blackwell/GB202 GPUs)
# with the beta driver branch for latest hardware support.
#
# Includes:
#   - Modesetting for Wayland compatibility
#   - nvidia-container-toolkit for GPU-accelerated containers
#   - VRAM leak workaround for niri compositor
{ config, lib, pkgs, ... }:

{
  # NVIDIA kernel params and early module loading
  boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" ];
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.blacklistedKernelModules = [ "nouveau" ];

  # Use the proprietary NVIDIA driver (the "open" flag below controls
  # whether the open-source kernel modules are used -- the userspace
  # components are always proprietary).
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Kernel modesetting -- required for Wayland compositors (niri, sway, etc.)
    # and for proper VT switching. Adds "nvidia-drm.modeset=1" to kernel params.
    modesetting.enable = true;

    # Use NVIDIA's open-source kernel modules (nvidia-open).
    # Required for Blackwell (RTX 5090 / GB202) -- the legacy closed-source
    # kernel modules do not support this generation.
    open = true;

    # Install nvidia-settings GUI for manual tweaking (fan curves, clocks, etc.)
    nvidiaSettings = true;

    # Beta driver branch -- Blackwell support lands here first before stable.
    # Once stable drivers fully support GB202 this can switch to .stable.
    package = config.boot.kernelPackages.nvidiaPackages.beta;

    # Runtime power management -- disabled for a desktop workstation that is
    # always plugged in. Enable on laptops to allow the GPU to suspend.
    powerManagement.enable = false;

    # Dynamic Boost -- lets the GPU dynamically shift power between CPU and
    # GPU for better perf in mixed workloads. Mostly relevant for laptops
    # but harmless on desktops with sufficient power delivery.
    dynamicBoost.enable = true;
  };

  # Mesa / Vulkan / OpenGL support (required for both native and 32-bit apps)
  hardware.graphics = {
    enable = true;

    # 32-bit driver libraries -- needed by Steam, Wine, and other 32-bit apps
    enable32Bit = true;
  };

  # NVIDIA Container Toolkit (nvidia-ctk) -- allows Docker/Podman containers
  # to access the GPU. Required for GPU-accelerated ML training in containers.
  hardware.nvidia-container-toolkit.enable = true;

  # Workaround for a known VRAM leak when running niri compositor with NVIDIA.
  # The GL video heap reuse ratio of 0 prevents the driver from caching freed
  # VRAM allocations, which avoids the leak at a minor performance cost.
  # See: https://github.com/YaLTeR/niri/wiki/NVIDIA
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-niri-vram-fix.json".text = builtins.toJSON {
    rules = [
      {
        pattern = {
          feature = "procname";
          matches = "niri";
        };
        profile = "niri-vram-fix";
      }
    ];
    profiles = [
      {
        name = "niri-vram-fix";
        settings = [
          {
            key = "GLVidHeapReuseRatio";
            value = 0;
          }
        ];
      }
    ];
  };
}
