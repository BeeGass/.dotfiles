# Tensor - host-specific home-manager overrides.
#
# Two consumers:
#   1. The standalone `homeConfigurations."beegass@tensor"` (used while Tensor
#      still runs Ubuntu — soon to be obsolete once Phase 6 lands).
#   2. The NixOS `nixosConfigurations.tensor` home-manager submodule (Phase 6+).
#
# CUDA paths are now provided by the system (nix/modules/nixos/optional/cuda.nix)
# and HF cache env vars come from datasets.nix. Nothing Tensor-specific is needed
# at the user level beyond what the shared home modules already provide.
{ config, pkgs, vars, ... }:
{
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  # GPU monitoring (also installed system-side via cuda.nix; keeping here is a
  # no-op redundancy that helps the standalone HM path stay functional too).
  home.packages = with pkgs; [
    nvtopPackages.nvidia
  ];
}
