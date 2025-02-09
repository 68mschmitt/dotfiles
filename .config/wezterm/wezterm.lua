-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- For example, changing the color scheme:
config.color_scheme = 'Catppuccin Mocha'

-- Hide the top bar
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true
config.window_decorations = "NONE"

config.colors = {
		cursor_bg = "#A6ACCD",
		cursor_border = "#A6ACCD",
		cursor_fg = "#1B1E28",
	}

config.window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
}

config.keys = {
    {
        key = 't',
        mods = 'SHIFT|ALT',
        action = act.SpawnTab 'CurrentPaneDomain',
    }
}

config.window_background_opacity = 0.70

-- and finally, return the configuration to wezterm
return config
