# Matrix - macOS system configuration (nix-darwin)
# Apple Silicon MacBook
# Usage: darwin-rebuild switch --flake ~/.dotfiles#matrix
{ config, pkgs, vars, ... }:
{
  # System identity
  networking.hostName = "matrix";

  # Nix daemon configuration
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" vars.username ];
  };
  nixpkgs.config.allowUnfree = true;

  # Enable zsh (default macOS shell)
  programs.zsh.enable = true;

  # Homebrew integration (for GUI apps not in nixpkgs)
  # Actual brew installs managed by `brew bundle` separately
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      cleanup = "none";  # Don't uninstall brew packages not in this config
    };
    casks = [
      "ghostty"
      "kitty"
      "iterm2"
      "font-jetbrains-mono-nerd-font"
    ];
  };

  # macOS system defaults
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;        # Don't rearrange spaces based on use
      show-recents = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      FHIdeExtension = false;
      ShowPathbar = true;
      ShowStatusBar = true;
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;     # Fast key repeat
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };
    trackpad = {
      Clicking = true;           # Tap to click
      TrackpadRightClick = true;
    };
  };

  # Security
  security.pam.services.sudo_local.touchIdAuth = true;

  # System packages (darwin-level)
  environment.systemPackages = with pkgs; [
    gnupg
    pinentry_mac
  ];

  # Required for nix-darwin
  system.stateVersion = 6;
}
