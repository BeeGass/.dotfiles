# Waybar status bar configuration for Niri.
{ pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    systemd.enable = false; # niri manages waybar via spawn-at-startup

    settings = [{
      layer = "top";
      position = "top";
      height = 34;
      spacing = 4;

      modules-left = [ "niri/workspaces" "niri/window" ];
      modules-center = [ "clock" ];
      modules-right = [ "tray" "network" "cpu" "memory" "custom/gpu" "pulseaudio" "custom/lock" ];

      "niri/workspaces" = {
        format = "{icon}";
        format-icons = {
          "1-term"  = "";
          "2-web"   = "";
          "3-code"  = "";
          "4-notes" = "";
          "5-chat"  = "";
          "6-media" = "";
          "7-misc"  = "";
          "8-misc2" = "";
          "9-steam" = "󰓓";
          focused   = "";
          default   = "";
        };
      };

      "niri/window" = {
        format = "{}";
        max-length = 60;
      };

      clock = {
        format = "  {:%l:%M %p}";
        format-alt = "  {:%A, %B %d, %Y}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      cpu = {
        format = "  {usage}%";
        interval = 2;
      };

      memory = {
        format = "  {percentage}%";
        tooltip-format = "{used:0.1f}GiB / {total:0.1f}GiB";
        interval = 5;
      };

      "custom/gpu" = {
        exec = "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo N/A";
        format = "󰢮  {}%";
        interval = 5;
      };

      network = {
        format-ethernet = "󰈁  {ipaddr}";
        format-wifi = "  {signalStrength}%";
        format-disconnected = "󰤭  off";
      };

      pulseaudio = {
        format = "{icon}  {volume}%";
        format-muted = "  muted";
        format-icons = { default = [ "" "" "" ]; };
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };

      tray = {
        icon-size = 16;
        spacing = 8;
      };

      "custom/lock" = {
        format = "";
        on-click = "swaylock -f";
        tooltip-format = "Lock screen";
      };
    }];

    style = ''
      * {
        font-family: "Google Sans Mono", "JetBrains Mono Nerd Font", monospace;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(26, 26, 26, 0.90);
        color: #a8a8a8;
        border-bottom: 2px solid #333333;
      }

      #workspaces button {
        padding: 0 8px;
        color: #686868;
        background: transparent;
        border: none;
        border-radius: 4px;
        margin: 2px 1px;
      }

      #workspaces button.focused {
        color: #1a1a1a;
        background-color: #f7ca88;
        font-weight: bold;
      }

      #workspaces button.active {
        color: #f7ca88;
        background-color: #2a2a2a;
      }

      #workspaces button:hover {
        background-color: #333333;
        color: #ffffff;
      }

      #window {
        color: #a8a8a8;
        padding: 0 12px;
      }

      #clock {
        color: #ffffff;
        font-weight: bold;
      }

      #cpu, #memory, #custom-gpu, #network, #pulseaudio, #tray, #custom-lock {
        padding: 0 10px;
        color: #a8a8a8;
        background-color: #2a2a2a;
        border-radius: 4px;
        margin: 3px 2px;
      }

      #cpu { color: #7fc8ff; }
      #memory { color: #9d7cd8; }
      #custom-gpu { color: #76b568; }
      #network { color: #7fc8ff; }
      #pulseaudio { color: #f7ca88; }
      #pulseaudio.muted { color: #686868; }

      #custom-lock {
        color: #f7ca88;
        padding: 0 12px;
      }
      #custom-lock:hover {
        background-color: #f7ca88;
        color: #1a1a1a;
      }

      tooltip {
        background-color: #1a1a1a;
        border: 1px solid #333333;
        border-radius: 4px;
        color: #ffffff;
      }
    '';
  };
}
