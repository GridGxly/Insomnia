#!/bin/bash
# PR 93: press and hold the end ring on macOS 27; the ring on a light menu
# bar. t93.sh REV LABEL
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
note "== PR 93, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
for attempt in 1 2 3; do
  start_session
  if wait_sleep_disabled; then note "hold $attempt: session started; SleepDisabled 1"; else note "session did not start"; exit 1; fi
  sleep 4
  pos=$(ax 'get position of menu bar item 1 of menu bar 2' | tr -d ' ')
  size=$(ax 'get size of menu bar item 1 of menu bar 2' | tr -d ' ')
  left=${pos%,*} width=${size%,*}
  rx=$((left + width - 12))
  [ "$attempt" = 1 ] && { shot_menubar "93-$label-running"; note "status item at x $left, width $width; ring at x $rx"; }
  mark=$(log_mark)
  ( sleep 0.55; screencapture -x -R"$((rx - 120)),0,160,30" "$OUT/93-$label-mid-hold-$attempt.png" ) &
  "$HOME/hold" "$rx" 12 1500
  wait
  sleep 3
  if log_since "$mark" | grep -q 'session end (user)'; then
    note "hold $attempt: 1.5 s hold on the ring ended the session: $(log_since "$mark" | grep -m1 'session end')"
  else
    note "hold $attempt: 1.5 s hold on the ring did not end the session; log: $(log_since "$mark" | tr '\n' ' ' | cut -c1-300)"
    quit_app; launch_app
  fi
  state_note
done
# A light menu bar: a light solid wallpaper.
pic=$(ls "/System/Library/Desktop Pictures/Solid Colors/" | grep -m1 -E '^(Silver|Stone|White|Soft)')
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"/System/Library/Desktop Pictures/Solid Colors/$pic\"" >/dev/null
note "wallpaper set to $pic"
sleep 3
start_session
wait_sleep_disabled >/dev/null
sleep 4
shot_menubar "93-$label-light"
quit_app
state_note
