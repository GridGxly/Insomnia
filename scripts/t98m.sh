#!/bin/bash
# PR 98, visual: the status menu's error line after a start that another
# process undid. t98m.sh REV LABEL
source "$HOME/lab/lib.sh"
rev=$1 label=$2
note "== PR 98 (status menu), $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app
sudo -n /bin/sh -c 'while :; do /usr/bin/pmset -a disablesleep 0; sleep 0.5; done' &
note "started a root loop running pmset -a disablesleep 0 every 0.5 s"
mark=$(log_mark)
start_session
wait_log "$mark" 'session end \(startFailed\)' 20 && note "start failed, as set up"
sudo -n pkill -TERM -f 'disablesleep 0; sleep 0.5'
sleep 2
x=$(eye_x)
"$HOME/click" right $((x + 16)) 15
sleep 1.5
shot "98m-$label"
log_since "$mark" | grep -E 'could not disable sleep' | sed 's/^/    /'
key 53
sleep 0.5
quit_app
state_note
