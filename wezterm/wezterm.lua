-- Minimal WezTerm Configuration
local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Appearance
config.color_scheme = 'Builtin Dark'
config.colors = {
  background = '#000000',
  foreground = '#ffffff',
}

-- Window settings
config.window_background_opacity = 0.80
config.window_decorations = "RESIZE"
config.window_padding = {
  left = 10,
  right = 10,
  top = 10,
  bottom = 10,
}

-- Font
config.font = wezterm.font_with_fallback({
  'Google Sans Mono',
  'JetBrains Mono',
  'SF Mono',
  'Symbols Nerd Font Mono',
})
config.font_size = 10.0

local function has_nvidia()
  local f = io.popen("command -v nvidia-smi >/dev/null 2>&1 && echo yes || echo no")
  local out = f and f:read("*l") or "no"
  if f then f:close() end
  return out == "yes"
end

local BEEGASS_GPU_ENABLED = has_nvidia()
config.set_environment_variables = config.set_environment_variables or {}
if BEEGASS_GPU_ENABLED then
  config.set_environment_variables.BEEGASS_GPU_ENABLED = '1'
end

-- Cursor
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 500

-- Disable tab bar (using tmux instead)
config.enable_tab_bar = false

-- Performance
config.enable_wayland = false
config.front_end = "OpenGL"
config.max_fps = 120
config.scrollback_lines = 10000

-- Auto-start tmux
config.default_prog = { 'tmux', 'new-session', '-A', '-s', 'main' }

-- Mouse support
config.mouse_bindings = {
  -- Right click pastes
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}

-- Minimal key bindings
config.keys = {
  -- Toggle window decorations with F11
  {
    key = 'F11',
    mods = '',
    action = wezterm.action_callback(function(window, pane)
      local overrides = window:get_config_overrides() or {}
      if not overrides.window_decorations or overrides.window_decorations == "RESIZE" then
        overrides.window_decorations = "TITLE | RESIZE"
      else
        overrides.window_decorations = "RESIZE"
      end
      window:set_config_overrides(overrides)
    end)
  },
}

return config
