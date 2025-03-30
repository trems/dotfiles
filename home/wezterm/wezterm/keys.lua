local wez = require("wezterm")
local act = wez.action
local module = {}

-- bind action with direction parameter to HJKL+arrows
local function bindDirectionAction(targetTable, action, mods)
	local directionKeys = { Left = "h", Down = "j", Up = "k", Right = "l" }

	for direction, key in pairs(directionKeys) do
		local keyBind = { key = key, action = action(direction), mods = mods }
		local arrowBind = { key = direction .. "Arrow", action = action(direction), mods = mods }
		table.insert(targetTable, keyBind)
		table.insert(targetTable, arrowBind)
	end
end

local function extend_copy_mode(config)
	-- add vim-like binding for search
	local copy_mode = nil
	if wez.gui then
		copy_mode = wez.gui.default_key_tables().copy_mode
		table.insert(copy_mode, { key = "/", mods = "NONE", action = act.Search("CurrentSelectionOrEmptyString") })
	end
	config.key_tables.copy_mode = copy_mode
end

function module.apply_to_config(config)
	config.leader = { key = "a", mods = "SUPER", timeout_milliseconds = 5000 }
	config.key_tables = {
		pane_control = {
			-- Cancel the mode by pressing escape or enter
			{ key = "Escape", action = "PopKeyTable" },
			{ key = "Enter", action = "PopKeyTable" },
			{ key = "-", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
			{ key = "\\", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
			{ key = "q", action = act.CloseCurrentPane({ confirm = true }) },
			{ key = "z", action = act.TogglePaneZoomState },
			{ key = "r", action = act.RotatePanes("Clockwise") },
			{ key = "R", action = act.RotatePanes("CounterClockwise") },
		},
		move_tab = {
			{ key = "Escape", action = "PopKeyTable" },
			{ key = "Enter", action = "PopKeyTable" },
		},
		-- copy_mode = {
		-- 	{ key = "/", action = act.Search("CurrentSelectionOrEmptyString") },
		-- },
	}
	config.keys = {
		-- send Cmd-A if pressed twice
		{ key = "a", mods = "LEADER|SUPER", action = act.SendKey({ key = "a", mods = "SUPER" }) },
		{ key = "LeftArrow", mods = "SUPER", action = act.SendKey({ key = "Home" }) },
		{ key = "RightArrow", mods = "SUPER", action = act.SendKey({ key = "End" }) },
		{ key = "Backspace", mods = "SUPER", action = act.SendString("\x15") }, -- remove all to the left
		{ key = "z", mods = "SUPER", action = act.SendString("\x1f") }, -- undo
		{ key = "c", mods = "LEADER", action = act.ActivateCopyMode },
		{ key = "s", mods = "LEADER", action = act.QuickSelect },

		{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		{ key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
		{ key = "w", mods = "SUPER", action = act.CloseCurrentPane({ confirm = true }) },
		{
			key = "p",
			mods = "LEADER",
			action = act.ActivateKeyTable({ name = "pane_control", one_shot = false }),
		},

		-- Key table for moving tabs around
		{ key = "m", mods = "LEADER", action = act.ActivateKeyTable({ name = "move_tab", one_shot = false }) },
		-- Tab keybindings
		{ key = "t", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
		{ key = "[", mods = "LEADER", action = act.ActivateTabRelative(-1) },
		{ key = "]", mods = "LEADER", action = act.ActivateTabRelative(1) },
		{ key = "n", mods = "LEADER", action = act.ShowTabNavigator },
		{
			key = "r",
			mods = "LEADER",
			action = act.PromptInputLine({
				description = wez.format({
					{ Attribute = { Intensity = "Bold" } },
					{ Foreground = { AnsiColor = "Fuchsia" } },
					{ Text = "Renaming Tab Title...:" },
				}),
				action = wez.action_callback(function(window, pane, line)
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},

		{ key = "w", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
		-- Prompt for a name to use for a new workspace and switch to it.
		{
			key = "W",
			mods = "LEADER",
			action = act.PromptInputLine({
				description = wez.format({
					{ Attribute = { Intensity = "Bold" } },
					{ Foreground = { AnsiColor = "Fuchsia" } },
					{ Text = "Enter name for new workspace" },
				}),
				action = wez.action_callback(function(window, pane, line)
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
	}
	-- I can use the tab navigator (LDR t), but I also want to quickly navigate tabs with index
	for i = 1, 9 do
		table.insert(config.keys, {
			key = tostring(i),
			mods = "LEADER",
			action = act.ActivateTab(i - 1),
		})
	end
	-- Navigate panes in pane_control
	bindDirectionAction(config.key_tables.pane_control, function(d)
		return act.ActivatePaneDirection(d)
	end)
	-- Comment because moving between panes handled by smart-splits
	-- -- Activate pane in LDR mode
	-- bindDirectionAction(config.keys, function(d)
	-- 	return act.ActivatePaneDirection(d)
	-- end, "LEADER")
	-- -- Resize pane in pane_control mode
	bindDirectionAction(config.key_tables.pane_control, function(d)
		return act.AdjustPaneSize({ d, 1 })
	end, "CTRL")
	-- Move current tab in move_tab mode
	bindDirectionAction(config.key_tables.move_tab, function(d)
		local offset = 1 -- move right
		if d == "Left" or d == "Down" then
			offset = -1 -- or move left
		end
		return act.MoveTabRelative(offset)
	end)

	extend_copy_mode(config)
end

return module
