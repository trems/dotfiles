local wezterm = require("wezterm")
local act = wezterm.action
local nf = wezterm.nerdfonts

local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

local function log(msg)
	wezterm.log_info(msg)
end

local function basename(s)
	return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

config = {
	-- Settings
	color_scheme = "One Dark (Gogh)",
	-- color_scheme = "JetBrains Darcula",
	font = wezterm.font("JetBrains Mono", { weight = "Regular" }),
	harfbuzz_features = { "calt=0" }, -- disable ligatures
	font_size = 13.0,
	default_cursor_style = "SteadyBar",
	prefer_to_spawn_tabs = true,
	default_prog = { "/usr/local/bin/fish", "--login" },
	unix_domains = { { name = "work" } },
	default_domain = "local",
	default_workspace = "home",
	set_environment_variables = {
		SHELL = "/usr/local/bin/fish",
	},
	term = "wezterm",
	enable_kitty_keyboard = false,
	window_background_opacity = 0.99,
	window_decorations = "RESIZE",
	window_padding = { left = 5, right = 5, top = 0, bottom = 0 },
	inactive_pane_hsb = { saturation = 0.3, brightness = 0.5 },
	foreground_text_hsb = { brightness = 1.7, saturation = 0.99 },

	-- Keys
	leader = { key = "a", mods = "SUPER", timeout_milliseconds = 5000 },
	keys = {
		-- send Cmd-A if pressed twice
		{ key = "a", mods = "LEADER|SUPER", action = act.SendKey({ key = "a", mods = "SUPER" }) },
		{ key = "LeftArrow", mods = "SUPER", action = act.SendKey({ key = "Home" }) },
		{ key = "RightArrow", mods = "SUPER", action = act.SendKey({ key = "End" }) },
		{ key = "Backspace", mods = "SUPER", action = act.SendString("\x15") }, -- remove all to the left
		{ key = "z", mods = "SUPER", action = act.SendString("\x1f") }, -- undo
		{ key = "c", mods = "LEADER", action = act.ActivateCopyMode },

		{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		{ key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },

		{
			key = "p",
			mods = "LEADER",
			action = act.ActivateKeyTable({ name = "pane_control", one_shot = false }),
		},
		{
			key = "w",
			mods = "LEADER",
			action = act.ActivateKeyTable({ name = "window_control", one_shot = false }),
		},
		-- Tab keybindings
		{ key = "t", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
		{ key = "[", mods = "LEADER", action = act.ActivateTabRelative(-1) },
		{ key = "]", mods = "LEADER", action = act.ActivateTabRelative(1) },
		{ key = "n", mods = "LEADER", action = act.ShowTabNavigator },
		{
			key = "e",
			mods = "LEADER",
			action = act.PromptInputLine({
				description = wezterm.format({
					{ Attribute = { Intensity = "Bold" } },
					{ Foreground = { AnsiColor = "Fuchsia" } },
					{ Text = "Renaming Tab Title...:" },
				}),
				action = wezterm.action_callback(function(window, pane, line)
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},
		-- Key table for moving tabs around
		{ key = "m", mods = "LEADER", action = act.ActivateKeyTable({ name = "move_tab", one_shot = false }) },
		-- Or shortcuts to move tab w/o move_tab table. SHIFT is for when caps lock is on
		{ key = "{", mods = "LEADER|SHIFT", action = act.MoveTabRelative(-1) },
		{ key = "}", mods = "LEADER|SHIFT", action = act.MoveTabRelative(1) },

		{ key = "w", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
		-- Prompt for a name to use for a new workspace and switch to it.
		{
			key = "W",
			mods = "LEADER",
			action = act.PromptInputLine({
				description = wezterm.format({
					{ Attribute = { Intensity = "Bold" } },
					{ Foreground = { AnsiColor = "Fuchsia" } },
					{ Text = "Enter name for new workspace" },
				}),
				action = wezterm.action_callback(function(window, pane, line)
					-- line will be `nil` if they hit escape without entering anything
					-- An empty string if they just hit enter
					-- Or the actual line of text they wrote
					if line then
						window:perform_action(
							act.SwitchToWorkspace({
								name = line,
							}),
							pane
						)
					end
				end),
			}),
		},
		-- {
		--   key = 'f',
		--   mods = 'LEADER',
		--   action
		-- },
	},
}

-- I can use the tab navigator (LDR t), but I also want to quickly navigate tabs with index
for i = 1, 9 do
	table.insert(config.keys, {
		key = tostring(i),
		mods = "LEADER",
		action = act.ActivateTab(i - 1),
	})
end

config.key_tables = {
	pane_control = {
		-- Cancel the mode by pressing escape or enter
		{ key = "Escape", action = "PopKeyTable" },
		{ key = "Enter", action = "PopKeyTable" },
		{ key = "-", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		{ key = "\\", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "x", action = act.CloseCurrentPane({ confirm = true }) },
		{ key = "z", action = act.TogglePaneZoomState },
		{ key = "r", action = act.RotatePanes("Clockwise") },
		{ key = "R", action = act.RotatePanes("CounterClockwise") },
	},
	move_tab = {
		{ key = "Escape", action = "PopKeyTable" },
		{ key = "Enter", action = "PopKeyTable" },
	},
}

-- bind action with direction parameter to hjkl+arrows
local function bindDirectionAction(targetTable, action, mods)
	local directionKeys = { Left = "h", Down = "j", Up = "k", Right = "l" }

	for direction, key in pairs(directionKeys) do
		local keyBind = { key = key, action = action(direction), mods = mods }
		local arrowBind = { key = direction .. "Arrow", action = action(direction), mods = mods }
		table.insert(targetTable, keyBind)
		table.insert(targetTable, arrowBind)
	end
end

bindDirectionAction(config.key_tables.pane_control, function(d)
	return act.ActivatePaneDirection(d)
end)
bindDirectionAction(config.keys, function(d)
	return act.ActivatePaneDirection(d)
end, "LEADER")
bindDirectionAction(config.key_tables.pane_control, function(d)
	return act.AdjustPaneSize({ d, 1 })
end, "CTRL")
bindDirectionAction(config.key_tables.move_tab, function(d)
	local offset = 1 -- move right
	if d == "Left" or d == "Down" then
		offset = -1
	end -- or move left
	return act.MoveTabRelative(offset)
end)

wezterm.on("format-tab-title", function(tab)
	local pane = tab.active_pane
	local title = ""
	if tab.tab_title and #tab.tab_title > 0 then -- if tab title was explicitly set
		title = tab.tab_title
	else
		title = pane.title
	end
	title = tab.tab_index + 1 .. ". " .. title
	if pane.domain_name then
		title = title .. " (" .. pane.domain_name .. ")"
	end

	return title
end)

-- configure status line (left and right sides of tab-bar)
-- Wezterm has a built-in nerd fonts
-- https://wezfurlong.org/wezterm/config/lua/wezterm/nerdfonts.html
wezterm.on("update-status", function(window, pane)
	-- Workspace name
	local stat = window:active_workspace()
	local stat_color = "#f7768e"
	-- It's a little silly to have workspace name all the time
	-- Utilize this to display LDR or current key table name
	if window:active_key_table() then
		stat = window:active_key_table()
		stat_color = "#7dcfff"
	end
	if window:leader_is_active() then
		stat = "LEADER"
		stat_color = "#bb9af7"
	end

	window:set_left_status(wezterm.format({
		{ Foreground = { Color = stat_color } },
		{ Text = "  " },
		{ Text = nf.oct_table .. "  " .. stat },
		{ Text = " |" },
	}))

	-- Current working directory
	local cwd = basename(pane:get_current_working_dir().file_path)

	-- Current command (only for 'local' domain)
	local cmd = pane:get_foreground_process_name()
	-- CWD and CMD could be nil (e.g. viewing log using Ctrl-Alt-l)
	cmd = cmd and { Text = nf.md_application_brackets .. " " .. basename(cmd) } or {}

	-- Battery
	local battery = { text = "", color = "white" }
	if next(wezterm.battery_info()) ~= nil then
		local b = wezterm.battery_info()[1]
		if b.state == "Discharging" or b.state == "Empty" then
			if b.state_of_charge > 0.66 then
				battery.icon = nf.md_battery_high
			elseif b.state_of_charge > 0.33 then
				battery.icon = nf.md_battery_medium
			else
				battery.icon = nf.md_battery_low
			end
			if b.state_of_charge < 0.2 then
				battery.color = "#e66060"
			end
		elseif b.state == "Charging" or b.state == "Full" then
			if b.state_of_charge > 0.66 then
				battery.icon = nf.md_battery_charging_high
			elseif b.state_of_charge > 0.33 then
				battery.icon = nf.md_battery_charging_medium
			else
				battery.icon = nf.md_battery_charging_low
			end
		end

		battery.text = battery.text .. string.format("%.0f%%", b.state_of_charge * 100)
	end
	--
	-- Time
	local time = wezterm.strftime("%H:%M")

	window:set_right_status(wezterm.format({
		{ Text = nf.md_folder .. " " .. cwd },
		{ Text = " | " },
		cmd,
		{ Text = " | " },
		{ Foreground = { Color = battery.color } },
		{ Text = battery.icon .. " " .. battery.text },
		"ResetAttributes",
		{ Text = " | " },
		{ Text = nf.md_clock .. " " .. time },
		{ Text = "  " },
	}))
end)

return config
