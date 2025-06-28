-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action

-- This table will hold the configuration.
local config = {}

-- In case you've previously defined objects, we'll start from a clean slate.
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- =======================================================
-- ||                    APPEARANCE                      ||
-- =======================================================

-- Color scheme (try: 'Catppuccin Mocha', 'Tokyo Night', 'Dracula', 'Nord')
config.color_scheme = 'Catppuccin Mocha'

-- Window settings with transparency
config.window_background_opacity = 0.90
config.text_background_opacity = 0.95
config.window_decorations = "RESIZE"
config.window_padding = {
  left = 10,
  right = 10,
  top = 10,
  bottom = 10,
}

-- Font configuration - keeping Google Sans Mono
config.font = wezterm.font_with_fallback({
  'Google Sans Mono',
  'Symbols Nerd Font Mono',
})
config.font_size = 12.0
config.line_height = 1.2

-- Cursor settings
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 500

-- =======================================================
-- ||                    TAB BAR                        ||
-- =======================================================

config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_max_width = 32

-- Tab bar colors
config.colors = {
  tab_bar = {
    background = '#1e1e2e',
    active_tab = {
      bg_color = '#313244',
      fg_color = '#cdd6f4',
    },
    inactive_tab = {
      bg_color = '#181825',
      fg_color = '#6c7086',
    },
    inactive_tab_hover = {
      bg_color = '#1e1e2e',
      fg_color = '#9399b2',
    },
  },
}

-- =======================================================
-- ||                  KEY BINDINGS                     ||
-- =======================================================

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.keys = {
  -- Split panes
  { key = '|', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  
  -- Navigate panes
  { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  
  -- Resize panes
  { key = 'H', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'J', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },
  { key = 'K', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'L', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },
  
  -- Tab management
  { key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
  { key = 'w', mods = 'LEADER', action = act.ShowTabNavigator },
  
  -- Tab shortcuts
  { key = '1', mods = 'LEADER', action = act.ActivateTab(0) },
  { key = '2', mods = 'LEADER', action = act.ActivateTab(1) },
  { key = '3', mods = 'LEADER', action = act.ActivateTab(2) },
  { key = '4', mods = 'LEADER', action = act.ActivateTab(3) },
  { key = '5', mods = 'LEADER', action = act.ActivateTab(4) },
  
  -- Copy mode
  { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },
  
  -- Other useful bindings
  { key = 'r', mods = 'LEADER', action = act.ReloadConfiguration },
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'f', mods = 'LEADER', action = act.Search { CaseInSensitiveString = '' } },
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
}

-- =======================================================
-- ||                  PERFORMANCE                      ||
-- =======================================================

-- Enable GPU acceleration
config.enable_wayland = false
config.front_end = "OpenGL"
config.max_fps = 120

-- Scrollback
config.scrollback_lines = 10000

-- =======================================================
-- ||                MISCELLANEOUS                      ||
-- =======================================================

-- Enable hyperlinks
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Mouse bindings
config.mouse_bindings = {
  -- Right click pastes from clipboard
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.PasteFrom 'Clipboard',
  },
}

-- And finally, return the configuration to wezterm
return config
