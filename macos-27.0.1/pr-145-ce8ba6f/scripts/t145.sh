#!/bin/bash
# PR 145 (#93 #74 #143 #84 #132 #137 integrated) on macOS 27: hold-to-end,
# End session in the menu, the menu's Time left line, the countdown toggle,
# End time with CPU and a time zone change, displays asleep, and typing a
# duration. t145.sh PART... (A B C D G E F). Part G types $VM_PASSWORD, the
# VM user's password, into the prompt System Settings shows.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"; source "$HOME/lab/t145lib.sh"
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
ends() { log_since "$1" | grep -c 'session end'; }
count_menu() {
  note "$1 menu items: $2"
  note "$1 End session items: $(echo "$2" | grep -o 'End session' | wc -l | tr -d ' '); Time left rows: $(echo "$2" | grep -o 'Time left' | wc -l | tr -d ' '); first item: $(echo "$2" | cut -d, -f1)"
}
settings_toggle_countdown() {
  open_settings
  scroll_settings 1 >/dev/null
  sleep 1
  note "$1 press 'Show the countdown in the menu bar': $(ax_press AXCheckBox 'Show the countdown in the menu bar'); config showMenuBarCountdown $(config_get showMenuBarCountdown)"
  sleep 1
  [ -n "${2:-}" ] && shot_window "$2"
  close_window
  sleep 1
}

partA() {
  note "== A. Hold-to-end, countdown on, Time left"
  fresh_launch
  begin || return
  geom
  note "status item x $left, width $width; end ring at x $rx, y 12"
  shot_menubar "$P-A0-running"
  local m t s
  m=$(log_mark)
  "$HOME/hold" "$rx" 12 100
  sleep 3
  geom
  note "A1 short tap, 100 ms press on the ring: session end lines $(ends "$m"); $(sess); SleepDisabled $(sleep_disabled); item width $width"
  shot_menubar "$P-A1-after-short-tap"
  for spec in "300 $rx 90 down" "500 $rx 90 down" "500 $((rx - 40)) 12 left"; do
    set -- $spec
    t=$1
    geom
    m=$(log_mark)
    s=$(echo "$t" | awk '{printf "%.2f", 0.15 + $1 / 1000 + 0.3}')
    ( sleep "$s"; screencapture -x -R"$((rx - 120)),0,170,110" "$OUT/$P-A2-slide-$t-$4.png" ) &
    "$HOME/drag" "$rx" 12 "$t" "$2" "$3" 900
    wait
    sleep 3
    geom
    note "A2 press on the ring for $t ms, slide $4 off it to $2,$3 in 60 ms, release 0.9 s later: session end lines $(ends "$m"); $(sess); SleepDisabled $(sleep_disabled); item width $width"
    key 53
    sleep 1
  done
  geom
  local cx=$(((left + 24 + rx - 12) / 2))
  m=$(log_mark)
  "$HOME/click" "$cx" 12
  sleep 1.5
  geom
  note "A3 click on the countdown at x $cx: item width $width (pills open when wider than the running 120)"
  shot_menubar "$P-A3-countdown-click"
  local right=$((left + width))
  "$HOME/click" $((right - 43)) 12
  sleep 0.8
  osascript -e 'tell application "System Events" to keystroke "7"' >/dev/null
  sleep 0.8
  note "A3 clicked the Minutes pill at x $((right - 43)), typed 7"
  shot_menubar "$P-A3-minutes-pill-click"
  key 53
  sleep 1.5
  geom
  note "A3 Esc: item width $width; extend lines in the log: $(log_since "$m" | grep -ci 'extend')"
  m=$(log_mark)
  "$HOME/click" $((left + 16)) 12
  sleep 1.5
  geom
  note "A4 click on the eye: item width $width"
  shot_menubar "$P-A4-eye-click"
  key 53
  sleep 1.5
  geom
  note "A4 Esc: item width $width"
  for n in 1 2; do
    if [ "$n" = 2 ]; then begin || return; fi
    geom
    m=$(log_mark)
    rm -f /tmp/midhold.txt
    ( sleep 0.6; screencapture -x -R"$((rx - 120)),0,170,30" "$OUT/$P-A5-mid-hold-$n.png" ) &
    ( sleep 1.05; echo "$(sess); session end lines $(ends "$m")" > /tmp/midhold.txt ) &
    note "A5 hold $n: press on the ring at x $rx for 1.5 s (press at about +0.15 s)"
    "$HOME/hold" "$rx" 12 1500
    wait
    sleep 3
    note "A5 hold $n: 0.9 s after the press, button still down: $(cat /tmp/midhold.txt)"
    note "A5 hold $n: after the release: $(sess); SleepDisabled $(sleep_disabled)"
    log_since "$m" | grep -E 'session end|sleep restored|app nap' | sed 's/^/    /'
    shot_menubar "$P-A5-after-hold-$n"
  done
}

