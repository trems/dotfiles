local wez = require("wezterm")

local config = {}
if wez.config_builder then
	config = wez.config_builder()
end

config = {
	-- Settings
	default_prog = { "fish", "--login" },
	unix_domains = { { name = "work" } },
	default_domain = "local",
	default_workspace = "home",
	set_environment_variables = {},
	enable_kitty_keyboard = false,
	front_end = "WebGpu",
	webgpu_power_preference = "LowPower",
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

local currDir = (...):match("(.-)[^%.]+$")
require(currDir .. "keys").apply_to_config(config)
require(currDir .. "appearance").apply_to_config(config)
require(currDir .. "status-bar").apply_to_config(config)
require(currDir .. "smart-splits").apply_to_config(config)

return config
