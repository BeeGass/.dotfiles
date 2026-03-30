# Niri -- scrollable tiling Wayland compositor
#
# System-level integration: installs the compositor, sets up session
# environment variables for Wayland/NVIDIA compatibility, configures
# XDG portals, and pulls in common Wayland utilities.
#
# User-level niri configuration (keybinds, layouts, etc.) is handled
# separately in the home-manager module.
{ config, lib, pkgs, ... }:

{
  # Enable the niri compositor via the NixOS module (from nixpkgs or the
  # niri-flake overlay). This installs the binary and creates the
  # wayland-sessions desktop entry for display managers / greeters.
  programs.niri.enable = true;

  # Session-wide environment variables applied to all processes launched
  # within the Wayland session. These ensure correct rendering and
  # protocol selection for various toolkits on NVIDIA + Wayland.
  environment.sessionVariables = {
    # Tell Electron apps (VS Code, Discord, etc.) to use Wayland natively
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";

    # Force GBM (Generic Buffer Management) to use the NVIDIA DRM backend
    # instead of Mesa's default -- required for EGLStreams-free compositing.
    GBM_BACKEND = "nvidia-drm";

    # Ensure GLX calls use the NVIDIA vendor library, not Mesa
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Firefox: use Wayland backend natively
    MOZ_ENABLE_WAYLAND = "1";

    # Qt: prefer Wayland, fall back to XCB (XWayland)
    QT_QPA_PLATFORM = "wayland;xcb";

    # Qt: let the compositor handle window decorations (CSD)
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

    # SDL2: use Wayland video driver
    SDL_VIDEODRIVER = "wayland";

    # Inform applications that this is a Wayland session
    XDG_SESSION_TYPE = "wayland";
  };

  # XDG Desktop Portal configuration -- provides sandboxed access to
  # host resources (file chooser, screen sharing, notifications, etc.)
  xdg.portal = {
    enable = true;

    # Portal implementations:
    # - GNOME portal: screencast and screenshot support via PipeWire
    # - GTK portal: file chooser and other GTK-native dialogs
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];

    # Map niri portal interfaces to the appropriate implementations.
    # The GNOME portal handles screen capture; GTK handles everything else.
    config.niri = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  # Common Wayland utilities that are expected by most compositor setups
  environment.systemPackages = with pkgs; [
    # Clipboard: Wayland copy/paste and clipboard history
    wl-clipboard
    cliphist

    # Screenshots: area selection + capture
    grim
    slurp

    # Hardware control: backlight and media keys
    brightnessctl
    playerctl

    # Desktop integration
    libnotify              # send desktop notifications from scripts
    networkmanagerapplet   # systray network manager (nm-applet)
    xdg-utils              # xdg-open and friends

    # Authentication agent -- prompts for polkit elevation (e.g. systemctl)
    polkit_gnome
  ];
}