partB() {
  note "== B. End session in the right-click menu"
  fresh_launch
  begin || return
  local names m e
  open_menu
  names=$(menu_names)
  count_menu B1 "$names"
  shot_menubar "$P-B1-menu" 240
  m=$(log_mark)
  note "B1 click End session: $(menu_click 'End session')"
  sleep 5
  log_since "$m" | grep -vE 'wifi|Wi-Fi' | sed 's/^/    /'
  state_note
  note "B1 app pid after: $(app_pid)"
  shot_menubar "$P-B1-after-end"
  note "B2 a 1 minute session; the menu opens 20 s before its end and stays open until 15 s after it"
  begin 1 || return
  e=$(ends_at)
  note "B2 session ends at $(date -u -r "$e" +%H:%M:%SZ)"
  while [ "$(date +%s)" -lt $((e - 20)) ]; do sleep 1; done
  m=$(log_mark)
  open_menu
  names=$(menu_names)
  count_menu "B2 at end-20 s" "$names"
  shot_menubar "$P-B2-menu-before-end" 240
  while [ "$(date +%s)" -lt $((e + 15)) ]; do sleep 1; done
  note "B2 at end+15 s, menu still open: $(sess); SleepDisabled $(sleep_disabled)"
  shot_menubar "$P-B2-menu-after-end" 240
  log_since "$m" | grep -vE 'wifi|Wi-Fi' | sed 's/^/    /'
  m=$(log_mark)
  note "B2 click End session in the menu left open: $(menu_click 'End session')"
  sleep 5
  note "B2 log after that click:"
  log_since "$m" | sed 's/^/    /'
  state_note
  note "B2 app pid after: $(app_pid)"
  key 53
  sleep 1
  open_menu
  count_menu "B3 menu reopened after the end" "$(menu_names)"
  shot_menubar "$P-B3-menu-after-end-reopened" 200
  key 53
}

partC() {
  note "== C. Show the countdown in the menu bar, off and on mid-session"
  fresh_launch
  geom
  local idle=$width names m
  note "C0 idle item width $idle"
  begin || return
  geom
  note "C0 countdown on: item width $width; bar reads: $(bar_text)"
  shot_menubar "$P-C0-bar-on"
  settings_toggle_countdown C1 "$P-C1-settings-off"
  geom
  note "C1 countdown off mid-session: item width $width; bar reads: $(bar_text)"
  shot_menubar "$P-C1-bar-off"
  open_menu
  names=$(menu_names)
  count_menu C1 "$names"
  shot_menubar "$P-C1-menu-off" 260
  key 53
  sleep 1
  "$HOME/click" $(($(eye_x) + 16)) 12
  sleep 1.5
  geom
  note "C1 click on the eye with the countdown off: item width $width"
  shot_menubar "$P-C1-eye-click-off"
  key 53
  sleep 1.5
  settings_toggle_countdown C2
  geom
  note "C2 countdown back on mid-session: item width $width; bar reads: $(bar_text)"
  shot_menubar "$P-C2-bar-on-again"
  open_menu
  count_menu C2 "$(menu_names)"
  shot_menubar "$P-C2-menu-on" 240
  key 53
  note "C3 a start with the countdown already off"
  fresh_launch '{"showMenuBarCountdown": false}'
  geom
  idle=$width
  note "C3 idle item width $idle"
  begin || return
  geom
  note "C3 running: item width $width (idle $idle); bar reads: $(bar_text)"
  shot_menubar "$P-C3-bar-off-running"
  open_menu
  count_menu C3 "$(menu_names)"
  shot_menubar "$P-C3-menu-off" 260
  m=$(log_mark)
  note "C3 click End session: $(menu_click 'End session')"
  sleep 5
  log_since "$m" | grep -E 'session end|sleep restored' | sed 's/^/    /'
  state_note
  geom
  note "C3 after the end: item width $width"
  shot_menubar "$P-C3-after-end-eye"
}

