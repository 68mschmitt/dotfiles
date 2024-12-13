-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = 'Batman'

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
    left = 30,
    right = 30,
    top = 30,
    bottom = 30,
}

config.window_background_opacity = 0.70

-- and finally, return the configuration to wezterm
return config
