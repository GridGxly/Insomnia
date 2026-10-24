#!/bin/bash
# PR 147: Greptile's three fixes in Settings. t147.sh REV LABEL
#   1. Battery: the caption under End the session below, and Never for Low
#      Power Mode turning the end off.
#   2. Edit Apps: Remove Terminal, then Choose… Terminal.app adds it back.
#   3. Hotspot sheet: a save held by the keychain's unlock prompt (the login
#      keychain locked from the desktop session); Escape and Done while it
#      waits, then Cancel on the prompt.
# Starts from default settings (config.json removed) and puts the old file
# back at the end.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
# PARTS=3 runs only the hotspot part, on the installed build.
PARTS=${PARTS:-123}
AXJS="$HOME/lab/ax147.js"
KC="$HOME/Library/Keychains/login.keychain-db"
axj() { osascript -l JavaScript "$AXJS" "$@" 2>&1; }
cfg() { /usr/bin/python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); print(" ".join("%s=%s" % (k, json.dumps(c.get(k))) for k in sys.argv[2:]))' "$SUP/config.json" "$@" 2>&1; }
in_agents() { /usr/bin/python3 -c 'import json,sys; a=json.load(open(sys.argv[1])).get("agentList", []); print("on agentList at %d of %d" % (a.index(sys.argv[2]) + 1, len(a)) if sys.argv[2] in a else "not on agentList (%d apps)" % len(a))' "$SUP/config.json" "$1" 2>&1; }
# gui_run NAME CMD: runs CMD in the desktop session (through Terminal, so
# it sees the session's keychain), waits for it and prints its output.
gui_run() {
  local f="/tmp/gui-$1.command" out="/tmp/gui-$1.out"
  printf '#!/bin/bash\n%s > %s 2>&1\necho "rc $?" >> %s\n' "$2" "$out" "$out" > "$f"
  chmod +x "$f"; rm -f "$out"
  open -g -a Terminal "$f"
  for _ in $(seq 40); do grep -q '^rc ' "$out" 2>/dev/null && break; sleep 0.5; done
  tr '\n' ' ' < "$out"
  # Quit, not an Apple event: those wait on an Automation prompt.
  pkill -x Terminal; sleep 0.5
}
kc_state() { gui_run kcinfo "security show-keychain-info $KC"; }
middle() { echo "$(($1 + $3 / 2)) $(($2 + $4 / 2))"; }
shot_full() { screencapture -x "$OUT/$1.png"; }

note "== PR 147 settings fixes, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
if [ "$PARTS" = 123 ]; then install_rev "$rev" || exit 1; fi
quit_app
[ -f "$SUP/config.json" ] && cp "$SUP/config.json" "$OUT/147-$label-config-saved.json"
rm -f "$SUP/config.json"
note "config.json removed: the app starts from its defaults"
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings; ax 'set position of window 1 to {40, 40}' >/dev/null; sleep 0.6
note "window $(ax 'get size of window 1'); screen $(osascript -l JavaScript -e 'ObjC.import("AppKit"); const s = $.NSScreen.mainScreen; s.frame.size.width + "x" + s.frame.size.height' 2>&1)"

if [[ $PARTS == *1* ]]; then
# 1. Battery
note "-- 1. battery"
note "config.json: $(cfg lowPowerFloor endFloor)"
note "Low Power Mode pop-up: $(axj popup 'Turn on Low Power Mode below')"
note "End pop-up: $(axj popup 'End the session below')"
note "caption on the page: $(axj texts window | tr ';' '\n' | grep -c 'Stays below the Low Power Mode level') match(es)"
shot_window "147-$label-1-battery-before"
note "pick Never for Low Power Mode: $(axj pick 'Turn on Low Power Mode below' Never)"; sleep 1.2
note "config.json: $(cfg lowPowerFloor endFloor)"
note "End pop-up: $(axj popup 'End the session below')"
shot_window "147-$label-1-battery-never"
note "put back 40% and 10%: $(axj pick 'Turn on Low Power Mode below' '40%') $(axj pick 'End the session below' '10%')"; sleep 1
note "config.json: $(cfg lowPowerFloor endFloor)"

fi
if [[ $PARTS == *2* ]]; then
# 2. Edit Apps: Terminal out and back in
note "-- 2. Terminal back with Choose…"
note "Terminal: $(in_agents com.apple.Terminal)"
e=$(axj find window 'Freeze when lid closes' AXButton); note "Edit Apps button (x y w h enabled): $e"
set -- $e; "$HOME/click" $(middle "$1" "$2" "$3" "$4"); sleep 2
note "sheet $(sheet_size)"
note "rows: $(axj rows)"
shot_window "147-$label-2-apps-before"
r=$(axj find sheet Terminal AXButton); note "Terminal's Remove (x y w h enabled): $r"
set -- $r; "$HOME/click" $(middle "$1" "$2" "$3" "$4"); sleep 1.5
note "after Remove: Terminal $(in_agents com.apple.Terminal); rows: $(axj rows)"
note "Add App menu, Choose…: $(axj menu sheet 'Add App' 'Choose…')"; sleep 2.5
note "windows: $(ax 'get name of every window' 2>&1)"
shot_full "147-$label-2-open-panel"
osascript -e 'tell application "System Events" to keystroke "g" using {command down, shift down}' >/dev/null; sleep 1.2
osascript -e 'tell application "System Events" to keystroke "/System/Applications/Utilities/Terminal.app"' >/dev/null; sleep 1
key 36; sleep 1.5
shot_full "147-$label-2-open-panel-terminal"
key 36; sleep 2.5
note "after Open: windows $(ax 'get name of every window' 2>&1)"
note "Terminal $(in_agents com.apple.Terminal)"
note "rows: $(axj rows)"
shot_window "147-$label-2-apps-after"
key 36; sleep 1.2; note "after Return: sheet $(sheet_size)"
note "Settings page: $(axj texts window | tr ';' '\n' | grep -i -m2 -E 'Terminal|None on this Mac' | tr '\n' ';')"

