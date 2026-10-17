#!/bin/bash
# PR 111, visual: screenshots of the status item about 125 times a second
# for 3 s during a session, plus one full screenshot.
# t111v.sh REV LABEL
source "$HOME/lab/lib.sh"
rev=$1 label=$2
note "== PR 111 (screenshots), $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app
mark=$(log_mark)
start_session
# The running look (countdown and end control) appears once the 5 s
# read-back after pmset has passed, with the "session started" log line.
if wait_log "$mark" 'session started until' 20; then note "session started from the menu bar"; else note "session did not start"; exit 1; fi
"$HOME/click" move 512 500
sleep 4
x=$(eye_x)
w=$(osascript -e 'tell application "System Events" to tell process "Insomnia" to get size of menu bar item 1 of menu bar 2' 2>/dev/null | cut -d, -f1 | tr -d ' ')
note "status item x $x, width $w (Accessibility); capturing x $((x - 150)) to $((x + w + 30))"
rm -rf "$OUT/111v-$label"
note "$("$HOME/grab" $((x - 150)) 0 $((w + 180)) 30 4 "$OUT/111v-$label")"
shot "111v-$label"
quit_app
state_note