partD() {
  note "== D. Countdown set to End time, picked in Settings mid-session"
  fresh_launch
  begin || return
  sleep 8
  note "D0 Time left, 10 s after the start, 40 samples: CPU $(cpu_mean 40)"
  open_settings
  scroll_settings 0 >/dev/null
  sleep 1
  note "D1 pick End time: $(ax_pick Countdown 'End time'); config countdownStyle $(config_get countdownStyle)"
  sleep 1
  shot_window "$P-D1-settings-end-time"
  close_window
  geom
  note "D1 bar: item width $width; reads: $(bar_text)"
  shot_menubar "$P-D1-bar-end-time"
  open_menu
  count_menu D2 "$(menu_names)"
  shot_menubar "$P-D2-menu-end-time" 260
  key 53
  settings_toggle_countdown "D2b countdown off with End time:"
  open_menu
  count_menu "D2b countdown off, End time" "$(menu_names)"
  shot_menubar "$P-D2b-menu-off-end-time" 260
  key 53
  settings_toggle_countdown "D2b countdown on again:"
  sleep 10
  local pid c0
  pid=$(app_pid)
  c0=$(ps -o time= -p "$pid" | tr -d ' ')
  note "D3 End time, 10 s after the switch, 40 samples: CPU $(cpu_mean 40); CPU time $c0 -> $(ps -o time= -p "$pid" | tr -d ' ')"
}

# Frames of the status item every 0.15 s or so for $2 seconds, named $1-N.png
# in /tmp/frames, with their times in /tmp/frames/$1.times.
frames() {
  mkdir -p /tmp/frames
  rm -f /tmp/frames/"$1"-*.png
  : > /tmp/frames/"$1".times
  local end i=0
  end=$(perl -e "print time + $2")
  while [ "$(date +%s)" -lt "$end" ]; do
    i=$((i + 1))
    screencapture -x -R"$((left - 4)),0,$((width + 8)),30" "/tmp/frames/$1-$i.png"
    echo "$i $(now)" >> /tmp/frames/"$1".times
    sleep 0.1
  done
}
# The first frame that differs from frame 1, and its time after $2.
first_change() {
  local base n t
  base=$(md5 -q "/tmp/frames/$1-1.png")
  cp "/tmp/frames/$1-1.png" "$OUT/$P-$1-frame1.png"
  while read -r n t; do
    if [ "$(md5 -q "/tmp/frames/$1-$n.png")" != "$base" ]; then
      echo "frame $n, $(echo "$t $2" | awk '{printf "%.2f", $1 - $2}') s after the change"
      cp "/tmp/frames/$1-$n.png" "$OUT/$P-$1-first-changed.png"
      return
    fi
  done < /tmp/frames/"$1".times
  echo "no change in $(wc -l < /tmp/frames/"$1".times | tr -d ' ') frames"
}

