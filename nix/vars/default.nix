# Centralized identity and networking variables.
# Every module can access these via { vars, ... }: in its function signature.
# Pattern source: ryan4yin/nix-config
{
  # -- User Identity --
  username = "beegass";
  fullName = "Bryan Gass";
  email = "44324535+BeeGass@users.noreply.github.com";
  githubUser = "BeeGass";

  # -- GPG Key IDs (from YubiKey) --
  gpgKeys = {
    master         = "0xA34200D828A7BB26";
    signing        = "0xACC3640C138D96A2";
    encryption     = "0x21691AE75B0463CC";
    authentication = "0x27D667E55F655FD2";
  };

  # -- Networking --
  networking = {
    tailnet = "tailf7d439.ts.net";
    sshPort = 40822;
    hosts = {
      manifold = {
        ip = "192.168.68.10";
        system = "x86_64-linux";
        username = "beegass";
        description = "Primary ML workstation (Ryzen 9 9950X3D, 64GB). GPU: RTX Pro 6000 (Blackwell 96GB) planned; RTX 5090 current. NixOS + Niri.";
      };
      tensor = {
        ip = "192.168.68.11";
        system = "x86_64-linux";
        username = "beegass";
        description = "Interim workstation during migration (Ryzen 9 3900X, 32GB). GPU: RTX 5090 (Blackwell 32GB) planned via transplant from manifold; RTX 3080 current. NixOS + Niri.";
      };
      matrix = {
        # macOS - Apple Silicon MacBook
        system = "aarch64-darwin";
        username = "beegass";
        description = "MacBook (Apple Silicon)";
      };
      jacobian = {
        ip = "192.168.68.30";
        system = "aarch64-linux";
        username = "ubuntu";
        description = "Raspberry Pi 5 (secrets server, backup)";
      };
      hessian = {
        ip = "192.168.68.31";
        system = "aarch64-linux";
        username = "ubuntu";
        description = "Raspberry Pi 5 (monitoring)";
      };
    };
  };

  # Dotfiles repo relative to home directory.
  # The full path is computed per-host as "${config.home.homeDirectory}/.dotfiles"
  # in modules that need mkOutOfStoreSymlink references.
  dotfilesRelPath = ".dotfiles";
}
