#!/bin/bash
# PR 111: the countdown's look and the app's CPU during a session.
# t111.sh REV LABEL
source "$HOME/lab/lib.sh"
rev=$1 label=$2
note "== PR 111, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app
start_session
if wait_sleep_disabled; then note "session started from the menu bar; SleepDisabled 1"; else note "session did not start"; exit 1; fi
sleep 6
record "111-$label" 4
shot "111-$label"
sleep 2
note "CPU of Insomnia during the session: $(cpu_mean 60)"
quit_app
state_note