partE() {
  note "== E. Displays asleep"
  local pid m c0 c1 st
  for st in remaining endTime; do
    if [ "$st" = remaining ]; then fresh_launch; else fresh_launch '{"countdownStyle": "endTime"}'; fi
    begin || return
    pid=$(app_pid)
    m=$(log_mark)
    pmset displaysleepnow
    sleep 5
    c0=$(ps -o time= -p "$pid" | tr -d ' ')
    note "E1 $st, 5 s after pmset displaysleepnow: displays $("$HOME/dispasleep"); log:"
    log_since "$m" | grep -iE 'display|countdown' | sed 's/^/    /'
    sleep 60
    c1=$(ps -o time= -p "$pid" | tr -d ' ')
    note "E1 $st, 60 s untouched: CPU time $c0 -> $c1; displays $("$HOME/dispasleep"); CPU $(cpu_mean 20)"
    if [ "$st" = remaining ]; then
      kill -9 "$pid"
      sleep 2
      m=$(log_mark)
      open "$APP"
      for _ in $(seq 20); do [ -n "$(app_pid)" ] && break; sleep 1; done
      sleep 8
      pid=$(app_pid)
      c0=$(ps -o time= -p "$pid" | tr -d ' ')
      note "E2 force-quit and opened again while asleep: pid $pid; displays $("$HOME/dispasleep"); log:"
      log_since "$m" | grep -iE 'display|countdown|resum|reconcile|session' | sed 's/^/    /'
      sleep 30
      note "E2 30 s later: CPU time $c0 -> $(ps -o time= -p "$pid" | tr -d ' '); displays $("$HOME/dispasleep")"
    fi
    m=$(log_mark)
    caffeinate -u -t 1
    sleep 3
    note "E3 $st, after a wake (caffeinate -u): displays $("$HOME/dispasleep"); log:"
    log_since "$m" | grep -iE 'display|countdown' | sed 's/^/    /'
    note "E3 $st: lines since the wake that say restarted: $(log_since "$m" | grep -c 'redraw restarted'); bar reads: $(bar_text)"
    shot_menubar "$P-E3-$st-after-wake"
    sleep 2
    note "E3 $st, 2 s later, bar reads: $(bar_text)"
  done
}

partF() {
  note "== F. Typing a duration after clicking the eye (#143)"
  fresh_launch
  killall TextEdit 2>/dev/null
  sleep 1
  : > /tmp/f145.txt
  open -a TextEdit /tmp/f145.txt
  sleep 3
  osascript -e 'tell application "System Events" to keystroke "abc"' >/dev/null
  sleep 0.5
  te() { osascript -e 'tell application "System Events" to tell process "TextEdit" to get value of text area 1 of scroll area 1 of window 1' 2>&1; }
  note "F0 TextEdit front with '$(te)' typed into it; front: $(front)"
  local x m
  x=$(eye_x)
  "$HOME/click" $((x + 16)) 12
  sleep 1.5
  geom
  note "F1 clicked the eye: item width $width; front $(front)"
  osascript -e 'tell application "System Events" to keystroke "2"' >/dev/null
  key 48
  osascript -e 'tell application "System Events" to keystroke "35"' >/dev/null
  key 51
  sleep 0.8
  shot_menubar "$P-F1-typed"
  note "F1 typed 2, Tab, 35, Backspace: TextEdit text '$(te)'"
  key 53
  sleep 1.5
  geom
  note "F1 Esc: item width $width; front $(front)"
  osascript -e 'tell application "System Events" to keystroke "d"' >/dev/null
  sleep 0.5
  note "F1 typed d after Esc: TextEdit text '$(te)'"
  m=$(log_mark)
  x=$(eye_x)
  "$HOME/click" $((x + 16)) 12
  sleep 1.5
  key 48
  osascript -e 'tell application "System Events" to keystroke "30"' >/dev/null
  sleep 0.5
  shot_menubar "$P-F2-typed-30"
  key 36
  if wait_log "$m" 'session started until' 30; then note "F2 Tab, 30, Enter: $(log_since "$m" | grep -m1 'session started until' | cut -c1-120)"; else note "F2 no session start"; fi
  sleep 1
  note "F2 after Enter: front $(front); TextEdit text '$(te)'"
  osascript -e 'tell application "System Events" to keystroke "e"' >/dev/null
  sleep 0.5
  note "F2 typed e: TextEdit text '$(te)'"
  geom
  m=$(log_mark)
  "$HOME/click" $(((left + 24 + rx - 12) / 2)) 12
  sleep 1.5
  osascript -e 'tell application "System Events" to keystroke "1"' >/dev/null
  sleep 0.5
  shot_menubar "$P-F3-extend-typed"
  note "F3 clicked the countdown, typed 1: TextEdit text '$(te)'"
  key 53
  sleep 1.5
  geom
  note "F3 Esc: item width $width; front $(front); extend lines $(log_since "$m" | grep -ci extend)"
  osascript -e 'tell application "System Events" to keystroke "f"' >/dev/null
  sleep 0.5
  note "F3 typed f: TextEdit text '$(te)'"
  x=$(eye_x)
  "$HOME/click" $((x + 16)) 12
  sleep 1.5
  geom
  note "F4 pills open again: item width $width; front $(front)"
  open -a Finder
  sleep 1.5
  geom
  note "F4 switched to Finder with the pills open: item width $width; front $(front)"
  shot_menubar "$P-F4-after-switch"
  osascript -e 'tell application "System Events" to keystroke "3"' >/dev/null
  sleep 0.5
  geom
  note "F4 typed 3 in Finder: item width $width"
  x=$(eye_x)
  "$HOME/click" $((x + 16)) 12
  sleep 1.5
  "$HOME/click" 440 300
  sleep 1.5
  geom
  note "F5 pills open, then a click in TextEdit's window: item width $width; front $(front)"
  osascript -e 'tell application "System Events" to keystroke "g"' >/dev/null
  sleep 0.5
  note "F5 typed g: TextEdit text '$(te)'"
  shot "$P-F5-screen"
  killall TextEdit 2>/dev/null
}

