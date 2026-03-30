# Terminal emulator configurations.
# Ghostty (primary), Kitty (backup), WezTerm (backup via symlink).
{ config, pkgs, lib, ... }:
{
  # Ghostty from nixpkgs on Linux; on macOS it's installed via Homebrew cask
  home.packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.ghostty ];

  # Ghostty config (generated from Nix)
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

    # Tabs
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

    # Unbind Alt+1-9 (pass through to tmux)
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

  # Kitty config (Wayland native - dropped linux_display_server x11)
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

  # WezTerm config (Lua - symlink existing file)
  xdg.configFile."wezterm/wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/wezterm/wezterm.lua";
}
