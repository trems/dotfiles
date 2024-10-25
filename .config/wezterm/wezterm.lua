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
}

require("keys").apply_to_config(config)
require("appearance").apply_to_config(config)
require("status-bar").apply_to_config(config)
require("smart-splits").apply_to_config(config)

return config
