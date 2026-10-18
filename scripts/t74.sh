#!/bin/bash
# PR 74: End session in the status item's right-click menu. t74.sh REV LABEL
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
note "== PR 74, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
start_session
if wait_sleep_disabled; then note "session started from the menu bar; SleepDisabled 1"; else note "session did not start"; exit 1; fi
sleep 3
open_menu
note "right-click menu items: $(menu_names)"
shot_menubar "74-$label-menu" 240
if menu_names | grep -q 'End session'; then
  mark=$(log_mark)
  menu_click "End session"
  sleep 6
  note "after End session:"
  log_since "$mark" | sed 's/^/    /'
  state_note
  note "Insomnia still running: pid $(app_pid)"
else
  key 53
  note "no End session item in this build"
fi
quit_app
state_note
