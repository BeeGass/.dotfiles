# Tensor - DECOMMISSIONED stub. Kept for potential reuse on a future host.
#
# Original purpose: host-specific home-manager overrides for the standalone
# `homeConfigurations."beegass@tensor"` and the NixOS submodule (both now
# commented in flake.nix).
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