fi
if [[ $PARTS == *3* ]]; then
# 3. Hotspot sheet while a save waits on the keychain
note "-- 3. hotspot save held by the keychain prompt"
h=$(axj find window 'Join an iPhone hotspot' AXButton); note "Set Up button (x y w h enabled): $h"
set -- $h; "$HOME/click" $(middle "$1" "$2" "$3" "$4"); sleep 2
note "sheet $(sheet_size)"
note "keychain before: $(kc_state)"
note "lock the login keychain in the desktop session: $(gui_run kclock "security lock-keychain $KC")"
osascript -e 'tell application "System Events" to set frontmost of process "Insomnia" to true' >/dev/null; sleep 0.8
note "front app: $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1); sheet $(sheet_size)"
note "password field (x y w h enabled subrole): $(axj field sheet Password)"
osascript -e 'tell application "System Events" to keystroke "lab-password-147"' >/dev/null; sleep 0.6
note "hotspot name in config.json: $(cfg hotspotSSID)"
note "buttons before saving: $(axj buttons sheet)"
m=$(log_mark)
key 36; sleep 3
note "buttons while waiting: $(axj buttons sheet)"
note "prompt: $(osascript -e 'tell application "System Events" to get value of every static text of window 1 of process "SecurityAgent"' 2>&1 | cut -c1-200)"
note "SecurityAgent: $(pgrep -x SecurityAgent >/dev/null && echo running || echo 'not running'); its windows: $(osascript -e 'tell application "System Events" to get name of every window of process "SecurityAgent"' 2>&1)"
note "while waiting, Done (x y w h enabled): $(axj button sheet Done)"
note "sheet texts: $(axj texts sheet | tr ';' '\n' | grep -E 'Sav|Could not' | tr '\n' ';')"
shot_full "147-$label-3-waiting"
# Escape with Insomnia in front.
osascript -e 'tell application "System Events" to set frontmost of process "Insomnia" to true' >/dev/null; sleep 0.8
# A real click on the sheet's top edge (no control there) makes Insomnia
# active and the sheet key, so Escape goes to the sheet.
ss=$(sheet_size); sx=${ss#position }; sx=${sx%%,*}; sy=${ss#position *,}; sy=${sy%%, size*}
note "click the sheet at $((sx + 40)) $((sy + 12))"; "$HOME/click" $((sx + 40)) $((sy + 12)); sleep 0.8
note "front app: $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1)"
key 53; sleep 1.2
note "after Escape: sheet $(sheet_size); SecurityAgent windows: $(osascript -e 'tell application "System Events" to get name of every window of process "SecurityAgent"' 2>&1)"
d=$(axj button sheet Done); note "Done (x y w h enabled): $d"
if [ "${d%% *}" != none ] && [ "${d#error}" = "$d" ]; then set -- $d; "$HOME/click" $(middle "$1" "$2" "$3" "$4"); sleep 1.5; fi
note "after clicking Done: sheet $(sheet_size)"
shot_full "147-$label-3-after-done-click"
# Cancel the prompt.
c=$(osascript -e 'tell application "System Events" to tell process "SecurityAgent" to click button "Cancel" of window 1' 2>&1)
note "Cancel on the prompt: ${c:-ok}"; sleep 2.5
if pgrep -x SecurityAgent >/dev/null && osascript -e 'tell application "System Events" to get name of every window of process "SecurityAgent"' 2>/dev/null | grep -q .; then
  osascript -e 'tell application "System Events" to set frontmost of process "SecurityAgent" to true' >/dev/null 2>&1; sleep 0.5; key 53; sleep 2
  note "prompt still up; after Escape on it: windows $(osascript -e 'tell application "System Events" to get name of every window of process "SecurityAgent"' 2>&1)"
fi
note "log since the save: $(log_since "$m" | grep -i -E 'hotspot|keychain' | cut -c1-160 | tr '\n' ';')"
note "sheet $(sheet_size)"
note "sheet notice: $(axj texts sheet 2>&1 | tr ';' '\n' | grep -E 'Could not|Saving' | tr '\n' ';')"
note "page notice: $(axj texts window 2>&1 | tr ';' '\n' | grep -E 'Could not' | tr '\n' ';')"
note "Done (x y w h enabled): $(axj button sheet Done)"
shot_full "147-$label-3-after-cancel"
# Escape again, with no save waiting: whether Escape closes this sheet at all.
ss=$(sheet_size)
if [ "$ss" != none ]; then
  sx=${ss#position }; sx=${sx%%,*}; sy=${ss#position *,}; sy=${sy%%, size*}
  "$HOME/click" $((sx + 40)) $((sy + 12)); sleep 0.8
  note "no save waiting; front app: $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1)"
  key 53; sleep 1.2
  note "after Escape with no save waiting: sheet $(sheet_size)"
fi
note "unlock the login keychain: $(gui_run kcunlock "security unlock-keychain -p \"$LAB_KEYCHAIN_PASSWORD\" $KC")"
note "keychain now: $(kc_state)"
if [ "$(sheet_size)" != none ]; then key 36; sleep 1.2; note "after Return: sheet $(sheet_size)"; fi
close_window
quit_app
rm -f "$SUP/config.json"
[ -f "$OUT/147-$label-config-saved.json" ] && cp "$OUT/147-$label-config-saved.json" "$SUP/config.json"
fi
note "t147 done ($label)"
