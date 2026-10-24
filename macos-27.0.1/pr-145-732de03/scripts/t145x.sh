#!/bin/bash
# PR 145 pill click fix check. t145x.sh LABEL: runs against the installed app
# with TextEdit frontmost, and reads TextEdit's text through accessibility.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"; source "$HOME/lab/t145lib.sh"
label=$1
te() { osascript -e 'tell application "System Events" to tell process "TextEdit" to get value of text area 1 of scroll area 1 of window 1' 2>&1; }
typ() { osascript -e "tell application \"System Events\" to keystroke \"$1\"" >/dev/null; }
bar() { screencapture -x -R800,0,640,34 "$OUT/$P-X-$label-$1.png"; }
away() { "$HOME/move" 700 600; }
w_at() {  # w_at NAME: width about 0.1, 0.6 and 1.5 s after the last click
  local d i=0 out=""
  for d in 0.1 0.5 0.9; do sleep "$d"; i=$((i + 1)); geom; out="$out +$i: $width"; bar "$1-$i"; done
  echo "$out"
}
open_pills() { "$HOME/click" $(($(eye_x) + 16)) 12; sleep 1.5; geom; }
fr() { lsappinfo info -only bundleid "$(lsappinfo front)" 2>/dev/null | sed -nE 's/.*bundleID="?([^"]*)"?.*/\1/p' | head -1; }
# The front app about 0.1 s and 1 s after the call, into /tmp/fr.txt.
fronts_after() { ( sleep 0.1; a=$(fr); sleep 0.9; echo "+0.1 s $a, +1 s $(fr)" > /tmp/fr.txt ) & }
textedit() {
  osascript -e 'tell application "Finder" to close every window' >/dev/null 2>&1
  killall TextEdit 2>/dev/null; sleep 1
  : > /tmp/x145.txt
  open -a TextEdit /tmp/x145.txt; sleep 3
  typ abc; sleep 0.5
}
note "== pill click fix check, $label: app CDHash $(codesign -dvvv "$APP" 2>&1 | awk -F= '/^CDHash=/ {print $2}')"
fresh_launch
textedit
note "X0 TextEdit text '$(te)'; front $(front)"

# X1 idle: eye, then the Minutes pill, 7, Enter.
m=$(log_mark)
open_pills; right=$((left + width))
note "X1 eye clicked: width $width; clicking the Minutes pill at x $((right - 43))"
"$HOME/click" $((right - 43)) 12; away
note "X1 after the pill click, widths:$(w_at X1)"
typ 7; sleep 0.5; bar X1-typed7
note "X1 typed 7: TextEdit text '$(te)'"
key 36; wait_log "$m" "session started until|session extended by" 20 >/dev/null; sleep 1
note "X1 Enter: $(log_since "$m" | grep -E 'session started|extended' | cut -c1-140)"
typ d; sleep 0.5
note "X1 typed d after Enter: TextEdit text '$(te)'; front $(front)"
end_any; sleep 2; in_session && note "WARNING: session still running"

# X2 idle: eye, then the Days pill, 1, Enter.
m=$(log_mark)
open_pills; right=$((left + width))
"$HOME/click" $((right - 170)) 12; away
note "X2 Days pill clicked at x $((right - 170)), widths:$(w_at X2)"
typ 1; sleep 0.5; bar X2-typed1
note "X2 typed 1: TextEdit text '$(te)'"
key 36; wait_log "$m" "session started until|session extended by" 20 >/dev/null; sleep 1
note "X2 Enter: $(log_since "$m" | grep -E 'session started|extended' | cut -c1-140)"
typ e; sleep 0.5
note "X2 typed e after Enter: TextEdit text '$(te)'"
end_any; sleep 2; in_session && note "WARNING: session still running"

