# Niri scrollable tiling window manager configuration.
# Keybindings designed for Colemak-DH (r/s/f/t = left/down/up/right).
# Alt is completely reserved for tmux.
{ config, pkgs, lib, ... }:
{
  programs.niri.settings = {

    # Global settings
    prefer-no-csd = true;
    hotkey-overlay.skip-at-startup = true;
    screenshot-path = "~/Pictures/Screenshots/screenshot-%Y-%m-%d-%H%M%S.png";

    # Cursor
    cursor = {
      size = 24;
      theme = "Adwaita";
      hide-after-inactive-ms = 1000;
      hide-when-typing = true;
    };

    # Input
    input = {
      keyboard = {
        repeat-delay = 300;
        repeat-rate = 50;
        xkb = {
          layout = "us";
          options = "ctrl:nocaps";
        };
      };
      mouse = {
        accel-profile = "flat";
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
        dwt = true;
      };
      focus-follows-mouse.enable = false;
      warp-mouse-to-focus.enable = false;
      power-key-handling.enable = true;
    };

    # Layout
    layout = {
      gaps = 8;
      center-focused-column = "never";

      focus-ring = {
        enable = true;
        width = 3;
        active.color = "#f7ca88";
        inactive.color = "#33333380";
      };

      border.enable = false;

      shadow = {
        enable = true;
        color = "#00000070";
        offset = { x = 0; y = 4; };
        softness = 20;
      };

      preset-column-widths = [
        { proportion = 1.0 / 3.0; }
        { proportion = 1.0 / 2.0; }
        { proportion = 2.0 / 3.0; }
      ];

      default-column-width = { proportion = 1.0 / 2.0; };
    };

    # Environment
    environment = {
      DISPLAY = ":0";
      NIXOS_OZONE_WL = "1";
    };

    # Named workspaces
    workspaces = {
      "1-term"  = {};
      "2-web"   = {};
      "3-code"  = {};
      "4-notes" = {};
      "5-chat"  = {};
      "6-media" = {};
      "7-misc"  = {};
      "8-misc2" = {};
      "9-steam" = {};
    };

    # Spawn at startup
    spawn-at-startup = [
      { command = [ "waybar" ]; }
      { command = [ "mako" ]; }
      { command = [ "swayidle" "-w"
          "timeout" "300" "swaylock -f"
          "timeout" "600" "niri msg action power-off-monitors"
          "before-sleep" "swaylock -f"
        ]; }
      { command = [ "swaybg" "--mode" "fill" "--color" "#000000" ]; }
      { command = [ "nm-applet" "--indicator" ]; }
      { command = [ "wl-paste" "--type" "text" "--watch" "cliphist" "store" ]; }
      { command = [ "wl-paste" "--type" "image" "--watch" "cliphist" "store" ]; }
    ];

    # Keybindings
    binds = {
      # App launchers
      "Mod+Return".action.spawn = "ghostty";
      "Mod+D".action.spawn = "fuzzel";
      "Mod+Q".action.close-window = {};
      "Mod+Shift+E".action.quit = { skip-confirmation = false; };

      # Focus (Colemak-DH: r=left, s=down, f=up, t=right)
      "Mod+R".action.focus-column-left = {};
      "Mod+S".action.focus-window-or-workspace-down = {};
      "Mod+F".action.focus-window-or-workspace-up = {};
      "Mod+T".action.focus-column-right = {};

      # Focus (arrow fallbacks)
      "Mod+Left".action.focus-column-left = {};
      "Mod+Down".action.focus-window-or-workspace-down = {};
      "Mod+Up".action.focus-window-or-workspace-up = {};
      "Mod+Right".action.focus-column-right = {};

      # Move windows (Colemak-DH)
      "Mod+Shift+R".action.move-column-left = {};
      "Mod+Shift+S".action.move-window-down = {};
      "Mod+Shift+F".action.move-window-up = {};
      "Mod+Shift+T".action.move-column-right = {};

      # Move windows (arrow fallbacks)
      "Mod+Shift+Left".action.move-column-left = {};
      "Mod+Shift+Down".action.move-window-down = {};
      "Mod+Shift+Up".action.move-window-up = {};
      "Mod+Shift+Right".action.move-column-right = {};

      # Workspace navigation
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;

      # Move to workspace
      "Mod+Shift+1".action.move-window-to-workspace = 1;
      "Mod+Shift+2".action.move-window-to-workspace = 2;
      "Mod+Shift+3".action.move-window-to-workspace = 3;
      "Mod+Shift+4".action.move-window-to-workspace = 4;
      "Mod+Shift+5".action.move-window-to-workspace = 5;
      "Mod+Shift+6".action.move-window-to-workspace = 6;
      "Mod+Shift+7".action.move-window-to-workspace = 7;
      "Mod+Shift+8".action.move-window-to-workspace = 8;
      "Mod+Shift+9".action.move-window-to-workspace = 9;

      # Sequential workspace switching
      "Mod+Page_Down".action.focus-workspace-down = {};
      "Mod+Page_Up".action.focus-workspace-up = {};

      # Monitor focus (Colemak-DH)
      "Mod+Ctrl+R".action.focus-monitor-left = {};
      "Mod+Ctrl+T".action.focus-monitor-right = {};
      "Mod+Ctrl+F".action.focus-monitor-up = {};
      "Mod+Ctrl+S".action.focus-monitor-down = {};

      # Column/window layout
      "Mod+W".action.switch-preset-column-width = {};
      "Mod+Shift+W".action.switch-preset-window-height = {};
      "Mod+M".action.maximize-column = {};
      "Mod+Shift+M".action.fullscreen-window = {};
      "Mod+C".action.center-column = {};

      # Column stacking
      "Mod+Comma".action.consume-window-into-column = {};
      "Mod+Period".action.expel-window-from-column = {};
      "Mod+Tab".action.toggle-column-tabbed-display = {};

      # Floating
      "Mod+V".action.toggle-window-floating = {};

      # Overview
      "Mod+O" = { action.toggle-overview = {}; repeat = false; };

      # Resize
      "Mod+Minus".action.set-column-width = "-10%";
      "Mod+Equal".action.set-column-width = "+10%";
      "Mod+Shift+Minus".action.set-window-height = "-10%";
      "Mod+Shift+Equal".action.set-window-height = "+10%";

      # Screenshots
      "Print".action.screenshot = {};
      "Mod+Print".action.screenshot-screen = {};
      "Mod+Shift+Print".action.screenshot-window = {};

      # Lock / power
      "Mod+L".action.spawn = [ "swaylock" "-f" ];
      "Mod+Shift+P".action.power-off-monitors = {};

      # Clipboard history
      "Mod+Shift+V".action.spawn = [ "sh" "-c" "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy" ];

      # Scroll wheel workspace switching
      "Mod+WheelScrollDown" = { action.focus-workspace-down = {}; cooldown-ms = 150; };
      "Mod+WheelScrollUp" = { action.focus-workspace-up = {}; cooldown-ms = 150; };

      # Media keys
      "XF86AudioRaiseVolume" = { action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+" ]; allow-when-locked = true; };
      "XF86AudioLowerVolume" = { action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-" ]; allow-when-locked = true; };
      "XF86AudioMute" = { action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle" ]; allow-when-locked = true; };
      "XF86AudioMicMute" = { action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle" ]; allow-when-locked = true; };
      "XF86AudioPlay".action.spawn = [ "playerctl" "play-pause" ];
      "XF86AudioNext".action.spawn = [ "playerctl" "next" ];
      "XF86AudioPrev".action.spawn = [ "playerctl" "previous" ];
      "XF86MonBrightnessUp".action.spawn = [ "brightnessctl" "set" "5%+" ];
      "XF86MonBrightnessDown".action.spawn = [ "brightnessctl" "set" "5%-" ];
    };

    # Window rules
    window-rules = [
      # All windows: corner radius
      {
        matches = [{}];
        geometry-corner-radius = let r = 8.0; in {
          top-left = r; top-right = r; bottom-left = r; bottom-right = r;
        };
        clip-to-geometry = true;
      }

      # Floating dialogs
      {
        matches = [
          { title = "^Open File"; }
          { title = "^Save File"; }
          { title = "^Open Folder"; }
          { title = "^About "; }
          { title = "^Preferences$"; }
          { title = "^Settings$"; }
        ];
        open-floating = true;
      }

      # PiP windows
      {
        matches = [
          { app-id = "firefox"; title = "^Picture-in-Picture$"; }
          { app-id = "google-chrome"; title = "^Picture in picture$"; }
        ];
        open-floating = true;
      }

      # Steam popups
      {
        matches = [{ app-id = "^steam$"; title = "^(?!Steam$)"; }];
        open-floating = true;
      }

      # App workspace assignments
      {
        matches = [{ app-id = "^discord$|^com\\.discordapp\\.Discord$"; }];
        open-on-workspace = "5-chat";
      }
      {
        matches = [{ app-id = "^org\\.telegram\\.desktop$"; }];
        open-on-workspace = "5-chat";
      }
      {
        matches = [{ app-id = "^com\\.slack\\.Slack$|^Slack$"; }];
        open-on-workspace = "5-chat";
      }
      {
        matches = [{ app-id = "^md\\.obsidian\\.Obsidian$|^obsidian$"; }];
        open-on-workspace = "4-notes";
      }
      {
        matches = [{ app-id = "^com\\.spotify\\.Client$|^spotify$"; }];
        open-on-workspace = "6-media";
      }
      {
        matches = [{ app-id = "^steam$"; title = "^Steam$"; }];
        open-on-workspace = "9-steam";
      }

      # Block pinentry from screencast
      {
        matches = [{ app-id = "^pinentry-"; }];
        block-out-from = "screencast";
      }
    ];
  };
}
