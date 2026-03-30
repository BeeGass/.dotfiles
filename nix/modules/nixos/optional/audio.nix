# PipeWire audio stack
#
# Replaces PulseAudio with PipeWire, providing unified handling of:
#   - ALSA (direct hardware access)
#   - PulseAudio (compatibility layer for PA-only apps)
#   - JACK (low-latency pro audio, if needed)
#
# WirePlumber is used as the session/policy manager.
{ config, lib, pkgs, ... }:

{
  # Disable PulseAudio -- it conflicts with PipeWire's pulse module.
  # This must be explicitly set to false when PipeWire's pulse
  # compatibility layer is enabled.
  hardware.pulseaudio.enable = false;

  services.pipewire = {
    # Enable the PipeWire daemon
    enable = true;

    # ALSA support -- lets ALSA-only applications route audio through PipeWire
    alsa.enable = true;

    # 32-bit ALSA support -- needed by Wine, Steam, and other 32-bit apps
    alsa.support32Bit = true;

    # PulseAudio compatibility -- runs a PipeWire-based PulseAudio server
    # so apps using libpulse (pavucontrol, Firefox, Discord, etc.) work
    # without modification.
    pulse.enable = true;

    # WirePlumber -- session and policy manager for PipeWire.
    # Handles device routing, default sinks/sources, and stream management.
    wireplumber.enable = true;
  };

  # RealtimeKit -- allows PipeWire (and WirePlumber) to request realtime
  # scheduling priority without running as root. Required for low-latency
  # audio without xruns.
  security.rtkit.enable = true;
}
