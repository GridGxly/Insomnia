#!/bin/bash
# PR 104 follow-up: the Edit Apps and hotspot sheets (their buttons need a
# label match), the app on both lists in Edit Apps, and the hotspot sheet
# with 30 tmux panes. t104b.sh REV
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1
note "== PR 104 follow-up, head ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
defaults write com.apple.dock autohide -bool true; killall Dock; sleep 2
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings
note "Edit Apps: $(ax_press_label 'Edit Apps…')"
sleep 1.5
shot_window "104b-head-apps"
note "sheet pop-ups: $(ax_dump | grep -E 'AXPopUpButton' | awk -F'|' '{print $2"="$NF}' | tr '\n' ';')"
note "Done: $(ax_press_label Done)"; sleep 1
note "hotspot: $(ax_press_label 'Set Up…')"
sleep 1.5
shot_window "104b-head-hotspot"
note "Done: $(ax_press_label Done)"; sleep 1
close_window
quit_app
/usr/bin/python3 - "$SUP/config.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
for k in ("agentList", "freezeList"):
    c[k] = [b for b in c.get(k, []) if b != "com.tinyspeck.slackmacgap"] + ["com.tinyspeck.slackmacgap"]
c["tmuxTargets"] = ["work:%d.0" % i for i in range(1, 31)]
json.dump(c, open(p, "w"), indent=2)
PY
note "config.json set by hand: com.tinyspeck.slackmacgap on both agentList and freezeList; 30 tmux targets"
launch_app
open_settings
note "Edit Apps: $(ax_press_label 'Edit Apps…')"; sleep 1.5
note "Edit Apps rules: $(ax_dump | grep -E 'AXPopUpButton|AXStaticText\|(Slack|Terminal)\|' | awk -F'|' '{print $2"="$NF}' | tr '\n' ';')"
shot_window "104b-head-both-lists-apps"
note "Done: $(ax_press_label Done)"; sleep 1
note "hotspot: $(ax_press_label 'Set Up…')"; sleep 1.5
note "expand tmux: $(ax_press AXDisclosureTriangle 'Type "continue" into tmux after an outage')"; sleep 1.5
note "screen: $(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>&1)"
note "window: $(ax 'get size of window 1'); sheet: $(ax 'get size of sheet 1 of window 1' 2>&1)"
note "Done button: $(osascript -l JavaScript -e '
  const se = Application("System Events");
  const w = se.processes.byName("Insomnia").windows[0];
  let out = "none";
  function walk(e, d) {
    if (d > 12) return;
    let r = "", n = "";
    try { r = e.role(); n = e.name() || ""; } catch (x) {}
    if (r === "AXButton" && n === "Done") { try { out = "position " + e.position() + ", size " + e.size(); } catch (x) { out = "found"; } }
    let kids = []; try { kids = e.uiElements(); } catch (x) {}
    for (const k of kids) walk(k, d + 1);
  }
  walk(w, 0); out;' 2>&1)"
screencapture -x "$OUT/104b-head-hotspot-30-tmux-full.png"
shot_window "104b-head-hotspot-30-tmux"
note "Done: $(ax_press_label Done)"; sleep 1
close_window
quit_app
defaults write com.apple.dock autohide -bool false; killall Dock
note "t104b done"
