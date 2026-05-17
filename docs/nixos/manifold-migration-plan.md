# NixOS Migration Plan: Ubuntu -> NixOS + Niri

> **SUPERSEDED.** The authoritative install plan is now `docs/nixos/manifold-install-plan.md` and the post-install runbook is `docs/nixos/first-boot.md`. The reality also changed: Tensor was decommissioned (hardware moved into Manifold), the RTX Pro 6000 is already installed in Manifold, and the disk layout is now six drives with LUKS on the system drive.
>
> This file is kept as a historical reference for the original research (reference configurations from ryan4yin, Misterio77, breakds/nixvital, graham33; ML/CUDA patterns from pierrot-lc, SomeoneSerge, natsukium, hf-nix; the Blackwell sm_120 PyTorch ≥ 2.7 constraint). Do not execute against this document.

## Context

Migrating the Manifold workstation (AMD Ryzen 9 9950X3D, RTX 5090 32GB, 64GB DDR5, dual NVMe) from Ubuntu 25.10 to NixOS with Niri window manager. The existing dotfiles at `~/.dotfiles` are managed via shell scripts + symlinks + justfile. This migration rewrites all configuration declaratively in Nix (flake-based NixOS + home-manager), creating a fully reproducible system.

**Key decisions:**
- Full wipe of nvme0n1 (2TB Samsung 9100 PRO) -- NixOS gets the entire drive
- nvme1n1 (2TB WD_BLACK, xfs `/data`) stays untouched
- Btrfs with subvolumes for nvme0n1
- All configs rewritten in Nix (not symlinked) for maximum reproducibility
- Niri config via `programs.niri.settings` (Nix-native, build-time validated)
- Steam via native NixOS `programs.steam` module (not Flatpak)

---

## Reference Configurations (Research)

Architecture and patterns drawn from real-world NixOS configs:

### Structural Patterns Adopted

