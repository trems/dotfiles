#!/usr/bin/env bash

FILEPATH=$1
LINE=$2

if [[ -n $LINE ]]; then
  LINE=":${LINE}"
fi

TAB_ID=$(wezterm cli list --format json | jq ".[] | select(.pane_id == ${WEZTERM_PANE}) | .tab_id")
HX_PANE=$(wezterm cli list --format json | jq "[.[] | select(.tab_id == ${TAB_ID} and (.title | startswith(\"hx\")))][0] | .pane_id // empty")

if [[ -n "$HX_PANE" ]]; then
	wezterm cli send-text --pane-id "$HX_PANE" --no-paste ":open ${FILEPATH}${LINE}"$'\r'
  wezterm cli zoom-pane --unzoom
  wezterm cli activate-pane --pane-id "$HX_PANE"
  echo "$WEZTERM_PANE" # pipe it to kill broot pane
else
  hx "$FILEPATH""$LINE"
fi

