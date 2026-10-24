#!/bin/bash
# PR 145: the pills open, then a click into another app's window.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"; source "$HOME/lab/t145lib.sh"
quit_app
cd "$HOME/src" && git checkout -q --detach ce8ba6f01adfe3ef3f4368320afc3a586e42a72d
./scripts/install.sh --allow-unverified-origin --app "$HOME/builds/ce8ba6f/Insomnia.app" > "$OUT/install-ce8ba6f-again.log" 2>&1
note "reinstalled ce8ba6f: install.sh exit $?; ~/src at $(git rev-parse --short HEAD), status lines $(git status --short | wc -l | tr -d ' '); app CDHash $(codesign -dvvv "$APP" 2>&1 | awk -F= '/^CDHash=/ {print $2}')"
osascript -e 'tell application "Finder" to close every window' >/dev/null 2>&1
fresh_launch
killall TextEdit 2>/dev/null; sleep 1
: > /tmp/f145.txt
open -a TextEdit /tmp/f145.txt
sleep 3
te() { osascript -e 'tell application "System Events" to tell process "TextEdit" to get value of text area 1 of scroll area 1 of window 1' 2>&1; }
osascript -e 'tell application "System Events" to keystroke "abc"' >/dev/null
sleep 0.5
wpos=$(osascript -e 'tell application "System Events" to tell process "TextEdit" to get position of window 1' | tr -d ' ')
note "F5 TextEdit text '$(te)', window at $wpos; front $(front)"
"$HOME/click" $(($(eye_x) + 16)) 12
sleep 1.5
geom
note "F5 eye clicked: item width $width; front $(front)"
osascript -e 'tell application "Finder" to activate' >/dev/null
sleep 1.5
geom
note "F5 then Finder activated: item width $width; front $(front)"
"$HOME/click" $(($(eye_x) + 16)) 12
sleep 1.5
geom
note "F6 eye clicked again: item width $width; front $(front)"
"$HOME/click" $((${wpos%,*} + 200)) $((${wpos#*,} + 200))
sleep 1.5
geom
note "F6 then a click inside TextEdit's window: item width $width; front $(front)"
osascript -e 'tell application "System Events" to keystroke "z"' >/dev/null
sleep 0.5
note "F6 typed z: TextEdit text '$(te)'"
shot "$P-F6-screen"
killall TextEdit 2>/dev/null
note "F5/F6 done"
