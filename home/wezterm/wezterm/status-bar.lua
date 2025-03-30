local wez = require("wezterm")
local nf = wez.nerdfonts

local module = {}

local function basename(s)
	return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

local function batteryStatus()
	local battery = { text = "", color = "white" }
	if next(wez.battery_info()) ~= nil then
		local b = wez.battery_info()[1]
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
	return battery
end

function module.apply_to_config(config)
	local stat_bg_color = wez.color.parse(config.colors.background):darken(0.3)
	-- configure status line (left and right sides of tab-bar)
	-- Wezterm has a built-in nerd fonts
	-- https://wezfurlong.org/wezterm/config/lua/wezterm/nerdfonts.html
	wez.on("update-status", function(window, pane)
		-- Workspace name
		local stat = window:active_workspace()
		local stat_fg_color = "#f7768e"
		-- It's a little silly to have workspace name all the time
		-- Utilize this to display LDR or current key table name
		if window:active_key_table() then
			stat = window:active_key_table()
			stat_fg_color = "#7dcfff"
		end
		if window:leader_is_active() then
			stat = "LEADER"
			stat_fg_color = "#bb9af7"
		end

		window:set_left_status(wez.format({
			{ Background = { Color = stat_bg_color } },
			{ Foreground = { Color = stat_fg_color } },
			{ Text = "  " },
			{ Text = nf.oct_table .. "  " .. stat },
			{ Text = " |" },
		}))

		-- Current working directory
		local cwd = pane:get_current_working_dir()
		if cwd ~= nil then
			cwd = basename(cwd.file_path)
		end

		-- Current command (only for 'local' domain)
		local cmd = pane:get_foreground_process_name()
		-- CWD and CMD could be nil (e.g. viewing log using Ctrl-Alt-l)
		cmd = cmd and { Text = nf.md_application_brackets .. " " .. basename(cmd) } or {}

		-- Battery
		local battery = batteryStatus()

		-- Time
		local time = wez.strftime("%H:%M")

		window:set_right_status(wez.format({
			{ Background = { Color = stat_bg_color } },
			cwd and { Text = nf.md_folder .. " " .. cwd },
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
end

return module
