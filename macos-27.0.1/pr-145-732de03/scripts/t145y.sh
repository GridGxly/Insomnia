#!/bin/bash
# PR 145 pill click cases X11 to X15. t145y.sh LABEL [CASES]: runs against the
# installed app with TextEdit frontmost; CASES defaults to all five.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"; source "$HOME/lab/t145lib.sh"
label=$1 cases=${2:-X11 X12 X13 X14 X15}
te() { osascript -e 'tell application "System Events" to tell process "TextEdit" to get value of text area 1 of scroll area 1 of window 1' 2>&1; }
typ() { osascript -e "tell application \"System Events\" to keystroke \"$1\"" >/dev/null; }
bar() { screencapture -x -R800,0,640,34 "$OUT/$P-Y-$label-$1.png"; }
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
te_front() { osascript -e 'tell application "TextEdit" to activate' >/dev/null; sleep 1; }
textedit() {
  osascript -e 'tell application "Finder" to close every window' >/dev/null 2>&1
  killall TextEdit 2>/dev/null; sleep 1
  : > /tmp/x145.txt
  open -a TextEdit /tmp/x145.txt; sleep 3
  typ abc; sleep 0.5
}
started() { log_since "$1" | grep -E 'session started|extended' | cut -c1-140; }
note "== pill click cases $cases, $label: app CDHash $(codesign -dvvv "$APP" 2>&1 | awk -F= '/^CDHash=/ {print $2}')"
fresh_launch
textedit
note "Y0 TextEdit text '$(te)'; front $(front)"

case " $cases " in *" X11 "*)
# X11 overlapping presses: click Minutes, press Days 100 ms after that
# release and hold it 500 ms, so the hold runs past 0.2 s after the first
# release. The pills stay open and a typed 7 goes to Days (7 days, 604800 s).
m=$(log_mark)
open_pills; right=$((left + width)); mx=$((right - 43)); dx=$((right - 170))
note "X11 eye clicked: width $width; front $(front); Minutes click at x $mx, then Days press at x $dx 100 ms after the release, held 500 ms"
( sleep 0.55; geom; echo "$width" > /tmp/x11mid.txt; bar X11-mid-hold ) &
f0=$(fr); "$HOME/click2" "$mx" 12 "$dx" 100 500 > /tmp/click2.txt; fronts_after; wait; away
note "X11 front app: before the first press $f0, after the Days release $(cat /tmp/fr.txt)"
note "X11 events: $(cat /tmp/click2.txt)"
note "X11 width during the Days hold (sampled about 0.55 s after the first press, AX read took a bit more): $(cat /tmp/x11mid.txt)"
note "X11 after the Days release, widths:$(w_at X11)"
typ 7; sleep 0.5; bar X11-typed7; geom
note "X11 typed 7: width $width; TextEdit text '$(te)'"
key 36; wait_log "$m" "session started until|session extended by" 20 >/dev/null; sleep 1
note "X11 Enter: $(started "$m"); front $(front)"
typ m; sleep 0.5
note "X11 typed m after Enter: TextEdit text '$(te)'"
end_any; sleep 2; in_session && note "WARNING: session still running"
te_front
;; esac

case " $cases " in *" X12 "*)
# X12 return app after a pill click: eye, Minutes, 7, Enter.
m=$(log_mark)
note "X12 front before the eye click: $(front)"
open_pills; right=$((left + width))
"$HOME/click" $((right - 43)) 12; away
note "X12 Minutes pill clicked, widths:$(w_at X12)"
typ 7; sleep 0.5; bar X12-typed7
note "X12 typed 7: TextEdit text '$(te)'"
f0=$(fr); key 36; fronts_after; wait
note "X12 front app: before Enter $f0, after Enter $(cat /tmp/fr.txt)"
wait_log "$m" "session started until|session extended by" 20 >/dev/null; sleep 1
note "X12 Enter: $(started "$m"); front $(front)"
typ n; sleep 0.5
note "X12 typed n: TextEdit text '$(te)'; front $(front)"
end_any; sleep 2; in_session && note "WARNING: session still running"
te_front
;; esac

case " $cases " in *" X13 "*)
# X13 the same with Escape: eye, Minutes, 7, Escape.
m=$(log_mark)
note "X13 front before the eye click: $(front)"
open_pills; right=$((left + width))
"$HOME/click" $((right - 43)) 12; away
note "X13 Minutes pill clicked, widths:$(w_at X13)"
typ 7; sleep 0.5; bar X13-typed7
note "X13 typed 7: TextEdit text '$(te)'"
f0=$(fr); key 53; fronts_after; wait
note "X13 front app: before Escape $f0, after Escape $(cat /tmp/fr.txt)"
sleep 1; geom
note "X13 2 s after Escape: width $width; session lines '$(started "$m")'; $(sess); front $(front)"
typ o; sleep 0.5
note "X13 typed o: TextEdit text '$(te)'; front $(front)"
;; esac

case " $cases " in *" X14 "*)
# X14 the eye opens the pills, the eye closes them, a key 1 s later.
te_front
note "X14 front before the eye click: $(fr)"
open_pills; eye=$((left + 16))
note "X14 pills open: width $width; clicking the eye at x $eye"
f0=$(fr); "$HOME/click" "$eye" 12; fronts_after; wait
note "X14 front app: before the closing press $f0, after the release $(cat /tmp/fr.txt)"
typ p; sleep 0.5; geom
note "X14 typed p 1 s after the release: width $width; TextEdit text '$(te)'; front $(fr)"
;; esac

case " $cases " in *" X15 "*)
# X15 eye, Minutes, 7, then the eye commits instead of Enter.
te_front
m=$(log_mark)
note "X15 front before the eye click: $(fr)"
open_pills; right=$((left + width)); eye=$((left + 16))
"$HOME/click" $((right - 43)) 12; away
note "X15 Minutes pill clicked, widths:$(w_at X15)"
typ 7; sleep 0.5; bar X15-typed7; geom; eye=$((left + 16))
note "X15 typed 7: width $width; TextEdit text '$(te)'; clicking the eye at x $eye"
f0=$(fr); "$HOME/click" "$eye" 12; fronts_after; wait
note "X15 front app: before the eye press $f0, after the release $(cat /tmp/fr.txt)"
wait_log "$m" "session started until|session extended by" 20 >/dev/null; sleep 1
note "X15 eye commit: $(started "$m"); front $(fr)"
typ q; sleep 0.5
note "X15 typed q: TextEdit text '$(te)'; front $(fr)"
end_any; sleep 2; in_session && note "WARNING: session still running"
;; esac

killall TextEdit 2>/dev/null
note "pill click cases $cases, $label done"
