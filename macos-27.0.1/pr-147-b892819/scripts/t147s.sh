#!/bin/bash
# PR 147 smoke: t147s.sh REV LABEL
#   1. The whole Settings page, top to bottom.
#   2. Edit Apps moves Slack from Freeze to Keep running and back.
#   3. During a session, Countdown and "Show the countdown in the menu bar"
#      change the menu bar at once.
# Starts from default settings (config.json removed) and puts the old file
# back at the end.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"; source "$HOME/lab/t145lib.sh"
rev=$1 label=$2
AXJS="$HOME/lab/ax147.js"
SLACK=com.tinyspeck.slackmacgap
axj() { osascript -l JavaScript "$AXJS" "$@" 2>&1; }
cfg() { /usr/bin/python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); print(" ".join("%s=%s" % (k, json.dumps(c.get(k))) for k in sys.argv[2:]))' "$SUP/config.json" "$@" 2>&1; }
lists() { /usr/bin/python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); i=sys.argv[2]; print("agentList %s, freezeList %s" % (i in c.get("agentList", []), i in c.get("freezeList", [])))' "$SUP/config.json" "$1" 2>&1; }
middle() { echo "$(($1 + $3 / 2)) $(($2 + $4 / 2))"; }
click_frame() { set -- $1; "$HOME/click" $(middle "$1" "$2" "$3" "$4"); }

note "== PR 147 smoke, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
end_any; quit_app
install_rev "$rev" || exit 1
[ -f "$SUP/config.json" ] && cp "$SUP/config.json" "$OUT/147s-$label-config-saved.json"
rm -f "$SUP/config.json"
note "config.json removed: the app starts from its defaults"
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings; ax 'set position of window 1 to {40, 40}' >/dev/null; sleep 0.6

# 1. The page
note "-- 1. the page"
: > /tmp/147s-texts
for f in 0 0.5 1; do
  note "scroll $f: $(scroll_settings "$f")"; sleep 1
  axj texts window | tr ';' '\n' | sed 's/^ *//; s/ *$//' >> /tmp/147s-texts
  shot_window "147s-$label-1-page-$f"
done
for t in "When the lid closes" "Apps" "Battery" "If Wi-Fi drops" "General"; do
  note "heading \"$t\": $(axj where window "$t")"
done
for t in "Keep running" "Freeze when lid closes" "Join an iPhone hotspot" "Default session length" "Default field" \
  "Countdown" "Show the countdown in the menu bar" "Open at login" "Version"; do
  note "text \"$t\": $(grep -c -x -F "$t" /tmp/147s-texts) of 3 scroll positions"
done
note "version row: $(grep -A1 -x -F Version /tmp/147s-texts | tail -1)"
note "General pop-ups: $(axj popup 'Default session length') / $(axj popup 'Countdown')"

# 2. Edit Apps
note "-- 2. Edit Apps: Slack between Freeze and Keep running"
scroll_settings 0 >/dev/null; sleep 0.8
note "Slack before: $(lists $SLACK)"
e=$(axj find window 'Freeze when lid closes' AXButton); note "Edit Apps button (x y w h enabled): $e"
click_frame "$e"; sleep 2
note "sheet $(sheet_size); rows: $(axj rows | cut -c1-120)"
note "Slack to Keep running: $(axj pickafter sheet Slack 'Keep running')"; sleep 1.5
note "Slack: $(lists $SLACK); rows: $(axj rows | cut -c1-120)"
shot_window "147s-$label-2-apps-slack-keep"
note "Slack back to Freeze: $(axj pickafter sheet Slack 'Freeze when lid closes')"; sleep 1.5
note "Slack: $(lists $SLACK); rows: $(axj rows | cut -c1-120)"
key 36; sleep 1.2; note "after Return: sheet $(sheet_size)"

# 3. Countdown during a session
note "-- 3. Countdown and the menu bar countdown during a session"
note "config.json: $(cfg countdownStyle showMenuBarCountdown)"
begin || { note "no session; stopping"; exit 1; }
geom; note "status item width $width; bar: $(bar_text | tr '\n' ' ')"
shot_menubar "147s-$label-3-bar-time-left"
open_settings; scroll_settings 1 >/dev/null; sleep 1
note "pick End time: $(axj pick 'Countdown' 'End time')"; sleep 2
note "config.json: $(cfg countdownStyle)"
note "session ends at $(date -r "$(ends_at)" +%H:%M) (VM clock)"
geom; note "status item width $width; bar: $(bar_text | tr '\n' ' ')"
shot_menubar "147s-$label-3-bar-end-time"
t=$(axj toggle window 'Show the countdown in the menu bar'); note "menu bar countdown switch (x y w h enabled value): $t"
click_frame "$t"; sleep 2
note "config.json: $(cfg showMenuBarCountdown)"
geom; note "status item width $width; bar: $(bar_text | tr '\n' ' ')"
shot_menubar "147s-$label-3-bar-off"
shot_window "147s-$label-3-settings-off"
t=$(axj toggle window 'Show the countdown in the menu bar'); click_frame "$t"; sleep 2
note "switch back on: $(cfg showMenuBarCountdown); status item width $(geom; echo "$width")"
note "pick Time left: $(axj pick 'Countdown' 'Time left')"; sleep 2
geom; note "status item width $width; bar: $(bar_text | tr '\n' ' ')"
end_any; note "after End session: $(sess)"
close_window
quit_app
rm -f "$SUP/config.json"
[ -f "$OUT/147s-$label-config-saved.json" ] && cp "$OUT/147s-$label-config-saved.json" "$SUP/config.json"
note "t147s done ($label)"
