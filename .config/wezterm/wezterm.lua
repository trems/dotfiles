local wez = require("wezterm")

local config = {}
if wez.config_builder then
	config = wez.config_builder()
end

config = {
	-- Settings
	default_prog = { "/usr/local/bin/fish", "--login" },
	unix_domains = { { name = "work" } },
	default_domain = "local",
	default_workspace = "home",
	set_environment_variables = {
		SHELL = "/usr/local/bin/fish",
	},
	term = "wezterm",
	enable_kitty_keyboard = false,
	front_end = "WebGpu",
	quick_select_patterns = {
		"v[0-9]+.+", -- golang version tag from 'git describe'
	},
	debug_key_events = true,
}

if next(wez.battery_info()) ~= nil then
	local b = wez.battery_info()[1]
	if b.state == "Discharging" or b.state == "Empty" then
		config.webgpu_power_preference = "LowPower"
		config.animation_fps = 1
	else
		config.webgpu_power_preference = "HighPerformance"
	end
end

require("keys").apply_to_config(config)
require("appearance").apply_to_config(config)
require("status-bar").apply_to_config(config)
require("smart-splits").apply_to_config(config)

return config
