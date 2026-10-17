#!/bin/bash
# PR 111, ticks: N sessions, 8 s of status item screenshots in each, to count
# seconds the countdown skipped or held. t111j.sh REV LABEL N
source "$HOME/lab/lib.sh"
rev=$1 label=$2 n=${3:-8}
note "== PR 111 (ticks, $n sessions), $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
for i in $(seq "$n"); do
  launch_app
  mark=$(log_mark)
  start_session
  if ! wait_log "$mark" 'session started until' 20; then note "session $i did not start"; quit_app; continue; fi
  "$HOME/click" move 512 500
  sleep 2
  x=$(eye_x)
  w=$(osascript -e 'tell application "System Events" to tell process "Insomnia" to get size of menu bar item 1 of menu bar 2' 2>/dev/null | cut -d, -f1 | tr -d ' ')
  d="$OUT/111j-$label/$i"
  rm -rf "$d"; mkdir -p "$d"
  note "session $i: $(log_since "$mark" | grep -m1 'session started until' | cut -c1-21,47-90); $("$HOME/grab" $((x - 150)) 0 $((w + 180)) 30 8 "$d")"
  quit_app
done
state_note
