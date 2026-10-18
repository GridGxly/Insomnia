#!/bin/bash
# PR 99: Insomnia --session start, extend, end, status. t99.sh REV LABEL
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
BIN="$HOME/Applications/Insomnia.app/Contents/MacOS/Insomnia"
note "== PR 99, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
quit_app
cli() {
  local out rc
  out=$("$BIN" --session "$@" 2>&1); rc=$?
  note "\$ Insomnia --session $*  ->  exit $rc: $out"
}
cli status
cli start 120
launch_app; bash ~/lab/clearnc.sh >/dev/null
cli status
cli start 120
note "SleepDisabled $(sleep_disabled); session.json $( [ -e "$SUP/session.json" ] && echo present || echo absent )"
sleep 3
shot_menubar "99-$label-started"
cli start 60
cli extend 300
cli status
sleep 2
shot_menubar "99-$label-extended"
mark=$(log_mark)
cli end
log_since "$mark" | sed 's/^/    /'
state_note
cli end
cli frobnicate
note "request or reply files left in the support folder: $(ls "$SUP" | grep -c 'session-command')"
quit_app
