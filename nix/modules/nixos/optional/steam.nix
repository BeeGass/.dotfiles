# Steam and gaming stack
#
# Enables Steam with Proton (Windows game compatibility), Gamescope
# (micro-compositor for games), GameMode (performance optimizations),
# and MangoHud (in-game overlay for FPS/GPU stats).
{ config, lib, pkgs, ... }:

{
  programs.steam = {
    # Install Steam and configure the necessary system integration
    # (32-bit libraries, pressure-vessel sandbox, etc.)
    enable = true;

    # Open firewall ports for Steam Remote Play (streaming games to
    # other devices on the network)
    remotePlay.openFirewall = true;

    # Open firewall ports for Steam dedicated game servers
    dedicatedServer.openFirewall = true;

    # Enable the Gamescope Wayland session -- allows launching Steam
    # in a dedicated Gamescope compositor session from the greeter.
    # Useful for a console-like big-picture experience.
    gamescopeSession.enable = true;

    # Extra Proton compatibility tools -- Proton-GE is a community fork
    # with additional game fixes and media codec support not in upstream Proton.
    extraCompatPackages = [
      pkgs.proton-ge-bin
    ];
  };

  # Gamescope -- Valve's micro-compositor for games. Provides resolution
  # scaling, frame limiting, VRR, and HDR support in a nested compositor.
  programs.gamescope = {
    enable = true;

    # Allow Gamescope to set CAP_SYS_NICE so it can request realtime
    # scheduling for smoother frame pacing.
    capSysNice = true;
  };

  # GameMode -- applies temporary system optimizations while a game is
  # running (CPU governor, I/O priority, GPU clock boost, etc.)
  programs.gamemode.enable = true;

  # Raise the default file descriptor limit. Some games and Wine/Proton
  # open a large number of files and hit the default 1024 limit.
  systemd.extraConfig = "DefaultLimitNOFILE=1048576";

  environment.systemPackages = with pkgs; [
    # MangoHud -- Vulkan/OpenGL overlay for monitoring FPS, frame times,
    # CPU/GPU utilization, temperatures, and VRAM usage in-game.
    mangohud

    # ProtonUp-Qt -- GUI tool for managing Proton-GE and other
    # compatibility tool installations for Steam and Lutris.
    protonup-qt
  ];
}
