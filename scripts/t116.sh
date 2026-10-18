#!/bin/bash
# PR 116: which pill has focus when the pills open. t116.sh REV LABEL
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
note "== PR 116, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
type5() {
  local x
  x=$(eye_x)
  "$HOME/click" $((x + 16)) 15
  sleep 1.5
  shot_menubar "116-$label-$1-pills" 120
  osascript -e 'tell application "System Events" to keystroke "5"' >/dev/null
  sleep 0.6
  shot_menubar "116-$label-$1-typed" 120
  key 36
  if wait_sleep_disabled; then note "$1: typed 5 and Enter; session.json length $(/usr/bin/python3 -c '
import json, sys, datetime
s = json.load(open(sys.argv[1]))
t = lambda v: v if isinstance(v, (int, float)) else datetime.datetime.fromisoformat(v.replace("Z", "+00:00")).timestamp()
print("%d s" % round(t(s["endsAt"]) - t(s["startedAt"])))' "$SUP/session.json")"; else note "$1: session did not start"; fi
  quit_app
  launch_app
}
type5 default
if [ "$label" = head ]; then
  open_settings
  note "Default field before: $(ax_dump | grep 'AXPopUpButton|Default field' | awk -F'|' '{print $NF}')"
  ax_press AXPopUpButton 'Default field' >/dev/null
  sleep 0.8
  key 125; sleep 0.3; key 36; sleep 1
  note "Default field after: $(ax_dump | grep 'AXPopUpButton|Default field' | awk -F'|' '{print $NF}'); config.json defaultFocusField: $(config_get defaultFocusField)"
  ax_reveal AXPopUpButton 'Default field' >/dev/null
  shot_window "116-$label-settings"
  close_window
  type5 minutes
fi
state_note
