# Tensor - Secondary ML server (standalone home-manager while on Ubuntu)
# RTX 3080, 32GB RAM
# Usage: home-manager switch --flake ~/.dotfiles#beegass@tensor
#
# Base modules imported by mkHome in flake.nix.
{ config, pkgs, vars, ... }:
{
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  # GPU monitoring
  home.packages = with pkgs; [
    nvtopPackages.nvidia
  ];

  # System CUDA on Ubuntu (not Nix-managed)
  home.sessionVariables = {
    CUDA_PATH = "/usr/local/cuda";
  };

  home.sessionPath = [
    "/usr/local/cuda/bin"
  ];
}