| Pattern | Source | What We Take |
|---------|--------|-------------|
| `global/optional` module split | [Misterio77/nix-config](https://github.com/Misterio77/nix-config) | NixOS modules split into `common/` (always imported) and per-host opt-in. No custom `mkBoolOpt` abstractions needed. |
| `vars/` centralized variables | [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) | `nix/vars/default.nix` for networking IPs, usernames, GPG keys, Tailscale tailnet -- all parameterized, not hardcoded in modules |
| Role-based `mkHost` | [andrewgigena/homelab](https://github.com/andrewgigena/homelab) | `mkHost { name = "manifold"; roles = ["workstation" "ml" "gaming"]; }` -- future hosts pick different roles |
| Separate `nvidia.nix` per GPU host | [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) | Clean importable module with `nvidia-drm.fbdev=1`, `nvidia-container-toolkit`, not mixed into hardware-configuration.nix |
| `specialArgs` for threading | [Misterio77](https://github.com/Misterio77/nix-config), [fufexan](https://github.com/fufexan/dotfiles) | Pass `{ inherit inputs outputs; }` to all modules via `specialArgs` / `extraSpecialArgs` |
| `config.lib.niri.actions` for keybindings | [vlaci's niri config](https://vlaci.github.io/nix.org/posts/niri) | Cleaner binding syntax: `"Mod+Q".action = close-window;` instead of `"Mod+Q".action.close-window = {};` |
| Colmena for multi-host deployment | [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) | SSH-based remote rebuild for tensor/jacobian/hessian from manifold |
| Distributed builds | [Mic92/dotfiles](https://github.com/Mic92/dotfiles) | Lighter machines delegate builds to manifold via `nix.distributedBuilds` |

### ML/CUDA Patterns (from ML Researchers on NixOS)

| Researcher | Affiliation | Key Pattern |
|------------|------------|-------------|
| [pierrot-lc](https://pierrot-lc.dev/posts/nixos-deep-learning/) | PhD, Inria | `uv` + Nix devShell: Nix provides CUDA plumbing, uv manages Python deps |
| [SomeoneSerge](https://github.com/SomeoneSerge) | PhD, Aalto (CV) | Co-built the CUDA binary cache; uses FHS fallback for edge cases |
| [breakds/nixvital](https://github.com/nixvital/ml-pkgs) | ML/Robotics, SF | Explicit `cudaCapabilities`, overlay-based ML packages |
| [natsukium](https://github.com/natsukium/dotfiles) | ML Engineer, nixpkgs committer | Global `cudaSupport=true`, `nvidia-container-toolkit`, Ollama |
| [graham33](https://github.com/graham33/nixos-dgx-spark) | DGX Spark | `cudaCapabilities = ["12.0"]`, open kernel modules required for Blackwell |
| [Canva ML Platform](https://www.canva.dev/blog/engineering/supporting-gpu-accelerated-machine-learning-with-kubernetes-and-nix/) | Production | Nix-built Docker images, `/run/opengl-driver` for driver libs |
| [HuggingFace](https://github.com/huggingface/hf-nix) | Official | `hf-nix` overlay for ML packages not in nixpkgs |

**Critical finding:** [nixpkgs #406675](https://github.com/NixOS/nixpkgs/issues/406675) -- RTX 5090 (Blackwell, sm_120) requires PyTorch >= 2.7.0 which is NOT yet in nixpkgs. The `uv` + devShell approach (install PyTorch from PyPI with its bundled CUDA 12.8) is **required**, not optional.

### Niri-Specific Patterns

| Pattern | Source | Detail |
|---------|--------|--------|
| VRAM leak fix | [niri NVIDIA wiki](https://github.com/niri-wm/niri/wiki/Nvidia) | `GLVidHeapReuseRatio = 0` in nvidia application profiles |
| Waybar double-launch prevention | [vlaci](https://vlaci.github.io/nix.org/posts/niri) | `systemd.enable = false` on waybar; let niri `spawn-at-startup` manage it |
| `config.lib.niri.actions` | [sodiboo/niri-flake](https://github.com/sodiboo/niri-flake) | Type-safe action helpers: `spawn`, `close-window`, `focus-workspace`, etc. |
| Window opacity rules | [KiaraGrouwstra/cfg](https://github.com/KiaraGrouwstra/cfg) | Active/inactive opacity differentiation via window rules |
| Overview toggle | [vlaci](https://vlaci.github.io/nix.org/posts/niri) | `"Mod+O" = { action = toggle-overview; repeat = false; }` |
| Scroll workspace switching | [vlaci](https://vlaci.github.io/nix.org/posts/niri) | `"Mod+WheelScrollDown" = { action = focus-workspace-down; cooldown-ms = 150; }` |
| `prefer-no-csd` | Multiple configs | Removes client-side decorations for cleaner look with niri's borders |

---

## Directory Structure

All Nix files live under `~/.dotfiles/nix/`. The `flake.nix` goes at `~/.dotfiles/flake.nix` so `nixos-rebuild switch --flake ~/.dotfiles#manifold` works directly.

Architecture follows Misterio77's `global/optional` pattern with ryan4yin's `vars/` and andrewgigena's role-based `mkHost`.

```
.dotfiles/
  flake.nix                           # Top-level flake
  flake.lock
  nix/
    lib/
      mkHost.nix                      # Host builder: takes name, system, roles, extra modules
    vars/
      default.nix                     # Centralized variables (networking, users, GPG keys)
    hosts/
      manifold/
        default.nix                   # Host: imports common/global + optional modules for its roles
        hardware-configuration.nix    # Generated by nixos-generate-config
      # Future: tensor/, jacobian/, hessian/
    modules/
      nixos/
        common/                       # Always imported by every host (Misterio77 pattern)
          default.nix                 # Aggregates all common modules
          boot.nix                    # systemd-boot, kernel, initrd
          nix-settings.nix            # Flakes, caches, auto-optimise, nix-ld
          networking.nix              # NetworkManager, firewall base
          users.nix                   # User account, groups, shell
          security.nix                # pcscd, YubiKey, polkit
          services.nix                # SSH, fwupd, GC
        optional/                     # Opt-in per host (imported explicitly)
          nvidia.nix                  # RTX 5090 drivers, modesetting, container-toolkit, VRAM fix
          cuda.nix                    # CUDA toolkit, cudnn, nccl, ML dev shell template
          niri.nix                    # Niri WM system-level enable + XDG portals
          greetd.nix                  # Display manager (tuigreet)
          audio.nix                   # PipeWire + WirePlumber
          steam.nix                   # Steam + gaming (Proton-GE, gamescope, gamemode)
          tailscale.nix               # Tailscale mesh VPN
          flatpak.nix                 # Flatpak service
          docker.nix                  # Docker/Podman + nvidia-container-toolkit
          filesystems-btrfs.nix       # Btrfs subvolumes, btrbk snapshots
      home/
        default.nix                   # Home-manager entry point
        shell.nix                     # Zsh (full rewrite)
        prompt.nix                    # Oh My Posh configuration
        environment.nix               # Session vars, PATH, GPU env
        git.nix                       # Git (native programs.git)
        gpg.nix                       # GPG + gpg-agent + dirmngr
        ssh.nix                       # SSH client config (matchBlocks)
        terminals.nix                 # Ghostty, Kitty, WezTerm
        editor.nix                    # Neovim + vim-plug + Colemak-DH
        tmux.nix                      # Tmux (native programs.tmux)
        cli-tools.nix                 # fzf, bat, eza, ripgrep, fd, delta, jq, etc.
        dev-tools.nix                 # uv, rustup, nodejs, just, python
        fonts.nix                     # Google Sans Mono, Nerd Fonts, fontconfig
        xdg.nix                       # XDG dirs, MIME associations
        claude.nix                    # Claude Code settings, hooks, commands, RC services
        scripts.nix                   # Utility scripts -> ~/.local/bin
        secrets.nix                   # pass store integration
        desktop/
          niri.nix                    # Niri WM config (programs.niri.settings)
          waybar.nix                  # Status bar + CSS
          fuzzel.nix                  # App launcher
          mako.nix                    # Notifications
          swaylock.nix                # Screen locker
          swayidle.nix                # Idle management
          gtk-qt.nix                  # GTK/QT dark theme, cursor, icons
          desktop-apps.nix            # Electron Wayland flags, Flatpak apps, MIME
    overlays/
      default.nix                     # Overlay aggregator (Google Sans Mono font, etc.)
```

---

## Phase 1: Flake Skeleton + NixOS System Modules

**Goal:** Create the complete NixOS system configuration -- boot, NVIDIA GPU, networking, audio, security, gaming, and all system services. After this phase, `nix build .#nixosConfigurations.manifold.config.system.build.toplevel` should succeed (with a stub hardware-configuration.nix).

**Files to create:** `flake.nix`, `nix/lib/mkHost.nix`, `nix/vars/default.nix`, all `nix/modules/nixos/common/*.nix`, all `nix/modules/nixos/optional/*.nix`, `nix/hosts/manifold/default.nix`

---

### 1.1 `~/.dotfiles/flake.nix`

This is the top-level entry point for the entire NixOS system. It lives at the dotfiles root so `sudo nixos-rebuild switch --flake ~/.dotfiles#manifold` works directly. Every other Nix file is referenced through this.

**Why nixos-unstable:** The RTX 5090 (Blackwell, sm_120) requires NVIDIA driver 580.x and CUDA >= 12.8. These are only available on the unstable branch. The current Ubuntu system already runs driver 580.126.09, confirming Blackwell support is mature in this driver series.

**Why NOT global `cudaSupport = true`:** Setting this in the nixpkgs config causes every CUDA-capable package (OpenCV, FFmpeg, blender, etc.) to rebuild with CUDA support, taking hours even with binary caches. Per ML researcher consensus (pierrot-lc, breakds, SomeoneSerge), CUDA support should be per-project via dev shells. The system only needs the CUDA toolkit and driver libraries.

```nix
# ~/.dotfiles/flake.nix
{
  description = "BeeGass NixOS - Manifold workstation with Niri WM";

  inputs = {
    # --- Core ---
    # nixos-unstable: required for RTX 5090 driver 580.x and CUDA >= 12.8
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager: manages user-level config (zsh, git, tmux, etc.)
    # follows nixpkgs to avoid duplicate nixpkgs evaluations
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Hardware ---
    # nixos-hardware: community hardware quirks, includes common-gpu-nvidia-blackwell
    # which auto-enables open kernel modules for RTX 5090
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # --- Desktop ---
    # niri-flake: NixOS + home-manager modules for the Niri scrollable tiling WM
    # Provides: nixosModules.niri, homeModules.niri, homeModules.config, overlays.niri
    # Auto-configures: polkit, xdg-desktop-portal-gnome, GNOME keyring, PAM for swaylock
    # Binary cache: niri.cachix.org (auto-enabled)
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Disk Management ---
    # disko: declarative disk partitioning, used during initial install
    # Can be removed from the flake after installation is complete
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, niri, disko, ... }@inputs:
  let
    # Import the host builder helper
    mkHost = import ./nix/lib/mkHost.nix { inherit inputs; };

    # Centralized variables (networking, users, GPG keys)
    vars = import ./nix/vars;
  in
  {
    # ── NixOS System Configurations ───────────────────────────────────
    nixosConfigurations = {
      # Primary workstation: RTX 5090, Niri WM, CUDA, Steam
      manifold = mkHost {
        name = "manifold";
        roles = [
          "nvidia"            # NVIDIA proprietary driver, modesetting, container-toolkit
          "cuda"              # CUDA toolkit, cudnn, nccl (system-level libraries)
          "niri"              # Niri WM system-level enable + XDG portals + env vars
          "greetd"            # tuigreet display manager -> niri-session
          "audio"             # PipeWire + WirePlumber
          "steam"             # Steam, gamescope, gamemode, proton-ge
          "tailscale"         # Tailscale mesh VPN
          "flatpak"           # Flatpak for Obsidian, Discord, etc.
          "docker"            # Docker/Podman + nvidia-container-toolkit
          "filesystems-btrfs" # Btrfs subvolumes, btrbk snapshots, auto-scrub
        ];
      };

      # Future hosts (stubs):
      # tensor   = mkHost { name = "tensor";   roles = ["nvidia" "cuda" "tailscale" "docker"]; };
      # jacobian = mkHost { name = "jacobian"; system = "aarch64-linux"; roles = ["tailscale"]; };
      # hessian  = mkHost { name = "hessian";  system = "aarch64-linux"; roles = ["tailscale"]; };
    };

    # ── Dev Shells ────────────────────────────────────────────────────
    # ML dev shell template: provides CUDA plumbing, user installs PyTorch via uv
    # Usage: `nix develop .#ml` or per-project flake.nix that imports this
    devShells.x86_64-linux = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    in {
      # ML training shell: CUDA toolkit + uv + Python
      # Inside: `uv add torch` to get PyTorch 2.7.0+ with sm_120 support
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
          # /run/opengl-driver is where NixOS places NVIDIA driver .so files at runtime
          # This is NixOS-specific and will NOT work on other distros
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib  # libstdc++.so.6
            pkgs.zlib              # libz.so
            "/run/opengl-driver"   # libcuda.so, libnvidia-ml.so
          ];
          CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
          TRITON_LIBCUDA_PATH = "/run/opengl-driver/lib"; # for torch.compile
          CC = "${pkgs.gcc}/bin/gcc";
        };
        shellHook = ''
          echo "ML dev shell active. CUDA toolkit at $CUDA_PATH"
          echo "Install PyTorch: uv init && uv add torch"
        '';
      };
    };
  };
}
```

**What this achieves:**
- `sudo nixos-rebuild switch --flake ~/.dotfiles#manifold` builds and activates the full system
- `nix develop .#ml` drops into a shell with CUDA toolkit, uv, and Python ready for `uv init && uv add torch`
- Future hosts (tensor, jacobian, hessian) can be added by uncommenting stubs and creating their host dirs
- `niri.cachix.org` and `cache.nixos-cuda.org` binary caches are configured downstream in `nix-settings.nix`

---

### 1.2 `~/.dotfiles/nix/lib/mkHost.nix`

This is the host builder function. It takes a hostname and a list of roles, and assembles a complete NixOS system configuration by importing the common modules (always present) plus the optional modules for each role.

**Pattern source:** andrewgigena/homelab's role-based `mkHost` combined with Misterio77's `specialArgs` threading.

**Why roles instead of enable options:** The `mkBoolOpt` pattern (hlissner) requires custom module infrastructure and auto-importing all modules. Roles are simpler -- you explicitly list what each host needs, and the module is only imported if the role is listed. No hidden conditional logic.

```nix
# ~/.dotfiles/nix/lib/mkHost.nix
#
# Role-based host builder. Each host specifies a list of roles (strings),
# and this function maps them to optional NixOS modules.
#
# Usage in flake.nix:
#   manifold = mkHost { name = "manifold"; roles = ["nvidia" "niri" ...]; };
#
{ inputs }:

{ name                          # hostname, e.g. "manifold"
, system ? "x86_64-linux"       # architecture
, roles ? []                    # list of role strings -> optional modules
, extraModules ? []             # additional one-off modules
}:

let
  vars = import ../vars;
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;

  # specialArgs makes these available as function arguments in EVERY module.
  # This is how modules access flake inputs, vars, etc. without import hacks.
  # Pattern from Misterio77/nix-config and fufexan/dotfiles.
  specialArgs = {
    inherit inputs vars;
  };

  modules =
    # 1. Common modules: always imported for every host
    [ ../modules/nixos/common ]

    # 2. Host-specific config: hardware-configuration.nix, host overrides
    ++ [ ../hosts/${name} ]

    # 3. Role-based optional modules: nvidia.nix, steam.nix, etc.
    # Each role string maps to a .nix file in modules/nixos/optional/
    ++ (map (role: ../modules/nixos/optional/${role}.nix) roles)

    # 4. niri-flake NixOS module (only if "niri" role is present)
    # This must be imported at the flake level because it comes from an external input
    ++ (if builtins.elem "niri" roles then [ inputs.niri.nixosModules.niri ] else [])

    # 5. nixos-hardware Blackwell module (only if "nvidia" role is present)
    ++ (if builtins.elem "nvidia" roles then [
      inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    ] else [])

    # 6. home-manager as a NixOS module (not standalone)
    # This means `nixos-rebuild switch` also rebuilds the home environment
    ++ [
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;     # home-manager uses the system's nixpkgs instance
          useUserPackages = true;   # user packages installed to /etc/profiles
          extraSpecialArgs = { inherit inputs vars; };
          users.${vars.username} = import ../modules/home;
        };
      }
    ]

    # 7. Any extra one-off modules
    ++ extraModules;
}
```

**What this achieves:**
- `mkHost { name = "manifold"; roles = ["nvidia" "steam"]; }` imports `common/`, `hosts/manifold/`, `optional/nvidia.nix`, `optional/steam.nix`, niri-flake NixOS module, nixos-hardware NVIDIA module, and home-manager
- `vars` is available as a function argument in every module: `{ config, pkgs, vars, ... }:`
- `inputs` is available for referencing flake inputs in modules (e.g., `inputs.niri.packages`)
- Adding a new host is just adding a new entry in `flake.nix` and a new directory under `hosts/`

---

### 1.3 `~/.dotfiles/nix/vars/default.nix`

Centralized identity and networking variables. Every module can access these via `{ vars, ... }:` in its function signature. This avoids hardcoding usernames, IPs, GPG keys, etc. throughout the config.

**Pattern source:** ryan4yin/nix-config's `vars/` directory.

**Why a separate file instead of inline:** These values are referenced in 10+ modules (users.nix, networking.nix, ssh.nix, gpg.nix, git.nix, etc.). Centralizing them means changing a GPG key or IP address is a single edit, not a grep-and-replace across 10 files.

```nix
# ~/.dotfiles/nix/vars/default.nix
{
  # ── User Identity ───────────────────────────────────────────────────
  username = "beegass";
  fullName = "Bryan Gass";
  email = "bryank123@live.com";
  githubUser = "BeeGass";

  # ── GPG Key IDs (from YubiKey) ─────────────────────────────────────
  # Master key: certification only, stored offline
  # Subkeys: signing, encryption, authentication (on YubiKey)
  gpgKeys = {
    master         = "0xA34200D828A7BB26";  # Master/certification
    signing        = "0xACC3640C138D96A2";  # Git commit signing
    encryption     = "0x21691AE75B0463CC";  # File/message encryption
    authentication = "0x27D667E55F655FD2";  # SSH authentication via gpg-agent
  };

  # ── Networking ──────────────────────────────────────────────────────
  networking = {
    # Tailscale tailnet domain (MagicDNS)
    tailnet = "tailf7d439.ts.net";

    # Custom SSH port (non-standard for security, matches ssh/config)
    sshPort = 40822;

    # All machines in the homelab
    # Used by: networking.nix (hostName, static IP), ssh.nix (matchBlocks),
    #          tailscale.nix (firewall), and future colmena deployment
    hosts = {
      manifold = {
        ip = "192.168.68.10";
        description = "Primary ML workstation (Ryzen 9 9950X3D, RTX 5090)";
        roles = [ "workstation" "ml" "gaming" ];
      };
      tensor = {
        ip = "192.168.68.11";
        description = "Secondary ML server";
        roles = [ "ml-server" ];
      };
      jacobian = {
        ip = "192.168.68.30";
        description = "Raspberry Pi 5 (secrets server, backup)";
        roles = [ "server" ];
      };
      hessian = {
        ip = "192.168.68.31";
        description = "Raspberry Pi 5 (monitoring)";
        roles = [ "server" ];
      };
    };
  };

  # ── Dotfiles Path ───────────────────────────────────────────────────
  # Absolute path to this repo on disk. Used by home-manager modules
  # that need to reference existing config files via mkOutOfStoreSymlink.
  # NOTE: Claude configs are the one exception that uses symlinks instead
  # of Nix-native rewriting (they're JSON/markdown, not system config).
  dotfilesPath = "/home/beegass/.dotfiles";
}
```

---

### 1.4 `~/.dotfiles/nix/hosts/manifold/default.nix`

This is the Manifold-specific host configuration. It imports the generated `hardware-configuration.nix` and sets host-specific overrides that don't belong in shared modules.

```nix
# ~/.dotfiles/nix/hosts/manifold/default.nix
{ config, pkgs, vars, ... }:

{
  imports = [
    ./hardware-configuration.nix  # Generated by nixos-generate-config
  ];

  # Host identity
  networking.hostName = "manifold";

  # Static IP on the LAN interface (2.5GbE)
  # The interface name will be determined by hardware-configuration.nix
  # Typically enp* for PCIe Ethernet on AMD platforms
  # networking.interfaces.enp*.ipv4.addresses = [{
  #   address = vars.networking.hosts.manifold.ip;  # 192.168.68.10
  #   prefixLength = 24;
  # }];
  # NOTE: Uncomment and set the correct interface name after first boot.
  # Use `ip link` to find it. NetworkManager will use DHCP by default,
  # which is fine for initial setup.

  # System state version -- set once during install, never change
  # This does NOT affect package versions; it controls NixOS module defaults
  # for backward compatibility. Always set to the NixOS version you installed with.
  system.stateVersion = "25.05";
}
```

**`~/.dotfiles/nix/hosts/manifold/hardware-configuration.nix`** -- This file is generated automatically by `nixos-generate-config --root /mnt` during installation. It contains filesystem mounts, kernel modules for the specific hardware, and the `system.stateVersion`. A stub is needed for `nix build` validation on Ubuntu:

```nix
# STUB -- replace with output of `nixos-generate-config` during install
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];
  fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; options = [ "subvol=@root" "compress=zstd" "noatime" ]; };
  fileSystems."/home" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; options = [ "subvol=@home" "compress=zstd" "noatime" ]; };
  fileSystems."/nix" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; options = [ "subvol=@nix" "compress=zstd" "noatime" ]; };
  fileSystems."/var/log" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; options = [ "subvol=@log" "compress=zstd" "noatime" ]; };
  fileSystems."/persist" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; options = [ "subvol=@persist" "compress=zstd" "noatime" ]; };
  fileSystems."/boot" = { device = "/dev/disk/by-label/boot"; fsType = "vfat"; };
  fileSystems."/data" = { device = "/dev/disk/by-label/data"; fsType = "xfs"; };
  swapDevices = [];
  hardware.cpu.amd.updateMicrocode = true;
}
```

---

### 1.5 NixOS Common Modules (always imported)

These modules are imported by EVERY host via `../modules/nixos/common`. The `common/default.nix` aggregates them:

```nix
# ~/.dotfiles/nix/modules/nixos/common/default.nix
{ ... }:
{
  imports = [
    ./boot.nix
    ./nix-settings.nix
    ./networking.nix
    ./users.nix
    ./security.nix
    ./services.nix
  ];
}
```

#### 1.5.1 `common/boot.nix`

**What it does:** Configures the bootloader (systemd-boot for UEFI), kernel version, and NVIDIA-required kernel parameters. These kernel params are safe on all hosts -- they're no-ops without an NVIDIA GPU.

**Source mapping:** New file (Ubuntu uses GRUB; NixOS uses systemd-boot for its simpler generation management).

```nix
# ~/.dotfiles/nix/modules/nixos/common/boot.nix
{ config, pkgs, ... }:

{
  # systemd-boot: simple, fast, integrates with NixOS generations
  # Each `nixos-rebuild switch` creates a new boot entry for rollback
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 20;  # Keep last 20 generations in boot menu
    editor = false;           # Disable boot entry editing (security)
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Latest kernel: required for RTX 5090 (Blackwell) driver compatibility
  # If NVIDIA driver breaks with latest, pin: pkgs.linuxPackages_6_12
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # NVIDIA kernel parameters (safe no-ops without NVIDIA hardware):
  # nvidia-drm.modeset=1: required for Wayland compositors (enables KMS)
  # nvidia-drm.fbdev=1: enables framebuffer device for direct scanout (newer drivers)
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];

  # Load NVIDIA modules early in initrd for framebuffer console
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  # Blacklist nouveau (open source NVIDIA driver) to prevent conflicts
  boot.blacklistedKernelModules = [ "nouveau" ];
}
```

#### 1.5.2 `common/nix-settings.nix`

**What it does:** Configures the Nix daemon itself -- enables flakes, sets up binary caches (critical for avoiding hours-long CUDA builds), garbage collection, store optimization, and nix-ld for running unpackaged binaries.

**Why nix-ld:** ML tools (especially Python wheels with C extensions) often ship as dynamically-linked ELF binaries that expect `/lib/ld-linux-x86-64.so.2` and standard library paths. NixOS doesn't have these. `nix-ld` provides a compatibility shim so these binaries "just work". Per andrewgigena and natsukium, this is essential for any ML workstation.

```nix
# ~/.dotfiles/nix/modules/nixos/common/nix-settings.nix
{ pkgs, ... }:

{
  # Enable flakes and the new `nix` CLI (nix build, nix develop, nix flake)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages (NVIDIA drivers, Steam, etc.)
  nixpkgs.config.allowUnfree = true;

  # Binary caches: avoid building from source
  # Order matters -- earlier caches are checked first
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"           # Official NixOS cache (default)
      "https://niri.cachix.org"           # Niri WM prebuilt packages
      "https://cache.nixos-cuda.org"      # CUDA packages (moved from cachix Nov 2025)
      "https://cache.flox.dev"            # Flox CUDA prebuilts (partnership with NVIDIA)
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
  };

  # Hard-link identical files in the Nix store (saves ~25-35% disk space)
  nix.settings.auto-optimise-store = true;

  # Garbage collection: weekly, delete generations older than 14 days
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # nix-ld: compatibility shim for dynamically-linked binaries
  # Without this, PyTorch wheels, CUDA tools, and many ML binaries fail with
  # "No such file or directory" because they expect /lib/ld-linux-x86-64.so.2
  programs.nix-ld = {
    enable = true;
    # Common libraries that unpackaged binaries need
    libraries = with pkgs; [
      stdenv.cc.cc.lib  # libstdc++.so.6
      zlib              # libz.so
      openssl           # libssl.so, libcrypto.so
      curl              # libcurl.so
      libGL             # libGL.so (for rendering)
      glib              # libglib-2.0.so
    ];
  };

  # Allow users in the wheel group to use nix and access caches
  nix.settings.trusted-users = [ "root" "@wheel" ];
}
```

#### 1.5.3 `common/networking.nix`

**What it does:** Configures NetworkManager, firewall, and sets the hostname from vars. The static IP is host-specific (in `hosts/manifold/default.nix`), but the firewall rules and NetworkManager are universal.

**Source mapping:** Replaces the manual NetworkManager configuration from Ubuntu.

```nix
# ~/.dotfiles/nix/modules/nixos/common/networking.nix
{ config, vars, ... }:

{
  # NetworkManager: handles DHCP, WiFi, VPN, etc.
  networking.networkmanager.enable = true;

  # Firewall: enabled by default on NixOS, we just open specific ports
  networking.firewall = {
    enable = true;
    # SSH on custom port (matching ssh/config and existing sshd setup)
    allowedTCPPorts = [ vars.networking.sshPort ];  # 40822
    # Tailscale: trust all traffic on the tailscale0 interface
    trustedInterfaces = [ "tailscale0" ];
  };

  # Disable the wait-online service (speeds up boot by ~15s)
  systemd.services.NetworkManager-wait-online.enable = false;
}
```

#### 1.5.4 `common/users.nix`

**What it does:** Creates the user account with correct groups. The shell is set to zsh (installed and configured via home-manager).

**Source mapping:** Replaces the `adduser` step from Ubuntu installation.

```nix
# ~/.dotfiles/nix/modules/nixos/common/users.nix
{ pkgs, vars, ... }:

{
  # Create the primary user account
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;   # "Bryan Gass"
    shell = pkgs.zsh;
    # Groups:
    # wheel         - sudo access
    # video         - GPU access (direct rendering)
    # docker        - Docker without sudo
    # networkmanager - WiFi/network management
    # input         - input device access (for Wayland)
    extraGroups = [ "wheel" "video" "docker" "networkmanager" "input" ];
  };

  # Enable zsh system-wide (required for it to be a valid login shell)
  programs.zsh.enable = true;

  # Set default shell for new users
  users.defaultUserShell = pkgs.zsh;

  # Sudo: allow wheel group without password (convenience for single-user workstation)
  # Comment this out if you prefer password prompts
  security.sudo.wheelNeedsPassword = false;
}
```

#### 1.5.5 `common/security.nix`

**What it does:** Configures GPG, YubiKey/smartcard support, and polkit. This is the system-level complement to the home-manager `gpg.nix` which configures the user's GPG settings.

**Source mapping:**
- `services.pcscd` replaces `sudo apt install pcscd scdaemon`
- `programs.gnupg.agent` replaces the manual gpg-agent setup in `zsh/20-environment.zsh` and `zsh/90-local.zsh`
- YubiKey udev rules replace `sudo apt install yubikey-personalization`

**Why system-level GPG agent:** When NixOS manages `programs.gnupg.agent`, it creates a proper systemd user service for gpg-agent with socket activation. This is more reliable than the shell-based `gpgconf --launch gpg-agent` in the current zsh config. The shell config's GPG blocks become no-ops (harmless) because the agent is already running.

```nix
# ~/.dotfiles/nix/modules/nixos/common/security.nix
{ pkgs, ... }:

{
  # PC/SC Smart Card Daemon: required for YubiKey GPG operations
  # This talks to the YubiKey's smartcard applet over USB
  services.pcscd.enable = true;

  # GPG agent with SSH support
  # This replaces:
  #   - zsh/20-environment.zsh lines: gpgconf --launch gpg-agent, SSH_AUTH_SOCK
  #   - zsh/90-local.zsh lines: GPG_TTY, gpg-connect-agent updatestartuptty
  #   - gnupg/linux-gpg-agent.conf: enable-ssh-support, pinentry-program
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;              # gpg-agent serves as the SSH agent
    pinentryPackage = pkgs.pinentry-gnome3; # GUI PIN entry dialog for Wayland
    # NOTE: This replaces the hardcoded /usr/bin/pinentry-gnome3 in
    # gnupg/linux-gpg-agent.conf with the correct Nix store path
  };

  # YubiKey udev rules: allows non-root access to the YubiKey USB device
  services.udev.packages = with pkgs; [
    yubikey-personalization  # udev rules for YubiKey
  ];

  # Polkit: allows GUI applications to request elevated privileges
  # Required by: niri (for power management), flatpak, systemd user services
  security.polkit.enable = true;

  # System packages for security tools
  environment.systemPackages = with pkgs; [
    gnupg                     # gpg, gpg-agent, gpgconf
    yubikey-personalization   # ykman predecessor, udev rules
    yubico-piv-tool           # PIV applet management
    pcsctools                 # pcscd diagnostic tools
    pinentry-gnome3           # GUI PIN entry for GPG on Wayland
    pass                      # Unix password manager (GPG-encrypted)
    pass-otp                  # TOTP/HOTP support for pass
  ];
}
```

#### 1.5.6 `common/services.nix`

**What it does:** Configures OpenSSH, firmware updates, and miscellaneous system services.

**Source mapping:**
- OpenSSH replaces `sudo apt install openssh-server` + `ssh/99-yubikey-only.conf` + `ssh/sshd_config_secure`
- fwupd replaces manual firmware update checks

```nix
# ~/.dotfiles/nix/modules/nixos/common/services.nix
{ vars, ... }:

{
  # OpenSSH server
  # Replaces: ssh/99-yubikey-only.conf (port 40822, password auth disabled)
  services.openssh = {
    enable = true;
    ports = [ vars.networking.sshPort ];  # 40822 (non-standard for security)
    settings = {
      PasswordAuthentication = false;     # YubiKey-only (publickey)
      PermitRootLogin = "no";
      MaxAuthTries = 3;
      # Allow GPG agent forwarding (for mcopp remote GPG signing)
      StreamLocalBindUnlink = true;
      AllowAgentForwarding = true;
    };
  };

  # Firmware updates via fwupd (LVFS)
  services.fwupd.enable = true;

  # Timezone and locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Console keymap (Colemak-DH is handled at firmware level on ZSA Voyager,
  # so the console uses standard US QWERTY for recovery/greetd)
  console.keyMap = "us";
}
```

---

### 1.6 NixOS Optional Modules (imported per-host via roles)

These modules are only imported when a host lists the corresponding role in its `mkHost` call.

#### 1.6.1 `optional/nvidia.nix`

**What it does:** Configures the NVIDIA proprietary driver for the RTX 5090 (Blackwell architecture). This is the highest-risk module and the one most likely to need debugging after kernel updates.

**Source mapping:** New file (Ubuntu used the `nvidia-driver-580` apt package).

**Why `open = true`:** The RTX 5090 uses the Blackwell architecture. NVIDIA's open-source kernel modules are now the recommended path for Turing+ GPUs, and are REQUIRED for data center GPUs from Blackwell onward. The `nixos-hardware` Blackwell module auto-sets this, but we set it explicitly for clarity.

**Why `nvidiaPackages.beta`:** The RTX 5090 is very new hardware. The beta driver branch has the most recent Blackwell fixes. If it causes issues, fall back to `.stable` or `.production`.

```nix
# ~/.dotfiles/nix/modules/nixos/optional/nvidia.nix
#
# NVIDIA RTX 5090 (Blackwell, sm_120) driver configuration.
# Imported by hosts with role "nvidia".
#
{ config, pkgs, lib, inputs, ... }:

{
  # Tell NixOS to load the NVIDIA driver
  services.xserver.videoDrivers = [ "nvidia" ];

  # NVIDIA driver settings
  hardware.nvidia = {
    # Kernel modesetting: MANDATORY for Wayland compositors (niri, sway, etc.)
    # Without this, niri will fail to start or show a black screen
    modesetting.enable = true;

    # Open-source kernel modules: required for Blackwell (RTX 5090)
    # The proprietary kernel modules do not support Blackwell architecture
    open = true;

    # nvidia-settings GUI tool (useful for debugging)
    nvidiaSettings = true;

    # Driver package: beta has the latest Blackwell fixes
    # Fallback options if beta breaks:
    #   config.boot.kernelPackages.nvidiaPackages.stable
    #   config.boot.kernelPackages.nvidiaPackages.production
    package = config.boot.kernelPackages.nvidiaPackages.beta;

    # Power management: disabled on desktop (no suspend/resume issues)
    powerManagement.enable = false;

    # Dynamic boost: adjusts GPU clocks based on workload
    dynamicBoost.enable = true;
  };

  # Graphics (replaces hardware.opengl in NixOS < 24.11)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Required for Steam and 32-bit games
  };

  # NVIDIA Container Toolkit: GPU passthrough for Docker/Podman containers
  # Required for: containerized ML training, GPU-accelerated Docker builds
  # Per natsukium (ML engineer, nixpkgs committer)
  hardware.nvidia-container-toolkit.enable = true;

  # NVIDIA VRAM leak workaround for Niri
  # Without this, niri gradually consumes ~1 GiB VRAM instead of ~100 MiB
  # Source: https://github.com/niri-wm/niri/wiki/Nvidia
  # Conditional: only applied when niri is enabled (safe no-op otherwise)
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-niri-vram-fix.json" = {
    text = builtins.toJSON {
      rules = [{
        pattern = {
          feature = "procname";
          matches = "niri";
        };
        profile = "Limit Free Buffer Pool On Wayland Compositors";
      }];
      profiles = [{
        name = "Limit Free Buffer Pool On Wayland Compositors";
        settings = [{
          key = "GLVidHeapReuseRatio";
          value = 0;
        }];
      }];
    };
  };
}
```

#### 1.6.2 `optional/cuda.nix`

**What it does:** Installs the CUDA toolkit and ML libraries at the system level. Does NOT enable global `cudaSupport` -- that would cause every CUDA-capable package to rebuild from source.

**ML workflow:** The system provides CUDA libraries in `/run/opengl-driver` and the Nix store. Per-project `flake.nix` files (or the top-level `devShells.ml`) create dev shells with `LD_LIBRARY_PATH` pointing to these libraries. Users then `uv init && uv add torch` inside the shell (or add to existing pyproject.toml).

**Source mapping:** Replaces `sudo apt install nvidia-cuda-toolkit` and the manual CUDA PATH setup in `zsh/20-environment.zsh`.

```nix
# ~/.dotfiles/nix/modules/nixos/optional/cuda.nix
#
# System-level CUDA toolkit and ML libraries.
# Does NOT set global cudaSupport -- use per-project dev shells instead.
# Imported by hosts with role "cuda".
#
{ pkgs, lib, ... }:

{
  # CUDA toolkit and libraries installed system-wide
  # These provide the .so files that PyTorch/JAX need at runtime
  environment.systemPackages = with pkgs; [
    # Core CUDA
    cudaPackages.cudatoolkit    # nvcc, cuda_runtime.h, etc.
    cudaPackages.cuda_cudart    # CUDA runtime library
    cudaPackages.cuda_nvcc      # NVIDIA CUDA compiler
    cudaPackages.cuda_nvrtc     # Runtime compilation

    # Deep learning libraries
    cudaPackages.cudnn           # cuDNN (convolution, RNN, etc.)
    cudaPackages.nccl            # Multi-GPU communication (AllReduce, etc.)
    cudaPackages.cutensor        # Tensor contractions
    cudaPackages.libcublas       # BLAS on GPU
    cudaPackages.libcusparse     # Sparse matrix operations
    cudaPackages.libcurand       # Random number generation
    cudaPackages.libcufft        # FFT on GPU
    cudaPackages.libcusolver     # Dense/sparse linear solvers
    cudaPackages.libnvjitlink    # JIT linking for CUDA

    # Monitoring
    nvtopPackages.full           # GPU process monitor (like htop for GPUs)
  ];

  # Environment variables for CUDA discovery
  # These help PyTorch/JAX find the CUDA installation
  environment.variables = {
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    EXTRA_LDFLAGS = "-L${pkgs.linuxPackages.nvidia_x11}/lib";
  };
}
```

#### 1.6.3 `optional/niri.nix`

**What it does:** System-level Niri WM configuration. Enables the niri compositor, sets Wayland environment variables needed for NVIDIA GPUs, and configures XDG desktop portals for screen sharing.

**Note:** The niri-flake NixOS module (`inputs.niri.nixosModules.niri`) is imported in `mkHost.nix`, not here. This module sets the NixOS-level options that the niri module exposes.

**Source mapping:** New (Ubuntu uses GNOME on X11).

```nix
# ~/.dotfiles/nix/modules/nixos/optional/niri.nix
#
# System-level Niri window manager configuration.
# The niri-flake NixOS module is imported in mkHost.nix.
# This module sets niri-specific options and Wayland environment variables.
#
{ config, pkgs, ... }:

{
  # Enable niri (the niri-flake NixOS module handles the rest):
  # - Installs niri binary and systemd units
  # - Enables polkit with KDE auth agent
  # - Installs xdg-desktop-portal-gnome for screencasting
  # - Enables GNOME keyring and dconf
  # - Adds PAM entries for swaylock
  # - Configures the niri.cachix.org binary cache
  programs.niri.enable = true;

  # Wayland session environment variables
  # These are set system-wide so they apply to niri AND all apps launched within it
  environment.sessionVariables = {
    # Electron apps (VS Code, Discord, Slack, Obsidian) use native Wayland
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";

    # NVIDIA-specific Wayland variables
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Firefox uses Wayland natively
    MOZ_ENABLE_WAYLAND = "1";

    # Qt apps prefer Wayland, fall back to X11 (via xwayland-satellite)
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

    # SDL games prefer Wayland
    SDL_VIDEODRIVER = "wayland";

    # Wayland session type (some apps check this)
    XDG_SESSION_TYPE = "wayland";
  };

  # XDG desktop portal configuration for niri
  # Portals handle: file picker, screen sharing, notifications, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome  # Screen sharing, file picker
      pkgs.xdg-desktop-portal-gtk    # Fallback for GTK apps
    ];
    config.niri = {
      default = [ "gnome" "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      # Use GTK for file picker (avoids needing Nautilus)
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  # Packages needed for a usable Niri desktop
  environment.systemPackages = with pkgs; [
    wl-clipboard            # wl-copy, wl-paste (Wayland clipboard)
    cliphist                # Clipboard history manager
    grim                    # Screenshot capture
    slurp                   # Region selection (for grim)
    brightnessctl           # Backlight control
    playerctl               # MPRIS media control (play/pause/next)
    libnotify               # notify-send (for scripts)
    networkmanagerapplet    # nm-applet for system tray
    xdg-utils               # xdg-open, xdg-mime
    polkit_gnome            # Polkit auth agent (GUI sudo prompts)
  ];
}
```

#### 1.6.4 `optional/greetd.nix`

**What it does:** Configures greetd (a lightweight display manager) with tuigreet (a TUI greeter). This is what you see when NixOS boots -- a terminal-style login screen that launches niri-session.

```nix
# ~/.dotfiles/nix/modules/nixos/optional/greetd.nix
{ config, pkgs, ... }:

{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # tuigreet: a terminal UI greeter
        # --time: show clock
        # --asterisks: show * for password characters
        # --remember: remember last user
        # --remember-user-session: remember which session (niri) user picked
        # --sessions: path to wayland-sessions directory where niri registers
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --asterisks --remember --remember-user-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  # Suppress greetd error messages on tty1 (cosmetic)
  # Without this, boot messages leak through to the greeter
  systemd.services.greetd.serviceConfig = {
    Type = "idle";          # Wait for other services before starting
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };
}
```

#### 1.6.5 `optional/audio.nix`

**What it does:** Configures PipeWire for audio (replaces PulseAudio). PipeWire provides lower latency, better Bluetooth support, and Wayland-native audio.

```nix
# ~/.dotfiles/nix/modules/nixos/optional/audio.nix
{ ... }:

{
  # Disable PulseAudio (conflicts with PipeWire)
  hardware.pulseaudio.enable = false;

  # Enable PipeWire as the audio server
  services.pipewire = {
    enable = true;
    alsa.enable = true;        # ALSA compatibility (for games, etc.)
    alsa.support32Bit = true;  # 32-bit ALSA (for Steam 32-bit games)
    pulse.enable = true;       # PulseAudio compatibility layer
    wireplumber.enable = true; # Session manager (replaces pipewire-media-session)
  };

  # Enable real-time scheduling for PipeWire (lower latency)
  security.rtkit.enable = true;
}
```

#### 1.6.6 `optional/steam.nix`

**What it does:** Configures Steam with Proton, gamescope (a Wayland compositor for games), and gamemode (CPU governor optimization).

**Source mapping:** Replaces `flatpak install com.valvesoftware.Steam`. The native NixOS module is superior because it properly manages the FHS sandbox, 32-bit libraries, and NVIDIA driver injection.

```nix
# ~/.dotfiles/nix/modules/nixos/optional/steam.nix
#
# Gaming stack: Steam, Proton-GE, gamescope, gamemode.
# Per fufexan/dotfiles and ryan4yin/nix-config patterns.
#
{ pkgs, ... }:

{
  # Steam with Proton-GE (community Proton fork, better game compatibility)
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;       # Steam Remote Play
    dedicatedServer.openFirewall = true;  # Dedicated game servers
    gamescopeSession.enable = true;       # Gamescope compositing session
    extraCompatPackages = with pkgs; [
      proton-ge-bin  # GloriousEggroll's Proton fork
    ];
  };

  # Gamescope: a Wayland compositor specifically for games
  # Provides: resolution scaling, frame limiting, VRR, HDR
  programs.gamescope = {
    enable = true;
    capSysNice = true;  # Allow gamescope to set realtime priority
  };

  # Gamemode: optimizes CPU governor and I/O scheduler during gameplay
  programs.gamemode.enable = true;

  # Increase file descriptor limit for Steam (it opens many files)
  systemd.extraConfig = "DefaultLimitNOFILE=1048576";

  # Extra gaming packages
  environment.systemPackages = with pkgs; [
    mangohud      # FPS overlay, GPU/CPU stats in-game
    protonup-qt   # GUI for managing Proton versions
  ];
}
```

#### 1.6.7 `optional/tailscale.nix`

**What it does:** Enables the Tailscale mesh VPN for connecting to the homelab (tensor, jacobian, hessian).

```nix
# ~/.dotfiles/nix/modules/nixos/optional/tailscale.nix
{ ... }:

{
  services.tailscale.enable = true;

  # Tailscale needs to open a UDP port for WireGuard
  networking.firewall = {
    # Allow Tailscale's UDP port
    allowedUDPPorts = [ 41641 ];
    # Trust all traffic on the Tailscale interface
    trustedInterfaces = [ "tailscale0" ];
  };
}
```

#### 1.6.8 `optional/flatpak.nix`

```nix
# ~/.dotfiles/nix/modules/nixos/optional/flatpak.nix
{ ... }:

{
  # Flatpak for apps not in nixpkgs or better served as sandboxed apps
  # After install: flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  # Apps to install:
  #   flatpak install flathub md.obsidian.Obsidian
  #   flatpak install flathub com.discordapp.Discord
  #   flatpak install flathub com.google.Chrome
  #   flatpak install flathub org.telegram.desktop
  #   flatpak install flathub com.spotify.Client
  #   flatpak install flathub com.slack.Slack
  services.flatpak.enable = true;
}
```

#### 1.6.9 `optional/docker.nix`

```nix
# ~/.dotfiles/nix/modules/nixos/optional/docker.nix
{ ... }:

{
  # Docker with NVIDIA GPU support
  # nvidia-container-toolkit is enabled in nvidia.nix
  virtualisation.docker = {
    enable = true;
    # Use nvidia runtime by default for GPU containers
    enableNvidia = true;
  };
}
```

#### 1.6.10 `optional/filesystems-btrfs.nix`

**What it does:** Configures Btrfs maintenance: automatic snapshots via btrbk and monthly scrubs. The actual filesystem layout (subvolumes, mount options) is in `hardware-configuration.nix`.

```nix
# ~/.dotfiles/nix/modules/nixos/optional/filesystems-btrfs.nix
{ ... }:

{
  # btrbk: automated Btrfs snapshots
  # Hourly snapshots of @root and @home, retained for 7 days daily + 4 weeks weekly
  services.btrbk.instances.default = {
    onCalendar = "hourly";
    settings = {
      snapshot_preserve_min = "2d";
      snapshot_preserve = "7d 4w";
      volume."/mnt/btrfs-root" = {
        subvolume."@root".snapshot_dir = "@snapshots";
        subvolume."@home".snapshot_dir = "@snapshots";
      };
    };
  };

  # Mount the top-level Btrfs volume for btrbk to operate on
  fileSystems."/mnt/btrfs-root" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvolid=5" "noatime" ];
    neededForBoot = false;
  };

  # Monthly scrub: detects and reports bitrot
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
}

---

## Phase 2: Home-Manager Core Modules (Full Nix Rewrite)

**Goal:** Rewrite every user-level configuration file into native Nix modules managed by home-manager. After this phase, all shell, git, GPG, SSH, terminal, editor, and tmux configs are declarative Nix.

**Files to create:** All `nix/modules/home/*.nix`

**Entry point:** `nix/modules/home/default.nix` imports all sub-modules:

```nix
# ~/.dotfiles/nix/modules/home/default.nix
{ ... }:
{
  imports = [
    ./shell.nix
    ./prompt.nix
    ./environment.nix
    ./git.nix
    ./gpg.nix
    ./ssh.nix
    ./terminals.nix
    ./editor.nix
    ./tmux.nix
    ./cli-tools.nix
    ./dev-tools.nix
    ./fonts.nix
    ./xdg.nix
    ./claude.nix
    ./scripts.nix
    ./secrets.nix
    ./desktop/niri.nix
    ./desktop/waybar.nix
    ./desktop/fuzzel.nix
    ./desktop/mako.nix
    ./desktop/swaylock.nix
    ./desktop/swayidle.nix
    ./desktop/gtk-qt.nix
    ./desktop/desktop-apps.nix
  ];

  home.username = "beegass";
  home.homeDirectory = "/home/beegass";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}
```

---

### 2.1 `shell.nix` -- Zsh (Full Rewrite)

**What it does:** Replaces ALL 12 numbered zsh files (`00-init.zsh` through `90-local.zsh`) with native `programs.zsh` configuration. This is the most complex module because it must faithfully reproduce every alias, function, keybinding, and environment variable.

**Translation strategy:**
- `programs.zsh.enable` + plugin options replace `30-plugins.zsh`
- `programs.zsh.history` replaces history settings from `00-init.zsh`
- `programs.zsh.defaultKeymap = "viins"` replaces `70-keybindings.zsh`
- `programs.zsh.shellAliases` replaces `40-aliases.zsh`
- `programs.zsh.initExtra` holds everything that can't be expressed declaratively: functions from `50-functions.zsh`, GPU detection from `20-environment.zsh`, banner from `00-init.zsh`, Claude functions from `60-claude.zsh`
- `programs.zsh.completionInit` and `programs.zsh.initExtraBeforeCompInit` replace `60-completions.zsh`

**Source files translated:**
- `zsh/zshenv` -> `programs.zsh.envExtra`
- `zsh/00-init.zsh` -> `programs.zsh.initExtra` (banner, GPU probe, compinit)
- `zsh/10-oh-my-posh.zsh` -> `prompt.nix` (separate module)
- `zsh/20-environment.zsh` -> `environment.nix` + `programs.zsh.initExtra` (GPG agent wiring)
- `zsh/30-plugins.zsh` -> `programs.zsh.{autosuggestion,syntaxHighlighting,historySubstringSearch}`
- `zsh/40-aliases.zsh` -> `programs.zsh.shellAliases`
- `zsh/50-functions.zsh` -> `programs.zsh.initExtra`
- `zsh/60-claude.zsh` -> `programs.zsh.initExtra` (sources claude-functions.zsh)
- `zsh/60-completions.zsh` -> `programs.zsh.initExtraBeforeCompInit` + zstyle
- `zsh/70-keybindings.zsh` -> `programs.zsh.defaultKeymap` + `programs.zsh.initExtra`
- `zsh/80-tools.zsh` -> Handled by native home-manager modules (fzf, uv completions)
- `zsh/90-local.zsh` -> `programs.zsh.initExtra` sources `~/.zsh_local` if exists

```nix
# ~/.dotfiles/nix/modules/home/shell.nix
#
# Complete Zsh configuration. Replaces all 12 files in zsh/.
#
{ config, pkgs, lib, vars, ... }:

{
  programs.zsh = {
    enable = true;

    # --- Plugins (replaces zsh/30-plugins.zsh) ---
    # home-manager installs these to the Nix profile and sources them automatically
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    # --- History (replaces zsh/00-init.zsh lines 68-74) ---
    history = {
      size = 100000;         # HISTSIZE  (was 10000, upgrading for full rewrite)
      save = 100000;         # SAVEHIST
      path = "$HOME/.zsh_history";  # HISTFILE
      ignoreDups = true;     # HIST_IGNORE_DUPS
      share = true;          # SHARE_HISTORY
      extended = true;       # EXTENDED_HISTORY (add timestamps)
    };

    # --- Vi mode (replaces zsh/70-keybindings.zsh line 5: bindkey -v) ---
    defaultKeymap = "viins";

    # --- Aliases (replaces zsh/40-aliases.zsh) ---
    # Only include NixOS-relevant aliases. Platform-specific (Termux, macOS)
    # aliases are dropped since this is a full NixOS rewrite.
    shellAliases = {
      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      cp = "cp -i";
      mv = "mv -i";
      rm = "rm -i";

      # Editors / dotfiles
      n = "nvim";
      zshfig = "nvim ~/.dotfiles/zsh/zshrc";
      zshconfig = "cd ~/.dotfiles && nvim";

      # GPG / YubiKey
      yubioath = "ykman oath accounts list";
      "update-pin" = "export GPG_TTY=$(tty); gpg-connect-agent updatestartuptty /bye";
      keyconfirm = "gpg-connect-agent updatestartuptty /bye; export GPG_TTY=$(tty); export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket); gpgconf --launch gpg-agent; ssh-add -l";

      # UV / Python
      mkuv = "uv venv";
      activateuv = "source .venv/bin/activate";
      uvrun = "uv run";
      uvsync = "uv sync";
      uvlock = "uv lock";
      uvtool = "uv tool";

      # Zen-NV Dashboard
      nvtop = "uv run --project ~/.dotfiles/scripts/zen-nv zen-nv";
      zennv = "uv run --project ~/.dotfiles/scripts/zen-nv zen-nv";

      # YubiKey helpers
      yk = "yk-status";
      yklock = "yk-lock";

      # ls -> eza (eza is installed by cli-tools.nix)
      ls = "eza --classify --group-directories-first";
      ll = "eza -lgh --icons --group-directories-first";
      la = "eza -lgha --icons --group-directories-first";
      lt = "eza --tree --icons";

      # cat -> bat
      cat = "bat --paging=never --style=plain";

      # grep -> ripgrep
      grep = "rg -n --color=auto";
    };

    # --- Environment (replaces zsh/zshenv) ---
    envExtra = ''
      # XDG sane defaults
      : "''${XDG_CONFIG_HOME:=$HOME/.config}"
      : "''${XDG_DATA_HOME:=$HOME/.local/share}"
      : "''${XDG_STATE_HOME:=$HOME/.local/state}"
      : "''${XDG_CACHE_HOME:=$HOME/.cache}"
      export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME

      # Dedupe PATH
      typeset -U path PATH

      # Cargo env (for rustup-managed toolchains)
      [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
    '';

    # --- Completion config (replaces zsh/60-completions.zsh) ---
    # This runs BEFORE compinit
    initExtraBeforeCompInit = ''
      # Completion styling
      zstyle ':completion:*' menu select
      zstyle ':completion:*:*:*:*:*' menu select
      zstyle ':completion:*:matches' group 'yes'
      zstyle ':completion:*:options' description 'yes'
      zstyle ':completion:*:options' auto-description '%d'
      zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
      zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
      zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
      zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
      zstyle ':completion:*:default' list-prompt '%S%M matches%s'
      zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
      zstyle ':completion:*' group-name '''
      zstyle ':completion:*' verbose yes
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' list-suffixes
      zstyle ':completion:*' expand prefix suffix
      zmodload zsh/complist
    '';

    # --- Everything else (replaces 00-init, 20-env, 50-functions, 60-claude, 70-keys, 80-tools, 90-local) ---
    initExtra = ''
      # ── GPU probe (from 00-init.zsh) ──────────────────────────────────
      if command -v nvidia-smi >/dev/null 2>&1; then
        export BEEGASS_GPU_ENABLED=1
        export GPU_VENDOR=nvidia
      fi

      # ── Banner (from 00-init.zsh) ────────────────────────────────────
      if [[ -o interactive ]]; then
        if command -v pfetch >/dev/null 2>&1; then
          pfetch
        elif command -v neofetch >/dev/null 2>&1; then
          neofetch
        else
          print -P "%F{cyan}%n@%m%f  %D{%a %b %d, %I:%M %p}  %~"
        fi
      fi

      # ── Colored output (from 00-init.zsh) ────────────────────────────
      export CLICOLOR=1

      # ── GPG/SSH agent (from 20-environment.zsh) ──────────────────────
      # NOTE: The system-level programs.gnupg.agent handles starting the agent.
      # This block updates the TTY for pinentry and is safe to keep.
      if [[ -o interactive ]] && command -v gpgconf >/dev/null 2>&1; then
        export GPG_TTY="$(tty 2>/dev/null || true)"
        gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
        export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
      fi

      # ── Key IDs (from 20-environment.zsh) ────────────────────────────
      export KEYID=${vars.gpgKeys.master}
      export S_KEYID=${vars.gpgKeys.signing}
      export E_KEYID=${vars.gpgKeys.encryption}
      export A_KEYID=${vars.gpgKeys.authentication}

      # ── NVM (from 20-environment.zsh) ────────────────────────────────
      export NVM_DIR="$HOME/.nvm"
      [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

      # ── Directory bookmarks (from 20-environment.zsh) ────────────────
      hash -d projects=~/Projects
      hash -d downloads=~/Downloads
      hash -d docs=~/Documents
      hash -d dots=~/.dotfiles

      # ── Functions (from 50-functions.zsh) ────────────────────────────
      uvnew() {
        if [ -z "$1" ]; then
          echo "Usage: uvnew <project-name> [python-version]"
          return 1
        fi
        local project_name="$1"
        local python_version="''${2:-3.11}"
        mkdir -p "$project_name" && cd "$project_name"
        uv init && uv venv --python "$python_version"
        echo "Created new uv project: $project_name with Python $python_version"
      }

      uvsetup() {
        if [ -f "pyproject.toml" ]; then
          uv sync && source .venv/bin/activate
          echo "Dependencies installed and virtual environment activated"
        else
          echo "No pyproject.toml found in current directory"
          return 1
        fi
      }

      uvupgrade() {
        if [ -f "pyproject.toml" ]; then
          uv sync --all-extras && uv lock --upgrade
          echo "Dependencies upgraded and synced with all extras"
        else
          echo "No pyproject.toml found in current directory"
          return 1
        fi
      }

      allbranches() {
        git for-each-ref --format='%(refname:short)' refs/remotes | \
        while read remote; do
          git switch --create "''${remote#origin/}" --track "$remote" 2>/dev/null
        done
      }

      gpgmsg() {
        if [ -z "$1" ]; then echo "Usage: gpgmsg <recipient_email>"; return 1; fi
        gpg -se -r "$1"
      }

      load-secrets() {
        local script="''${DOTFILES_DIR:-$HOME/.dotfiles}/scripts/load-secrets.sh"
        if [[ ! -x "$script" ]]; then
          script="$(command -v load-secrets 2>/dev/null || true)"
        fi
        if [[ -z "$script" ]]; then echo "load-secrets not found" >&2; return 1; fi
        if [[ "''${1:-}" == --* ]]; then
          bash "$script" "$@"
        else
          eval "$(bash "$script")"
        fi
      }

      sfssh()    { command sf vms ssh -A "$@"; }
      sftunnel() { command sftunnel "$@"; }

      config() { command git --git-dir="$HOME/.cfg/" --work-tree="$HOME" "$@"; }

      # ── Claude functions (from 60-claude.zsh) ───────────────────────
      # Source the claude-functions.zsh file from the dotfiles repo
      # These are shell functions (dev, test, qc, branch-status) that are
      # tightly coupled to the dotfiles repo structure, so we source rather
      # than rewrite them
      [[ -f ~/.dotfiles/claude/claude-functions.zsh ]] && source ~/.dotfiles/claude/claude-functions.zsh

      export CLAUDE_PROJECT_ROOT="''${HOME}/Projects"
      export CLAUDE_PYTHON_VERSION="3.13"
      export UV_PYTHON_PREFERENCE="only-managed"

      # ── Keybindings (from 70-keybindings.zsh) ───────────────────────
      # Vi mode is set by defaultKeymap above. Additional bindings:
      bindkey '^S' history-incremental-search-forward
      if zle -l | grep -q '^history-substring-search-up$'; then
        bindkey '^[[A' history-substring-search-up
        bindkey '^[[B' history-substring-search-down
        bindkey '^P' history-substring-search-up
        bindkey '^N' history-substring-search-down
      fi

      # ── UV completions (from 80-tools.zsh) ──────────────────────────
      if command -v uv &> /dev/null; then
        eval "$(uv generate-shell-completion zsh 2>/dev/null)" || true
      fi

      # ── Delta pager (from 80-tools.zsh) ─────────────────────────────
      if command -v delta &> /dev/null; then
        export GIT_PAGER='delta'
      fi

      # ── Local overrides (from 90-local.zsh) ─────────────────────────
      # Machine-specific overrides in a gitignored file
      [[ -r ~/.zsh_local ]] && source ~/.zsh_local
    '';
  };
}
```

---

### 2.2 `prompt.nix` -- Oh My Posh

**What it does:** Installs Oh My Posh and generates the config.json from a Nix attrset using `builtins.toJSON`. This means the prompt config is fully declarative and type-checked at build time.

**Source mapping:** Translates `oh-my-posh/config.json` (214 lines of JSON) and `zsh/10-oh-my-posh.zsh` (initialization and theme-switching functions).

The Oh My Posh config is large (214 lines JSON with Unicode escapes for Nerd Font glyphs). Rather than inlining the entire attrset here, the implementation will use `builtins.toJSON` to convert a Nix attrset that exactly mirrors the current `config.json`. The init command goes in `programs.zsh.initExtra` (in shell.nix).

**Key elements to preserve:**
- Powerline left segments: OS icon, root indicator, path (folder style, max depth 3), git status with background templates (orange for changes, red for diverged, blue for ahead, orange for behind), execution time (threshold 500ms)
- Right segments: Python venv, Node.js, Rust, Julia, Go, time (3:04:05 PM format)
- Second line: status indicator (green `>` on success, red `>` on failure)
- Transient prompt: collapses previous prompts to just `>`
- Tooltips: git (on `git`/`g` commands), kubectl (on `kubectl`/`k` commands)

---

### 2.3 `git.nix`

**What it does:** Translates `git/gitconfig` (69 lines) into native `programs.git`.

**Source file:** `/home/beegass/.dotfiles/git/gitconfig`

```nix
# ~/.dotfiles/nix/modules/home/git.nix
{ pkgs, vars, ... }:

{
  programs.git = {
    enable = true;
    userName = vars.fullName;     # "Bryan Gass"
    userEmail = vars.email;       # "bryank123@live.com"

    signing = {
      key = vars.gpgKeys.signing; # "0xACC3640C138D96A2"
      signByDefault = true;
    };

    # Delta: syntax-highlighted diffs
    delta = {
      enable = true;
      options = {
        navigate = true;
        light = false;
        side-by-side = false;
        line-numbers = true;
      };
    };

    extraConfig = {
      github.user = vars.githubUser;  # "BeeGass"
      gpg.program = "gpg";
      push.autosetupremote = true;
      pull.rebase = false;
      init.defaultBranch = "main";

      merge = {
        conflictstyle = "diff3";
        tool = "vimdiff";
      };
      mergetool.keepBackup = false;
      "mergetool \"vimdiff\"".layout = "LOCAL,BASE,REMOTE / MERGED";

      diff.colorMoved = "default";
      interactive.diffFilter = "delta --color-only";

      credential.helper = "cache --timeout=7200";
    };

    aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
      ci = "commit";
      unstage = "reset HEAD --";
      last = "log -1 HEAD";
      visual = "!gitk";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
    };

    # Machine-specific overrides (credential helper on macOS, etc.)
    includes = [{ path = "~/.gitconfig.local"; }];
  };
}
```

---

### 2.4 `gpg.nix`

**Source files:** `gnupg/gpg.conf` (10 lines), `gnupg/linux-gpg-agent.conf` (6 lines)

```nix
# ~/.dotfiles/nix/modules/home/gpg.nix
{ pkgs, ... }:

{
  # GPG configuration (replaces gnupg/gpg.conf)
  programs.gpg = {
    enable = true;
    settings = {
      keyid-format = "0xlong";
      with-subkey-fingerprint = true;
      list-options = "show-uid-validity";
      verify-options = "show-uid-validity";
      use-agent = true;
      auto-key-retrieve = true;
      auto-key-locate = "local,wkd,keyserver,clear";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      cert-digest-algo = "SHA512";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
    };
  };

  # GPG agent (replaces gnupg/linux-gpg-agent.conf)
  # NOTE: The system-level programs.gnupg.agent in security.nix handles the
  # systemd service. This home-manager config sets user-level agent options.
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
    defaultCacheTtl = 1800;      # 30 min
    defaultCacheTtlSsh = 1800;
    maxCacheTtl = 7200;          # 2 hours
    maxCacheTtlSsh = 7200;
  };
}
```

---

### 2.5 `ssh.nix`

**Source file:** `ssh/config` (55 lines)

```nix
# ~/.dotfiles/nix/modules/home/ssh.nix
{ vars, ... }:

let
  sshPort = vars.networking.sshPort;  # 40822
  tailnet = vars.networking.tailnet;  # "tailf7d439.ts.net"
in
{
  programs.ssh = {
    enable = true;

    # Include GPG agent SSH socket drop-in
    includes = [ "~/.ssh/config.d/*.conf" ];

    matchBlocks = {
      # Default for all hosts
      "*" = {
        extraOptions = {
          PreferredAuthentications = "publickey";
          PubkeyAuthentication = "yes";
          IdentitiesOnly = "no";
        };
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
        forwardAgent = false;
      };

      # Tailscale hosts: RPi (Jacobian, Hessian)
      "Jacobian Hessian" = {
        hostname = "%h.${tailnet}";
        user = vars.username;
        port = sshPort;
        forwardAgent = false;
      };

      # Tailscale hosts: workstations/servers
      "Tensor Matrix Vector Manifold" = {
        hostname = "%h.${tailnet}";
        user = vars.username;
        port = sshPort;
        forwardAgent = false;
      };

      # GitHub
      "github.com github" = {
        hostname = "github.com";
        user = "git";
        port = 22;
        forwardAgent = false;
      };

      # mcopp with GPG agent forwarding
      "mcopp" = {
        hostname = "mcopp.com";
        user = vars.username;
        port = 12211;
        requestTTY = true;
        forwardAgent = true;
        extraOptions = {
          StreamLocalBindUnlink = "yes";
          IdentitiesOnly = "no";
        };
      };
    };

    # OS-conditional GPG agent socket forwarding for mcopp
    extraConfig = ''
      Match host mcopp exec "uname -s | grep -q Linux"
          RemoteForward /run/user/1001/gnupg/S.gpg-agent     /run/user/1000/gnupg/S.gpg-agent.extra
          RemoteForward /run/user/1001/gnupg/S.gpg-agent.ssh /run/user/1000/gnupg/S.gpg-agent.ssh
    '';
  };
}
```

---

### 2.6 `terminals.nix`

**What it does:** Generates Ghostty config (primary terminal), Kitty config (backup), and WezTerm config (backup) as Nix-managed text files.

**Source files:** `ghostty/config` (62 lines), `kitty/kitty.conf` (46 lines), `wezterm/wezterm.lua` (79 lines)

**Key change from Ubuntu:** Kitty drops `linux_display_server x11` (was for picom on X11; not needed on Wayland/Niri).

```nix
# ~/.dotfiles/nix/modules/home/terminals.nix
{ pkgs, ... }:

{
  # Ghostty (primary terminal)
  home.packages = [ pkgs.ghostty ];
  xdg.configFile."ghostty/config".text = ''
    # Appearance
    background = 000000
    foreground = ffffff
    background-opacity = 0.80
    background-opacity-cells = true
    background-blur = true
    unfocused-split-opacity = 0.85

    # Window
    window-decoration = client
    window-padding-x = 10
    window-padding-y = 10
    window-padding-balance = true

    # Tabs (GTK)
    window-show-tab-bar = auto
    gtk-tabs-location = top
    gtk-wide-tabs = true
    gtk-titlebar-style = tabs

    # Font fallback chain
    font-family = Google Sans Mono
    font-family = JetBrains Mono
    font-family = SF Mono
    font-family = Symbols Nerd Font Mono
    font-size = 10

    # Cursor
    cursor-style = bar
    cursor-style-blink = true

    # Unbind Alt+1-9 so they pass through to tmux
    keybind = alt+1=unbind
    keybind = alt+2=unbind
    keybind = alt+3=unbind
    keybind = alt+4=unbind
    keybind = alt+5=unbind
    keybind = alt+6=unbind
    keybind = alt+7=unbind
    keybind = alt+8=unbind
    keybind = alt+9=unbind

    # Behavior
    right-click-action = paste
    scrollback-limit = 16777216

    # Auto-start tmux via login shell
    command = zsh -l -c "tmux -u new-session -A -s main"
  '';

  # Kitty (backup terminal) -- Wayland native (dropped linux_display_server x11)
  xdg.configFile."kitty/kitty.conf".text = ''
    foreground #ffffff
    background #000000
    background_opacity 0.80
    window_padding_width 10
    tab_bar_style hidden
    font_family      family="Google Sans Mono"
    bold_font        auto
    italic_font      auto
    bold_italic_font auto
    font_size 10.0
    symbol_map U+23FB-U+23FE,U+2665,U+26A1,U+276C-U+2771,U+2B58,U+E000-U+F8FF,U+F0001-U+F1AF0 JetBrainsMono Nerd Font Mono
    cursor_shape beam
    cursor_blink_interval 0.5
    repaint_delay 8
    scrollback_lines 10000
    sync_to_monitor yes
    shell zsh -l -c "tmux -u new-session -A -s main"
    mouse_map right press ungrabbed paste_from_clipboard
    map f11 toggle_fullscreen
  '';

  # WezTerm (backup terminal) -- Lua config
  xdg.configFile."wezterm/wezterm.lua".text = builtins.readFile ../../../wezterm/wezterm.lua;
  # NOTE: WezTerm's Lua config is complex enough that we read the existing file
  # rather than generating it from Nix. This is an exception to the "full rewrite" rule.
}
```

---

### 2.7 `editor.nix`

**What it does:** Configures Neovim with the existing vimrc (534 lines) loaded via `extraConfig`. The vimrc is too complex (Colemak-DH remapping, vim-plug with 20+ plugins, which-key, ALE, LSP, easymotion) to rewrite in Nix's `programs.neovim.plugins` API. Instead, we use Neovim's native module and load the vimrc as `extraConfig`.

```nix
# ~/.dotfiles/nix/modules/home/editor.nix
{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;     # `vi` -> `nvim`
    vimAlias = true;    # `vim` -> `nvim`

    # Load the existing vimrc wholesale
    # This preserves vim-plug, Colemak-DH remapping, all plugin configs
    extraConfig = builtins.readFile ../../../vim/vimrc;
  };

  # Also keep vim as a fallback (some scripts expect /usr/bin/vim)
  home.packages = [ pkgs.vim ];
}
```

---

### 2.8 `tmux.nix`

**What it does:** Configures tmux using `programs.tmux` for basic settings and `extraConfig` for the full tmux.conf content (432 lines). The tmux config is too complex for full Nix-native rewriting (conditional clipboard detection, GPU monitoring, TPM plugins, platform-specific overrides).

```nix
# ~/.dotfiles/nix/modules/home/tmux.nix
{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    # Basic settings that programs.tmux handles natively:
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 10000;
    terminal = "tmux-256color";
    prefix = "C-Space";

    # TPM plugins via home-manager
    plugins = with pkgs.tmuxPlugins; [
      sensible
      cpu
      resurrect
      continuum
      open
      sidebar
    ];

    # The full tmux.conf loaded as extraConfig
    # This includes: Alt-key bindings, status bar, clipboard detection,
    # GPU monitoring, platform-specific settings, and all custom keybindings
    extraConfig = builtins.readFile ../../../tmux/tmux.conf;
  };

  # TPM bootstrap (tmux plugin manager)
  home.activation.installTpm = pkgs.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
  '';
}
```

---

### 2.9 `cli-tools.nix`

**Source:** Replaces tool integration from `zsh/80-tools.zsh` and packages from `install/ubuntu-install.sh`.

```nix
# ~/.dotfiles/nix/modules/home/cli-tools.nix
{ pkgs, ... }:

{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;  # Adds ^R history search, ^T file search, Alt+C cd
    defaultOptions = [ "--height" "40%" "--layout=reverse" "--border" ];
    defaultCommand = "rg --files --hidden --follow --glob '!.git/*'";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
    fileWidgetCommand = "rg --files --hidden --follow --glob '!.git/*'";
  };

  programs.bat = {
    enable = true;
    config.theme = "TwoDark";
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = false;  # Custom aliases in shell.nix
  };

  programs.ripgrep.enable = true;

  home.packages = with pkgs; [
    fd              # find alternative
    jq              # JSON processor
    curl wget       # HTTP clients
    unzip           # Archive extraction
    tree            # Directory tree view
    htop            # Process monitor
    w3m             # Terminal web browser
    chafa           # Terminal image viewer
    neofetch        # System info display
    pfetch          # Minimal system info
    shellcheck      # Shell script linter
    shfmt           # Shell script formatter
    delta           # Syntax-highlighted diffs (for git)
  ];
}
```

---

### 2.10 `dev-tools.nix`

```nix
# ~/.dotfiles/nix/modules/home/dev-tools.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Python
    uv              # Python package manager (replaces pip, poetry, conda)
    python312       # System Python for scripts

    # Rust (rustup manages toolchains in ~/.cargo)
    rustup

    # Node.js (system default; nvm can override per-project)
    nodejs_22

    # Build tools
    just            # Task runner (dotfiles use this)
    gnumake
    gcc

    # Dev utilities
    gh              # GitHub CLI
    pre-commit      # Git pre-commit hooks
  ];

  # uv tool installs for development (Python LSP, linting, etc.)
  # These are installed imperatively via activation script because
  # uv manages its own tool store in ~/.local/share/uv/tools/
  home.activation.installUvTools = pkgs.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v uv &>/dev/null; then
      uv tool install python-lsp-server 2>/dev/null || true
      uv tool install ruff 2>/dev/null || true
      uv tool install mypy 2>/dev/null || true
      uv tool install pytest 2>/dev/null || true
    fi
  '';
}
```

---

### 2.11 `fonts.nix`

**Source:** `fontconfig/30-google-sans-mono-mono.conf` (8 lines XML)

```nix
# ~/.dotfiles/nix/modules/home/fonts.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono      # JetBrains Mono Nerd Font
    nerd-fonts.symbols-only        # Symbols-only Nerd Font (icon fallback)
    # Google Sans Mono: check nixpkgs. If not available, use overlay.
    # google-fonts                  # may include Google Sans Mono
  ];

  # Fontconfig: force Google Sans Mono to monospace spacing
  # Replaces: fontconfig/30-google-sans-mono-mono.conf
  xdg.configFile."fontconfig/conf.d/30-google-sans-mono-mono.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <match target="scan">
        <test name="family" compare="eq"><string>Google Sans Mono</string></test>
        <edit name="spacing" mode="assign"><int>100</int></edit>
      </match>
    </fontconfig>
  '';
}
```

---

### 2.12 `xdg.nix`

```nix
# ~/.dotfiles/nix/modules/home/xdg.nix
{ config, ... }:

{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
      music = "${config.home.homeDirectory}/Music";
      desktop = "${config.home.homeDirectory}/Desktop";
    };
  };
}
```

---

### 2.13 `claude.nix`

**What it does:** Symlinks Claude Code configuration files and creates 4 systemd user services for Claude Remote Control.

**Why symlinks here:** Claude configs (settings.json, CLAUDE.md, commands/, hooks/, rules/) are JSON/markdown that reference other files in the repo. They're not shell or system config -- they're consumed by the Claude Code binary. Symlinking via `mkOutOfStoreSymlink` is the correct approach here. This is the one exception to the "full Nix rewrite" rule.

```nix
# ~/.dotfiles/nix/modules/home/claude.nix
{ config, pkgs, lib, vars, ... }:

let
  link = config.lib.file.mkOutOfStoreSymlink;
  dotfiles = vars.dotfilesPath;  # "/home/beegass/.dotfiles"

  # Helper to create a Claude RC systemd user service
  mkClaudeRC = name: displayName: workDir: {
    Unit = {
      Description = "Claude Code Remote Control - ${displayName}";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${config.home.homeDirectory}/.local/bin/claude remote-control --name \"${displayName}\"";
      WorkingDirectory = workDir;
      Environment = [
        "PATH=${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin"
        "NODE_OPTIONS=--max-old-space-size=4096"
      ];
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
in
{
  # Symlink Claude Code configuration files
  home.file.".claude/settings.json".source = link "${dotfiles}/claude/settings.json";
  home.file.".claude/CLAUDE.md".source = link "${dotfiles}/claude/CLAUDE.md";
  home.file.".claude/commands".source = link "${dotfiles}/claude/commands";
  home.file.".claude/rules".source = link "${dotfiles}/claude/rules";
  xdg.configFile."claude/CLAUDE.md".source = link "${dotfiles}/claude/CLAUDE.md";

  # Claude Remote Control systemd user services
  systemd.user.services = {
    claude-rc-manifold  = mkClaudeRC "manifold"  "Manifold"          config.home.homeDirectory;
    claude-rc-projects  = mkClaudeRC "projects"  "Manifold Projects" "${config.home.homeDirectory}/Projects";
    claude-rc-freectrl  = mkClaudeRC "freectrl"  "Manifold FreeCtrl" "${config.home.homeDirectory}/Projects/FreeCtrl";
    claude-rc-rsde      = mkClaudeRC "rsde"      "Manifold RSDE"     "${config.home.homeDirectory}/Projects/RSDE";
  };
}
```

---

### 2.14 `scripts.nix`

```nix
# ~/.dotfiles/nix/modules/home/scripts.nix
{ config, vars, ... }:

let
  link = config.lib.file.mkOutOfStoreSymlink;
  scriptDir = "${vars.dotfilesPath}/scripts";
in
{
  # Symlink utility scripts to ~/.local/bin (both with and without .sh)
  home.file = {
    ".local/bin/doctor".source      = link "${scriptDir}/doctor.sh";
    ".local/bin/doctor.sh".source   = link "${scriptDir}/doctor.sh";
    ".local/bin/load-secrets".source    = link "${scriptDir}/load-secrets.sh";
    ".local/bin/load-secrets.sh".source = link "${scriptDir}/load-secrets.sh";
    ".local/bin/nf".source          = link "${scriptDir}/neofetch_random.sh";
    ".local/bin/setup_gpg_ssh.sh".source = link "${scriptDir}/setup_gpg_ssh.sh";
    ".local/bin/sfssh".source       = link "${scriptDir}/sfssh";
    ".local/bin/sftunnel".source    = link "${scriptDir}/sftunnel";
    ".local/bin/yk-gpg-refresh.sh".source = link "${scriptDir}/yk-gpg-refresh.sh";
    ".local/bin/yk-refresh".source  = link "${scriptDir}/yk-gpg-refresh.sh";
    ".local/bin/yk-lock".source     = link "${scriptDir}/yk-lock.sh";
    ".local/bin/yk-lock.sh".source  = link "${scriptDir}/yk-lock.sh";
    ".local/bin/yk-status".source   = link "${scriptDir}/yk-status.sh";
    ".local/bin/yk-status.sh".source = link "${scriptDir}/yk-status.sh";
  };
}
```

---

### 2.15 `secrets.nix` + `environment.nix`

```nix
# ~/.dotfiles/nix/modules/home/secrets.nix
{ pkgs, ... }:
{
  # pass is installed system-level in security.nix
  # This module ensures the password store directory exists
  home.file.".password-store/.keep".text = "";
}
```

```nix
# ~/.dotfiles/nix/modules/home/environment.nix
{ vars, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    CLAUDE_CODE_MAX_OUTPUT_TOKENS = "64000";
    BAT_THEME = "TwoDark";
  };

  # Ensure ~/.local/bin is on PATH
  home.sessionPath = [ "$HOME/.local/bin" "$HOME/.cargo/bin" ];
}

---

## Phase 3: Desktop Environment (Niri + Wayland Stack)

**Goal:** Create the complete Niri desktop environment with waybar, fuzzel, mako, swaylock, and consistent dark+amber theming.

The Niri config is the largest single module. Full `programs.niri.settings` Nix code is provided in the implementation. Key design decisions documented here; full code will be written during implementation following the patterns from vlaci, louis-thevenet, and KiaraGrouwstra configs.

### 3.1 `desktop/niri.nix` -- Niri WM (Nix-native)

**Complete `programs.niri.settings` to implement:**

**Input section:**
- `keyboard.xkb.layout = "us"` (Colemak-DH is firmware-level on ZSA Voyager -- setting xkb variant would double-remap)
- `keyboard.xkb.options = "ctrl:nocaps"` (Caps Lock -> Ctrl)
- `keyboard.repeat-delay = 300` / `keyboard.repeat-rate = 50`
- `mouse.accel-profile = "flat"` (no acceleration for precision)
- `focus-follows-mouse.enable = false`
- `warp-mouse-to-focus.enable = false`
- `power-key-handling.enable = true`

**Layout section:**
- `gaps = 8`
- `focus-ring = { enable = true; width = 3; active.color = "#f7ca88"; inactive.color = "#33333380"; urgent.color = "#ff5252"; }`
- `border.enable = false` (using focus-ring instead)
- `shadow = { enable = true; color = "#00000070"; offset = { x = 0; y = 4; }; softness = 20; }`
- `preset-column-widths = [{ proportion = 1.0/3.0; } { proportion = 1.0/2.0; } { proportion = 2.0/3.0; }]`
- `default-column-width = { proportion = 1.0/2.0; }`
- `center-focused-column = "never"` (or "on-overflow")

**Keybindings (using `config.lib.niri.actions`):**

| Binding | Action | Notes |
|---------|--------|-------|
| `Mod+Return` | `spawn "ghostty"` | Primary terminal |
| `Mod+D` | `spawn "fuzzel"` | App launcher |
| `Mod+Q` | `close-window` | |
| `Mod+Shift+E` | `quit` | With confirmation |
| `Mod+R` | `focus-column-left` | Colemak-DH left |
| `Mod+S` | `focus-window-or-workspace-down` | Colemak-DH down |
| `Mod+F` | `focus-window-or-workspace-up` | Colemak-DH up |
| `Mod+T` | `focus-column-right` | Colemak-DH right |
| `Mod+Shift+R/S/F/T` | `move-column-left/down/up/right` | Move windows |
| `Mod+Left/Right/Up/Down` | focus fallbacks | Arrow key fallbacks |
| `Mod+1-9` | `focus-workspace N` | Workspace nav |
| `Mod+Shift+1-9` | `move-column-to-workspace N` | Move to workspace |
| `Mod+Ctrl+R/T/F/S` | focus-monitor-left/right/up/down | Multi-monitor |
| `Mod+W` | `switch-preset-column-width` | Cycle 1/3, 1/2, 2/3 |
| `Mod+Shift+W` | `switch-preset-window-height` | Cycle heights |
| `Mod+M` | `maximize-column` | |
| `Mod+Shift+M` | `fullscreen-window` | |
| `Mod+C` | `center-column` | |
| `Mod+Comma` | `consume-window-into-column` | Stack windows |
| `Mod+Period` | `expel-window-from-column` | Unstack |
| `Mod+Tab` | `toggle-column-tabbed-display` | Tabbed view |
| `Mod+V` | `toggle-window-floating` | |
| `Mod+O` | `toggle-overview` | `repeat = false` |
| `Mod+L` | `spawn ["swaylock" "-f"]` | Lock screen |
| `Print` | `screenshot` | Interactive UI |
| `Mod+Print` | `screenshot-screen` | Current screen |
| `Mod+Shift+V` | clipboard history via cliphist+fuzzel | |
| `Mod+WheelScroll*` | workspace up/down | `cooldown-ms = 150` |
| `XF86Audio*` | wpctl volume/mute | `allow-when-locked = true` |
| `XF86MonBrightness*` | brightnessctl | |

**Alt is completely reserved for tmux** -- zero Alt bindings in Niri.

**Global settings:** `prefer-no-csd = true`, `hotkey-overlay.skip-at-startup = true`, `screenshot-path = "~/Pictures/Screenshots/screenshot-%Y-%m-%d-%H%M%S.png"`, `cursor = { hide-after-inactive-ms = 1000; hide-when-typing = true; }`

**Spawn at startup:** `waybar`, `mako`, `swayidle -w timeout 300 "swaylock -f" timeout 600 "niri msg action power-off-monitors" before-sleep "swaylock -f"`, `swaybg --mode fill --color "#000000"`, `nm-applet --indicator`, `wl-paste --type text --watch cliphist store`, `wl-paste --type image --watch cliphist store`, `polkit-gnome-authentication-agent-1`

**Named workspaces:** `1-term`, `2-web`, `3-code`, `4-notes`, `5-chat`, `6-media`, `7-misc`, `8-misc2`, `9-steam`

**Window rules:**
1. All windows: `geometry-corner-radius = 8.0` all corners, `clip-to-geometry = true`
2. File/Save/Open dialogs, About, Preferences, Settings: `open-floating = true`
3. Firefox/Chrome PiP: `open-floating = true`, fixed 480x270
4. Steam non-main windows: `open-floating = true`
5. Discord/Telegram/Slack: `open-on-workspace = "5-chat"`
6. Obsidian: `open-on-workspace = "4-notes"`
7. Spotify: `open-on-workspace = "6-media"`
8. Steam main: `open-on-workspace = "9-steam"`
9. Pinentry: `block-out-from = "screencast"`

---

### 3.2 `desktop/waybar.nix`

Full `programs.waybar` with settings and CSS. `systemd.enable = false` (niri manages lifecycle via spawn-at-startup).

**Modules:** `niri/workspaces` (icons), `niri/window` (with rewrite rules), `clock`, `tray`, `network`, `cpu`, `memory`, `custom/gpu` (nvidia-smi polling 5s), `pulseaudio`, `custom/lock`

**CSS color palette:** bg `#1a1a1a` at 90% opacity, amber `#f7ca88` for active workspace/pulseaudio/lock, purple `#9d7cd8` for memory, blue `#7fc8ff` for cpu/network, green `#76b568` for gpu/battery, red `#ff5252` for critical battery, muted `#686868` for inactive.

### 3.3 `desktop/fuzzel.nix`

```nix
programs.fuzzel = {
  enable = true;
  settings = {
    main = { font = "Google Sans Mono:size=12"; terminal = "ghostty -e"; prompt = "  "; width = 40; lines = 12; horizontal-pad = 20; vertical-pad = 12; border-width = 2; border-radius = 8; layer = "overlay"; };
    colors = { background = "1a1a1aee"; text = "ffffffff"; selection = "f7ca88ff"; selection-text = "1a1a1aff"; border = "333333ff"; match = "f7ca88ff"; selection-match = "1a1a1aff"; };
  };
};
```

### 3.4 `desktop/mako.nix`

```nix
services.mako = {
  enable = true;
  settings = {
    font = "Google Sans Mono 10"; background-color = "#1a1a1aee"; text-color = "#ffffffff"; border-color = "#333333ff"; border-size = 2; border-radius = 8; width = 380; height = 120; padding = "12"; margin = "8"; anchor = "top-right"; default-timeout = 5000; layer = "overlay"; max-visible = 3;
    "[urgency=critical]" = { border-color = "#ff5252ff"; default-timeout = 0; };
  };
};
```

### 3.5 `desktop/swaylock.nix`

`programs.swaylock` with `swaylock-effects`: screenshot blur (`effect-blur = "10x5"`), clock, indicator ring (amber keypress, purple verify, red wrong), grace period 3s, fade-in 0.2s. Google Sans Mono font size 24.

### 3.6 `desktop/gtk-qt.nix`

```nix
gtk = { enable = true; theme = { name = "Adwaita-dark"; package = pkgs.gnome-themes-extra; }; iconTheme = { name = "Adwaita"; }; cursorTheme = { name = "Adwaita"; size = 24; }; font = { name = "Google Sans"; size = 11; }; gtk3.extraConfig.gtk-application-prefer-dark-theme = true; gtk4.extraConfig.gtk-application-prefer-dark-theme = true; };
qt = { enable = true; platformTheme.name = "adwaita"; style.name = "adwaita-dark"; };
dconf.settings."org/gnome/desktop/interface" = { color-scheme = "prefer-dark"; };
```

### 3.7 `desktop/desktop-apps.nix`

XDG MIME defaults (Chrome for web, Evince for PDF). Flatpak app installation via `home.activation` script: Obsidian, Discord, Chrome, Telegram, Spotify, Slack. VS Code `.desktop` entry with `--ozone-platform=wayland`.

---

## Phase 4: Overlays + Justfile

### 4.1 `overlays/default.nix`

Custom font derivation for Google Sans Mono (if not in nixpkgs):
```nix
# Fetch Google Sans Mono from the private repo or local font files
google-sans-mono = pkgs.stdenvNoCC.mkDerivation {
  pname = "google-sans-mono";
  version = "1.0";
  src = /* font files from existing install or GitHub clone */;
  installPhase = ''
    mkdir -p $out/share/fonts/truetype
    cp *.ttf $out/share/fonts/truetype/
  '';
};
```

### 4.2 Justfile Additions

```just
# NixOS management
[group('nixos')]
[linux]
nixos-switch:
    sudo nixos-rebuild switch --flake {{DOTFILES_DIR}}#manifold

[group('nixos')]
[linux]
nixos-test:
    sudo nixos-rebuild test --flake {{DOTFILES_DIR}}#manifold

[group('nixos')]
[linux]
nixos-boot:
    sudo nixos-rebuild boot --flake {{DOTFILES_DIR}}#manifold

[group('nixos')]
[linux]
nixos-build:
    nixos-rebuild build --flake {{DOTFILES_DIR}}#manifold

[group('nixos')]
[linux]
nixos-update:
    nix flake update --flake {{DOTFILES_DIR}}

[group('nixos')]
[linux]
nixos-gc:
    sudo nix-collect-garbage -d && nix-collect-garbage -d
```

---

## Phase 5: Development Workflow (Writing on Ubuntu, Testing on Fresh NixOS Install)

**Reality:** We are writing all Nix configs on the current Ubuntu machine WITHOUT the ability to run `nix build` or `nixos-rebuild`. The Nix daemon is not installed on this machine and we cannot validate configs locally.

**Strategy:**
1. Write all ~40 Nix files on a dedicated git branch (`nix` branch) in this dotfiles repo
2. Push the branch to GitHub
3. On a fresh NixOS install (USB boot or separate machine), clone the repo and apply the flake
4. Fix any evaluation or runtime errors on the NixOS machine, push fixes back
5. Iterate until the config is stable, then merge to `main`

**Implications:**
- We must be extra careful with Nix syntax (typos won't be caught until install time)
- Use well-tested patterns from reference configs (Misterio77, ryan4yin, vlaci) rather than inventing novel approaches
- Keep modules small and self-contained so individual issues are easy to isolate
- Add comments explaining WHY each option is set, so debugging on the NixOS machine is faster
- The `hardware-configuration.nix` will be a stub until `nixos-generate-config` runs on real hardware

**Git workflow:**
```bash
# On current Ubuntu machine:
git checkout -b nix
# ... write all files ...
git add nix/ flake.nix flake.lock
git commit -m "feat(nix): add NixOS + Niri flake configuration"
git push -u origin nix

# On fresh NixOS install (from USB):
git clone https://github.com/BeeGass/.dotfiles
cd .dotfiles && git checkout nix
nixos-generate-config --root /mnt  # generates real hardware-configuration.nix
cp /mnt/etc/nixos/hardware-configuration.nix nix/hosts/manifold/hardware-configuration.nix
nixos-install --flake .#manifold
# Fix errors, commit, push, iterate
```

---

## Phase 6: Install NixOS

**Goal:** Flash NixOS, partition nvme0n1 with Btrfs, install the system.

### 6.1 Preparation

```bash
# Download NixOS minimal installer ISO (latest unstable)
# https://nixos.org/download#nixos-iso
# Flash to USB: dd if=nixos-*.iso of=/dev/sdX bs=4M status=progress

# Back up EVERYTHING before proceeding:
# - /home/beegass -> external drive
# - /data -> verify nvme1n1 is NOT nvme0n1 (double check with `lsblk`)
# - ~/.password-store -> git push to remote
# - Any uncommitted work in ~/Projects
```

### 6.2 Partitioning (in NixOS installer)

```bash
# Boot from USB, select "NixOS Installer"
# Connect to internet: nmtui or ethernet

# Identify drives:
lsblk
# nvme0n1 = Samsung 9100 PRO 2TB (WIPE THIS)
# nvme1n1 = WD_BLACK SN850X 2TB (KEEP - /data)

# Partition nvme0n1:
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary btrfs 512MiB 100%

# Label partitions:
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.btrfs -L nixos -f /dev/nvme0n1p2

# Create Btrfs subvolumes:
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@persist
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Mount subvolumes:
mount -o subvol=@root,compress=zstd,noatime /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{home,nix,var/log,persist,boot,data}
mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p2 /mnt/home
mount -o subvol=@nix,compress=zstd,noatime /dev/nvme0n1p2 /mnt/nix
mount -o subvol=@log,compress=zstd,noatime /dev/nvme0n1p2 /mnt/var/log
mount -o subvol=@persist,compress=zstd,noatime /dev/nvme0n1p2 /mnt/persist
mount /dev/nvme0n1p1 /mnt/boot

# Mount existing /data (READ ONLY first to verify it's the right drive):
mount -o ro /dev/nvme1n1p1 /mnt/data
ls /mnt/data  # Verify this is your data drive
umount /mnt/data
mount /dev/nvme1n1p1 /mnt/data  # Re-mount read-write
```

### 6.3 Install

```bash
# Generate hardware config:
nixos-generate-config --root /mnt

# Clone dotfiles:
nix-shell -p git
git clone https://github.com/BeeGass/.dotfiles /mnt/home/beegass/.dotfiles

# Copy generated hardware-configuration.nix to the right place:
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/beegass/.dotfiles/nix/hosts/manifold/hardware-configuration.nix

# Install NixOS:
nixos-install --flake /mnt/home/beegass/.dotfiles#manifold --no-root-passwd

# Set user password:
nixos-enter --root /mnt -c 'passwd beegass'

# Reboot:
reboot
```

---

## Phase 7: Post-Install Verification

**Complete checklist -- verify each item after first boot:**

| # | Test | Command | Expected Result |
|---|------|---------|----------------|
| 1 | Boot to greetd | (automatic) | tuigreet TUI with niri session listed |
| 2 | Login + niri | Enter password, select niri | Niri desktop with waybar at top |
| 3 | NVIDIA driver | `nvidia-smi` | RTX 5090 detected, driver 580.x |
| 4 | Niri version | `niri msg version` | niri version string |
| 5 | Terminal | `Mod+Return` | Ghostty opens with tmux session |
| 6 | App launcher | `Mod+D` | Fuzzel opens with dark theme |
| 7 | YubiKey/GPG | Insert YubiKey, `gpg --card-status` | Card serial, key IDs shown |
| 8 | SSH agent | `ssh-add -l` | GPG auth key listed |
| 9 | Tailscale | `sudo tailscale up` then `ssh Tensor` | Connected to mesh, SSH works |
| 10 | Git signing | `git commit -S -m "test"` in a repo | Signed commit, no errors |
| 11 | Pass secrets | `pass show api/ANTHROPIC_API_KEY` | API key decrypted via YubiKey |
| 12 | Claude Code | `npm i -g @anthropic-ai/claude-code` then `claude` | Claude starts |
| 13 | Claude RC | `systemctl --user status claude-rc-*` | 4 services active |
| 14 | Flatpak | `flatpak remote-add flathub ...` then install apps | Apps launch from Fuzzel |
| 15 | Steam | Launch from Fuzzel | Steam loads, library visible |
| 16 | Steam game | Launch a Proton game | Game runs with NVIDIA GPU |
| 17 | CUDA/PyTorch | `nix develop .#ml` then `uv init && uv add torch && uv run python -c "import torch; print(torch.cuda.is_available())"` | `True` |
| 18 | Screenshot | `Print` key | Niri screenshot UI, saves to ~/Pictures/Screenshots |
| 19 | Screen lock | `Mod+L` | Swaylock with blur + clock |
| 20 | Notifications | `notify-send "Test" "Hello"` | Mako notification top-right |
| 21 | Clipboard | Copy text, `Mod+Shift+V` | Cliphist history via fuzzel |
| 22 | Waybar GPU | Check right side of waybar | GPU utilization percentage shown |
| 23 | Audio | Play audio in browser | Sound through PipeWire |
| 24 | Workspace nav | `Mod+1` through `Mod+9` | Workspace switching works |
| 25 | Window tiling | Open 2+ windows | Scrollable tiling, amber focus ring |

---

## Implementation Order (File Creation Sequence)

All files written on the current Ubuntu machine, committed to the `nix` branch.
Validation happens later on the NixOS target machine.

| Step | Files | Notes |
|------|-------|-------|
| 1 | `flake.nix`, `nix/lib/mkHost.nix`, `nix/vars/default.nix` | Foundation -- everything depends on this |
| 2 | `nix/modules/nixos/common/default.nix` + all 6 common modules | boot, nix-settings, networking, users, security, services |
| 3 | `nix/modules/nixos/optional/nvidia.nix`, `cuda.nix` | Highest-risk module (GPU driver) |
| 4 | `nix/modules/nixos/optional/niri.nix`, `greetd.nix`, `audio.nix` | Desktop session stack |
| 5 | `nix/modules/nixos/optional/steam.nix`, `tailscale.nix`, `flatpak.nix`, `docker.nix`, `filesystems-btrfs.nix` | Remaining optional system modules |
| 6 | `nix/hosts/manifold/default.nix` + stub `hardware-configuration.nix` | Host assembly (stub replaced during install) |
| 7 | `nix/modules/home/default.nix`, `xdg.nix`, `environment.nix` | Home-manager foundation |
| 8 | `nix/modules/home/shell.nix`, `prompt.nix` | Zsh full rewrite (largest module) |
| 9 | `nix/modules/home/git.nix`, `gpg.nix`, `ssh.nix` | Core dev tools |
| 10 | `nix/modules/home/cli-tools.nix`, `dev-tools.nix` | CLI packages and dev environment |
| 11 | `nix/modules/home/terminals.nix`, `editor.nix`, `tmux.nix` | Terminal + editor + multiplexer |
| 12 | `nix/modules/home/fonts.nix`, `scripts.nix`, `claude.nix`, `secrets.nix` | Remaining home modules |
| 13 | `nix/modules/home/desktop/niri.nix` | Niri WM config (keybindings, window rules) |
| 14 | `nix/modules/home/desktop/waybar.nix`, `fuzzel.nix`, `mako.nix` | Status bar, launcher, notifications |
| 15 | `nix/modules/home/desktop/swaylock.nix`, `gtk-qt.nix`, `desktop-apps.nix` | Lock screen, theming, app config |
| 16 | `nix/overlays/default.nix` | Google Sans Mono font overlay |
| 17 | Justfile additions | NixOS rebuild recipes |
| 18 | `git commit` + `git push origin nix` | Push branch for testing |
| 19 | Boot NixOS USB, partition, `nixos-install --flake` | Phase 6 commands |
| 20 | Fix errors on NixOS, push fixes, iterate | Phase 7 checklist |
| 10 | `nix/modules/nixos/filesystems.nix` | Evaluates |
| 11 | `nix/hosts/manifold/default.nix` | `nix build` (needs hardware-config stub) |
| 12 | `nix/modules/home/default.nix`, `xdg.nix`, `environment.nix` | `nix build` |
| 13 | `nix/modules/home/shell.nix`, `prompt.nix` | `nix build` |
| 14 | `nix/modules/home/git.nix`, `gpg.nix`, `ssh.nix` | `nix build` |
| 15 | `nix/modules/home/cli-tools.nix`, `dev-tools.nix` | `nix build` |
| 16 | `nix/modules/home/terminals.nix`, `editor.nix`, `tmux.nix` | `nix build` |
| 17 | `nix/modules/home/fonts.nix`, `scripts.nix`, `claude.nix`, `secrets.nix` | `nix build` |
| 18 | `nix/modules/home/desktop/niri.nix` | `nix build` (niri validates KDL) |
| 19 | `nix/modules/home/desktop/waybar.nix`, `fuzzel.nix`, `mako.nix` | `nix build` |
| 20 | `nix/modules/home/desktop/swaylock.nix`, `swayidle.nix`, `gtk-qt.nix`, `desktop-apps.nix` | `nix build` |
| 21 | `nix/overlays/default.nix` | `nix build` |
| 22 | Justfile additions | Manual test |
| 23 | Validate full build on Ubuntu | `nix build .#nixosConfigurations.manifold.config.system.build.toplevel` |
| 24 | Install NixOS | Boot USB, partition, install |
| 25 | Post-install verification | Checklist above |

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| RTX 5090 driver (580.x) incompatible with latest kernel | Pin `boot.kernelPackages`; use `nvidiaPackages.beta`; import `nixos-hardware` Blackwell module |
| **PyTorch in nixpkgs does NOT support sm_120 (Blackwell)** | **Use `uv add torch`** in per-project envs (PyPI wheels bundle CUDA 12.8 with sm_120 support). Track [nixpkgs #406675](https://github.com/NixOS/nixpkgs/issues/406675) |
| CUDA packages take hours to build | Binary caches: `cache.nixos-cuda.org`, `cache.flox.dev` -- configure BEFORE first build. Do NOT set global `cudaSupport = true` |
| niri-flake breaks on unstable nixpkgs | Pin in `flake.lock`; test with `nixos-rebuild test` before `switch` |
| Niri VRAM leak on NVIDIA | `GLVidHeapReuseRatio = 0` in nvidia application profiles (already in nvidia.nix) |
| Google Sans Mono not in nixpkgs | Custom font derivation in overlays or use `hf-nix` overlay |
| Claude Code not in nixpkgs | Install imperatively via npm; reference `~/.local/bin/claude` in systemd services |
| Full zsh rewrite misses subtle behavior | Test each feature against originals; keep original files for reference on non-NixOS platforms |
| Waybar double-launch | `systemd.enable = false` on waybar; let niri `spawn-at-startup` manage it |
| Wayland breaks some X11-only apps | xwayland-satellite (auto-integrated by niri) handles X11 compatibility |
| `hardware.nvidia.open` instability | Required for Blackwell (no choice). Test thoroughly; fallback: `nvidiaPackages.production` if `beta` causes issues |
| `LD_LIBRARY_PATH` fragility for ML | Use `/run/opengl-driver` (NixOS-specific driver path). This is well-tested by pierrot-lc, romaingrx, and others |

---

## Files NOT Modified (Stay As-Is for Non-NixOS Platforms)

All existing files in the dotfiles repo remain. They continue to work on macOS, RPi, HPC, and Termux. The NixOS config is additive -- `flake.nix` and `nix/` are new additions, not replacements.

The `install/install.sh` NixOS detection (line 342) should be updated to either run `nixos-rebuild switch --flake ~/.dotfiles#manifold` or print guidance pointing to the flake.