partG() {
  note "== G. End time and a time zone change in System Settings"
  fresh_launch '{"countdownStyle": "endTime"}'
  begin || return
  local pid c0 t0
  sleep 2
  geom
  note "G0 time zone: $(sudo -n systemsetup -gettimezone); date: $(date); item width $width"
  shot_menubar "$P-G0-before"
  open "x-apple.systempreferences:com.apple.Date-Time-Settings.extension"
  sleep 4
  "$HOME/click" 900 418
  sleep 1
  osascript -e 'tell application "System Events" to keystroke "a" using command down' >/dev/null
  osascript -e 'tell application "System Events" to keystroke "New York"' >/dev/null
  sleep 2.5
  key 36
  sleep 2.5
  shot "$P-G1-password-prompt"
  osascript -e "tell application \"System Events\" to keystroke \"$VM_PASSWORD\"" >/dev/null
  sleep 0.5
  geom
  frames tz1 8 &
  sleep 1.5
  t0=$(now)
  key 36
  note "G1 Unlock pressed (Return) in the prompt for the Time zone city change to New York"
  wait
  note "G1 time zone now: $(sudo -n systemsetup -gettimezone); date: $(date)"
  note "G1 status item: $(first_change tz1 "$t0")"
  shot "$P-G1-after"
  shot_menubar "$P-G1-bar-after"
  osascript -e 'tell application "System Settings" to quit' >/dev/null
  sleep 3
  pid=$(app_pid)
  c0=$(ps -o time= -p "$pid" | tr -d ' ')
  note "G2 after the change, 40 samples: CPU $(cpu_mean 40); CPU time $c0 -> $(ps -o time= -p "$pid" | tr -d ' ')"
  open_menu
  count_menu G2 "$(menu_names)"
  shot_menubar "$P-G2-menu" 260
  key 53
  sleep 2
  geom
  frames tz2 6 &
  sleep 1.5
  t0=$(now)
  sudo -n systemsetup -settimezone GMT >/dev/null 2>&1
  note "G3 time zone set back with systemsetup -settimezone GMT"
  wait
  note "G3 time zone now: $(sudo -n systemsetup -gettimezone); date: $(date)"
  note "G3 status item: $(first_change tz2 "$t0")"
  shot_menubar "$P-G3-bar-back"
}

note "== PR 145 at $(cd ~/src && git rev-parse --short HEAD) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)); app CDHash $(codesign -dvvv "$APP" 2>&1 | awk -F= '/^CDHash=/ {print $2}'); locale $(defaults read -g AppleLocale); time zone $(sudo -n systemsetup -gettimezone)"
for part in "$@"; do
  "part$part"
done
end_any
quit_app
note "t145 done"
