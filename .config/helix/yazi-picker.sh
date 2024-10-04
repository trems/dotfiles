#!/usr/bin/env sh

 paths=$(yazi --chooser-file=/dev/stdout | while read -r; do printf "%q " "$REPLY"; done)

if [[ -n "$paths" ]]; then
	wezterm cli send-text --no-paste --pane-id $1 ":open ${paths}"$'\r'
	wezterm cli kill-pane
	wezterm cli send-text --no-paste --pane-id $1 ":redraw"$'\r'
	# zellij action toggle-floating-panes
	# zellij action write 27 # send <Escape> key
	# zellij action write-chars ":open $paths"
	# zellij action write 13 # send <Enter> key
	# zellij action toggle-floating-panes
fi

# zellij action close-pane
