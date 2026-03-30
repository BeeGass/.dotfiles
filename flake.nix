# BeeGass NixOS + Home Manager multi-host configuration
#
# NixOS hosts (full system management):
#   sudo nixos-rebuild switch --flake ~/.dotfiles#manifold
#   sudo nixos-rebuild switch --flake ~/.dotfiles#tensor
#
# Standalone home-manager (non-NixOS Linux hosts):
#   home-manager switch --flake ~/.dotfiles#beegass@jacobian
#   home-manager switch --flake ~/.dotfiles#ubuntu@hessian
#
# macOS (nix-darwin + home-manager):
#   darwin-rebuild switch --flake ~/.dotfiles#matrix
#
# Dev shells:
#   nix develop .#ml  (CUDA + uv + Python)
{
  description = "BeeGass multi-host NixOS, nix-darwin, and Home Manager configuration";

  inputs = {
    # nixos-unstable: required for RTX 5090 driver 580.x and CUDA >= 12.8
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin for macOS system management (matrix MacBook)
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Community hardware quirks (NVIDIA Blackwell, RPi)
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Niri scrollable tiling WM (manifold only)
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning (used during install)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, nixos-hardware, niri, ... }@inputs:
  let
    mkHost = import ./nix/lib/mkHost.nix { inherit inputs; };
    vars = import ./nix/vars;

    # Helper: create a standalone home-manager configuration
    # For non-NixOS hosts (RPis running Ubuntu, HPC clusters, etc.)
    mkHome = { system, hostname, username ? vars.username }:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs vars; };
        modules = [
          ./nix/modules/home
          ./nix/hosts/${hostname}/home.nix
        ];
      };
  in
  {
    # ── NixOS System Configurations (full system management) ──────────
    nixosConfigurations = {
      # Primary workstation: Ryzen 9 9950X3D, RTX 5090, 64GB, Niri WM
      manifold = mkHost {
        name = "manifold";
        roles = [
          "nvidia"
          "cuda"
          "niri"
          "greetd"
          "audio"
          "steam"
          "tailscale"
          "flatpak"
          "docker"
          "filesystems-btrfs"
        ];
      };

      # Secondary ML server: RTX 3080, 32GB
      # NOTE: Tensor currently runs Ubuntu. When migrating to NixOS,
      # uncomment this and create nix/hosts/tensor/hardware-configuration.nix
      # tensor = mkHost {
      #   name = "tensor";
      #   roles = [
      #     "nvidia"
      #     "cuda"
      #     "tailscale"
      #     "docker"
      #   ];
      # };
    };

    # ── nix-darwin Configuration (macOS) ──────────────────────────────
    darwinConfigurations = {
      # MacBook (Apple Silicon)
      matrix = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs vars; };
        modules = [
          ./nix/hosts/matrix/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs vars; };
              users.${vars.username} = { ... }: {
                imports = [
                  ./nix/modules/home            # Base modules
                  ./nix/hosts/matrix/home.nix   # macOS overrides
                ];
              };
            };
          }
        ];
      };
    };

    # ── Standalone Home Manager (non-NixOS Linux) ─────────────────────
    # For hosts running Ubuntu/Debian where we only manage the user env
    homeConfigurations = {
      # Jacobian - RPi 5 (secrets server, backup)
      # Usage: home-manager switch --flake ~/.dotfiles#ubuntu@jacobian
      "ubuntu@jacobian" = mkHome {
        system = "aarch64-linux";
        hostname = "jacobian";
        username = "ubuntu";
      };

      # Hessian - RPi 5 (monitoring)
      # Usage: home-manager switch --flake ~/.dotfiles#ubuntu@hessian
      "ubuntu@hessian" = mkHome {
        system = "aarch64-linux";
        hostname = "hessian";
        username = "ubuntu";
      };

      # Tensor - Secondary ML server (while still on Ubuntu)
      # Usage: home-manager switch --flake ~/.dotfiles#beegass@tensor
      "beegass@tensor" = mkHome {
        system = "x86_64-linux";
        hostname = "tensor";
      };

      # Generic fallback (for testing or unknown hosts)
      # Usage: home-manager switch --flake ~/.dotfiles#beegass
      "beegass" = mkHome {
        system = "x86_64-linux";
        hostname = "generic";
      };
    };

    # ── Dev Shells ────────────────────────────────────────────────────
    devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        # Nix development shell (for working on this flake)
        default = pkgs.mkShell {
          packages = with pkgs; [
            nil            # Nix LSP
            nixpkgs-fmt    # Nix formatter
          ];
        };
      } // (if system == "x86_64-linux" then {
        # ML training shell: CUDA + uv + Python (x86_64-linux only)
        ml = pkgs.mkShell {
          name = "ml-dev";
          packages = with pkgs; [
            uv
            python312
            cudaPackages.cudatoolkit
            cudaPackages.cudnn
            cudaPackages.nccl
            cudaPackages.libcublas
            cudaPackages.libcusparse
            gcc
          ];
          env = {
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
              "/run/opengl-driver"
            ];
            CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
            TRITON_LIBCUDA_PATH = "/run/opengl-driver/lib";
            CC = "${pkgs.gcc}/bin/gcc";
          };
          shellHook = ''
            echo "ML dev shell active. CUDA toolkit at $CUDA_PATH"
            echo "Install PyTorch: uv init && uv add torch"
          '';
        };
      } else {})
    );
  };
}