# X3 running: countdown, then the Minutes pill, 7, Enter extends by 420 s.
begin || exit 1
osascript -e 'tell application "TextEdit" to activate' >/dev/null; sleep 1
m=$(log_mark)
geom
"$HOME/click" $(((left + 24 + rx - 12) / 2)) 12; sleep 1.5; geom; right=$((left + width))
note "X3 countdown clicked: width $width; front $(front)"
"$HOME/click" $((right - 43)) 12; away
note "X3 Minutes pill clicked, widths:$(w_at X3)"
typ 7; sleep 0.5; bar X3-typed7
note "X3 typed 7: TextEdit text '$(te)'"
key 36; wait_log "$m" "session started until|session extended by" 20 >/dev/null; sleep 1
note "X3 Enter: $(log_since "$m" | grep -E 'session started|extended' | cut -c1-140)"
typ f; sleep 0.5
note "X3 typed f after Enter: TextEdit text '$(te)'"
end_any; sleep 2; in_session && note "WARNING: session still running"
osascript -e 'tell application "TextEdit" to activate' >/dev/null; sleep 1

# X4 a click on the eye while the pills are open.
open_pills; eye=$((left + 16))
note "X4 pills open: width $width; clicking the eye at x $eye"
f0=$(fr); "$HOME/click" "$eye" 12; fronts_after; away
note "X4 after the eye click, widths:$(w_at X4)"
wait; note "X4 front app: before the press $f0, after the release $(cat /tmp/fr.txt)"
typ g; sleep 0.5
note "X4 typed g: TextEdit text '$(te)'; front $(front)"

# X5 a press on a pill dragged off the item, released below it.
open_pills; right=$((left + width))
note "X5 pills open: width $width; press on Minutes at x $((right - 43)), drag to y 90, release"
"$HOME/drag" $((right - 43)) 12 150 $((right - 43)) 90 300; away
note "X5 after the release, widths:$(w_at X5)"
typ h; sleep 0.5
note "X5 typed h: TextEdit text '$(te)'; front $(front)"
key 53; sleep 1

# X6 a click on the item's right edge, past the Minutes pill.
open_pills; right=$((left + width))
note "X6 pills open: width $width; clicking x $((right - 3))"
"$HOME/click" $((right - 3)) 12; away
note "X6 after the click, widths:$(w_at X6)"
typ 5; sleep 0.5; bar X6-typed5; geom
note "X6 typed 5: width $width; TextEdit text '$(te)'"
key 53; sleep 1.5

# X7 a click in TextEdit's window.
open_pills
wpos=$(osascript -e 'tell application "System Events" to tell process "TextEdit" to get position of window 1' | tr -d ' ')
note "X7 pills open: width $width; clicking in TextEdit's window at $((${wpos%,*} + 200)),$((${wpos#*,} + 200))"
"$HOME/click" $((${wpos%,*} + 200)) $((${wpos#*,} + 200))
note "X7 after the click, widths:$(w_at X7)"
typ j; sleep 0.5
note "X7 typed j: TextEdit text '$(te)'; front $(front)"

# X8 Cmd-Tab.
open_pills
note "X8 pills open: width $width; front $(front)"
osascript -e 'tell application "System Events" to key code 48 using command down' >/dev/null
note "X8 after Cmd-Tab, widths:$(w_at X8); front $(front)"
osascript -e 'tell application "TextEdit" to activate' >/dev/null; sleep 1

# X9 Escape.
open_pills
note "X9 pills open: width $width"
key 53
note "X9 after Esc, widths:$(w_at X9)"
typ k; sleep 0.5
note "X9 typed k: TextEdit text '$(te)'"

# X10 Enter with nothing typed starts the default.
m=$(log_mark)
open_pills
key 36; wait_log "$m" "session started until|session extended by" 20 >/dev/null; sleep 1
note "X10 Enter with nothing typed: $(log_since "$m" | grep -E 'session started' | cut -c1-140)"
typ l; sleep 0.5
note "X10 typed l: TextEdit text '$(te)'"
end_any; in_session && note "WARNING: session still running"
killall TextEdit 2>/dev/null
note "pill click fix check, $label done"
