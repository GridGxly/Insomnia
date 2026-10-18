#!/bin/bash
# PR 84: the eye without the countdown, and the menu's time left and End
# Session. t84.sh REV LABEL
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
note "== PR 84, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
if [ "$label" = head ]; then
  open_settings
  note "toggle before: $(ax_dump | grep 'AXCheckBox|Show the countdown' | awk -F'|' '{print $NF}')"
  note "press: $(ax_press AXCheckBox 'Show the countdown in the menu bar')"
  sleep 1
  note "toggle after: $(ax_dump | grep 'AXCheckBox|Show the countdown' | awk -F'|' '{print $NF}'); config.json showMenuBarCountdown: $(config_get showMenuBarCountdown)"
  ax_reveal AXCheckBox 'Show the countdown in the menu bar' >/dev/null
  shot_window "84-$label-settings"
  close_window
fi
shot_menubar "84-$label-idle"
start_session
if wait_sleep_disabled; then note "session started from the menu bar; SleepDisabled 1"; else note "session did not start"; exit 1; fi
sleep 4
shot_menubar "84-$label-running"
note "status item width while running: $(ax 'get size of menu bar item 1 of menu bar 2')"
open_menu
note "right-click menu items: $(menu_names)"
shot_menubar "84-$label-menu" 260
if menu_names | grep -q 'End Session'; then
  mark=$(log_mark)
  menu_click "End Session"
  sleep 6
  note "after End Session:"
  log_since "$mark" | sed 's/^/    /'
  state_note
else
  key 53
fi
quit_app
state_note
if [ "$label" = head ]; then
  # Codex's finding: a wrongly typed value for the new key.
  /usr/bin/python3 - "$SUP/config.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["showMenuBarCountdown"] = "false"
c["endFloor"] = 23
c["freezeList"] = list(c.get("freezeList", [])) + ["com.example.marker"]
json.dump(c, open(p, "w"), indent=2)
PY
  note "config.json set by hand: showMenuBarCountdown \"false\" (a string), endFloor 23, com.example.marker on freezeList"
  mark=$(log_mark)
  launch_app
  sleep 3
  note "after launch: showMenuBarCountdown $(config_get showMenuBarCountdown), endFloor $(config_get endFloor), marker on freezeList: $(grep -c com.example.marker "$SUP/config.json")"
  log_since "$mark" | grep -iE 'config' | sed 's/^/    /'
  quit_app
fi
