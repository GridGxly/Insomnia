#!/bin/bash
# PR 98: the message when another process puts SleepDisabled back to 0.
# t98.sh REV LABEL
source "$HOME/lab/lib.sh"
rev=$1 label=$2
note "== PR 98, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app
# Another process resetting the bit, as a keep-awake LaunchDaemon did.
sudo -n /bin/sh -c 'while :; do /usr/bin/pmset -a disablesleep 0; sleep 0.5; done' &
loop=$!
note "started a root loop running pmset -a disablesleep 0 every 0.5 s"
mark=$(log_mark)
start_session
for i in 1 2 3 4 5 6 7 8 9 10; do
  sleep 1
  shot "98-$label-$i"
done
sudo -n pkill -TERM -f 'disablesleep 0; sleep 0.5' 2>/dev/null
wait "$loop" 2>/dev/null
note "stopped the loop; log since the click:"
log_since "$mark" | sed 's/^/    /'
state_note
quit_app
