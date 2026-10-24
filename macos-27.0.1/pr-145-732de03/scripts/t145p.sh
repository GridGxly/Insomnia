#!/bin/bash
# PR 145 follow-up: a click on a pill while the pills are open. t145p.sh LABEL
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"; source "$HOME/lab/t145lib.sh"
label=$1
burst() {  # burst NAME: item width and a shot with the pointer at +0.1, +0.6 and +1.5 s
  local i d
  for d in 0.1 0.5 0.9; do
    sleep "$d"
    i=$((${i:-0} + 1))
    screencapture -x -C -R800,0,640,34 "$OUT/$P-P-$label-$1-$i.png"
    geom
    printf '%s ' "+$i: width $width"
  done
}
note "== pill clicks, $label: $(cd ~/src && git rev-parse --short HEAD), app CDHash $(codesign -dvvv "$APP" 2>&1 | awk -F= '/^CDHash=/ {print $2}')"
fresh_launch
for pill in Minutes Days; do
  m=$(log_mark)
  "$HOME/click" $(($(eye_x) + 16)) 12
  sleep 1.5
  geom
  right=$((left + width))
  case $pill in Minutes) px=$((right - 43)) ;; Days) px=$((right - 170)) ;; esac
  note "P1 idle, eye clicked: item x $left width $width; clicking the $pill pill at x $px"
  screencapture -x -C -R800,0,640,34 "$OUT/$P-P-$label-idle-$pill-0.png"
  "$HOME/click" "$px" 12
  note "P1 after the click: $(burst "idle-$pill")"
  osascript -e 'tell application "System Events" to keystroke "7"' >/dev/null
  sleep 0.6
  geom
  screencapture -x -C -R800,0,640,34 "$OUT/$P-P-$label-idle-$pill-typed7.png"
  note "P1 typed 7: item width $width; log since the eye click:"
  log_since "$m" | sed 's/^/    /'
  key 53
  sleep 1.5
done
begin || exit 1
geom
m=$(log_mark)
"$HOME/click" $(((left + 24 + rx - 12) / 2)) 12
sleep 1.5
geom
right=$((left + width))
note "P2 running, countdown clicked: item x $left width $width; clicking the Minutes pill at x $((right - 43))"
screencapture -x -C -R800,0,640,34 "$OUT/$P-P-$label-running-Minutes-0.png"
"$HOME/click" $((right - 43)) 12
note "P2 after the click: $(burst running-Minutes)"
osascript -e 'tell application "System Events" to keystroke "7"' >/dev/null
sleep 0.6
geom
screencapture -x -C -R800,0,640,34 "$OUT/$P-P-$label-running-Minutes-typed7.png"
note "P2 typed 7: item width $width; log since the countdown click:"
log_since "$m" | sed 's/^/    /'
key 53
sleep 1.5
end_any
note "pill clicks, $label done"
