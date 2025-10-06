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
	local bg_dark = bg:darken(0.3)

	config.window_frame = {
		active_titlebar_bg = bg_dark,
		inactive_titlebar_bg = bg_dark,
	}

	-- config.colors.tab_bar = {
	-- 	inactive_tab_edge = bg_dark,
	-- 	active_tab = {
	-- 		bg_color = bg,
	-- 		fg_color = "#c0c0c0",
	-- 	},
	-- 	inactive_tab = {
	-- 		bg_color = bg_dark,
	-- 		fg_color = "#808080",
	-- 	},
	-- }

	-- The filled in variant of the < symbol
	local SOLID_LEFT_ARROW = wez.nerdfonts.pl_right_hard_divider

	-- The filled in variant of the > symbol
	local SOLID_RIGHT_ARROW = wez.nerdfonts.pl_left_hard_divider

	-- config.tab_bar_at_bottom = true
	config.use_fancy_tab_bar = false
	wez.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
		local pane = tab.active_pane
		local title = ""
		if tab.tab_title and #tab.tab_title > 0 then -- if tab title was explicitly set
			title = tab.tab_title
		else
			title = pane.title
		end
		title = tab.tab_index + 1 .. ". " .. title
		if pane.domain_name and pane.domain_name ~= "local" then
			title = title .. " (" .. pane.domain_name .. ")"
		end

		local edge_background = "#0b0022"
		local background = "#1b1032"
		local foreground = "#808080"

		if tab.is_active then
			background = "#2b2042"
			foreground = "#c0c0c0"
		elseif hover then
			background = "#3b3052"
			foreground = "#909090"
		end

		title = wez.truncate_right(title, max_width - 2)
		local edge_foreground = background
		return {
			{ Background = { Color = edge_background } },
			{ Foreground = { Color = edge_foreground } },
			{ Text = SOLID_LEFT_ARROW },
			{ Background = { Color = background } },
			{ Foreground = { Color = foreground } },
			{ Text = title },
			{ Background = { Color = edge_background } },
			{ Foreground = { Color = edge_foreground } },
			{ Text = SOLID_RIGHT_ARROW },
			-- { Text = SOLID_LEFT_ARROW },
			-- { Text = title },
		}

		-- if tab.is_active then
		-- 	return {
		-- 		{ Background = { Color = edge_background } },
		-- 		{ Foreground = { Color = edge_foreground } },
		-- 		{ Text = SOLID_LEFT_ARROW },
		-- 		{ Background = { Color = background } },
		-- 		{ Foreground = { Color = foreground } },
		-- 		{ Text = title },
		-- 		{ Background = { Color = edge_background } },
		-- 		{ Foreground = { Color = edge_foreground } },
		-- 		{ Text = SOLID_RIGHT_ARROW },
		-- 		-- { Text = SOLID_LEFT_ARROW },
		-- 		-- { Text = title },
		-- 	}
		-- end
		-- return title
	end)
end

return module
