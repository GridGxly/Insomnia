#!/bin/bash
# PR 93 follow-up on a light menu bar: the ring with the pointer away and on
# it, and three holds, each after the log says the session started (the
# first run held once during the start). t93b.sh REV LABEL
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
note "== PR 93 follow-up, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
osascript -e 'tell application "System Events" to tell every desktop to set picture to "/System/Library/Desktop Pictures/Solid Colors/Silver.png"' >/dev/null
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
for attempt in 1 2 3; do
  mark=$(log_mark)
  start_session
  if wait_log "$mark" 'session started until' 30; then note "hold $attempt: log says session started"; else note "hold $attempt: no session start in the log"; exit 1; fi
  sleep 2
  pos=$(ax 'get position of menu bar item 1 of menu bar 2' | tr -d ' ')
  size=$(ax 'get size of menu bar item 1 of menu bar 2' | tr -d ' ')
  left=${pos%,*} width=${size%,*}
  rx=$((left + width - 12))
  if [ "$attempt" = 1 ]; then
    "$HOME/move" 700 450; sleep 2
    shot_menubar "93b-$label-light-pointer-away"
    "$HOME/move" "$rx" 12; sleep 2
    shot_menubar "93b-$label-light-pointer-on-ring"
    note "status item at x $left, width $width; ring at x $rx"
  fi
  mark=$(log_mark)
  ( sleep 0.7; screencapture -x -R"$((rx - 120)),0,160,30" "$OUT/93b-$label-mid-hold-$attempt.png" ) &
  "$HOME/hold" "$rx" 12 1500
  wait
  sleep 3
  if log_since "$mark" | grep -q 'session end (user)'; then
    note "hold $attempt: 1.5 s hold on the ring ended the session: $(log_since "$mark" | grep -m1 'session end')"
  else
    note "hold $attempt: 1.5 s hold on the ring did not end the session; log: $(log_since "$mark" | tr '\n' ' ' | cut -c1-300)"
    shot_menubar "93b-$label-after-hold-$attempt" 120
    key 53; quit_app; launch_app
  fi
  state_note
done
quit_app
osascript -e 'tell application "System Events" to tell every desktop to set picture to "/System/Library/Desktop Pictures/Mac Blue.heic"' >/dev/null
state_note
