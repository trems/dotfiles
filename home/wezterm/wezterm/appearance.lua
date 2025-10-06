local wez = require("wezterm")
local module = {}

function module.apply_to_config(config)
	config.color_scheme = "Tokyo Night Moon"
	config.font = wez.font("JetBrains Mono", { weight = "Regular" })
	config.harfbuzz_features = { "calt=0" } -- disable ligature
	config.font_size = 13.0
	config.default_cursor_style = "SteadyBar"
	config.prefer_to_spawn_tabs = true
	config.window_background_opacity = 1.0
	config.window_decorations = "TITLE | RESIZE"
	config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
	config.inactive_pane_hsb = { saturation = 0.3, brightness = 0.5 }
	config.foreground_text_hsb = { brightness = 1.3, saturation = 1.00 }

	config.colors = wez.color.get_builtin_schemes()[config.color_scheme]
	local bg = wez.color.parse(config.colors.background)
	local fg = wez.color.parse(config.colors.foreground)
	local bg_dark = bg:darken(0.3)

	config.window_frame = {
		active_titlebar_bg = bg_dark,
		inactive_titlebar_bg = bg_dark,
	}

	config.use_fancy_tab_bar = false
	config.tab_max_width = 25

	config.tab_bar_style = {
		new_tab,
	}

	wez.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
		local pane = tab.active_pane
		local title = ""
		if tab.tab_title and #tab.tab_title > 0 then -- if tab title was explicitly set
			title = tab.tab_title
		else
			title = pane.title
		end
		local domain = ""
		if pane.domain_name and pane.domain_name ~= "local" then
			domain = "(" .. pane.domain_name .. ")"
		end
		title = tab.tab_index + 1 .. domain .. ":" .. title

		local edge_background = bg_dark
		local background = bg_dark
		local foreground = "grey"

		if tab.is_active then
			background = bg
			foreground = "#f1f1f1"
		elseif hover then
			background = bg:darken(0.1)
			foreground = "#cfcfcf"
		end

		title = wez.truncate_right(title, max_width - 2)
		local edge_foreground = background
		return {
			{ Background = { Color = edge_background } },
			{ Foreground = { Color = edge_foreground } },
			{ Text = wez.nerdfonts.pl_right_hard_divider },
			{ Background = { Color = background } },
			{ Foreground = { Color = foreground } },
			{ Text = title },
			{ Background = { Color = edge_background } },
			{ Foreground = { Color = edge_foreground } },
			{ Text = wez.nerdfonts.pl_left_hard_divider },
		}
	end)
end

return module
