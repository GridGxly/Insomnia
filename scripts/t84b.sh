#!/bin/bash
# PR 84 follow-up: the new toggle in Settings (scrolled to the App
# section), and whether main also resets config.json for a wrongly typed
# value of a key it already has. t84b.sh HEAD MAIN
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
head=$1 main=$2
note "== PR 84 follow-up, head ($head) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$head" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings
note "scroll: $(scroll_settings 1)"
sleep 1
note "toggle: $(ax_dump | grep 'AXCheckBox|Show the countdown' | awk -F'|' '{print $NF}')"
shot_window "84-head-settings-app"
close_window
quit_app
note "== PR 84 follow-up, main ($main): a wrongly typed value for an existing key"
install_rev "$main" || exit 1
quit_app
/usr/bin/python3 - "$SUP/config.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["endFloor"] = "23"
c["lowPowerFloor"] = 31
c["freezeList"] = list(c.get("freezeList", [])) + ["com.example.marker"]
json.dump(c, open(p, "w"), indent=2)
PY
note "config.json set by hand: endFloor \"23\" (a string), lowPowerFloor 31, com.example.marker on freezeList"
mark=$(log_mark)
launch_app
sleep 3
note "after launch: endFloor $(config_get endFloor), lowPowerFloor $(config_get lowPowerFloor), marker on freezeList: $(grep -c com.example.marker "$SUP/config.json")"
log_since "$mark" | grep -iE 'config' | sed 's/^/    /'
quit_app
note "t84b done"
