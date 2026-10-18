#!/bin/bash
# PR 104 follow-up: Edit Apps and the hotspot sheet, opened by clicking the
# buttons by position (they have no accessible name), closed with Return
# (Done is the confirmation action). Then an app on both lists, and the
# hotspot sheet with 30 tmux panes and its tmux list expanded. t104c.sh REV
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1
note "== PR 104 follow-up, head ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
defaults write com.apple.dock autohide -bool true; killall Dock; sleep 2
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
settings() { open_settings; ax 'set position of window 1 to {40, 60}' >/dev/null; sleep 0.6; }
settings
note "Edit Apps clicked at: $(click_after 'Freeze when lid closes')"; sleep 2
note "sheet: $(sheet_size)"
note "sheet pop-ups: $(ax_dump | grep -E 'AXPopUpButton' | awk -F'|' '{print $2"="$NF}' | tr '\n' ';')"
shot_window "104c-head-apps"
key 36; sleep 1.2; note "after Return: sheet $(sheet_size)"
note "Set Up clicked at: $(click_after 'Join an iPhone hotspot')"; sleep 2
note "sheet: $(sheet_size)"
shot_window "104c-head-hotspot"
key 36; sleep 1.2; note "after Return: sheet $(sheet_size)"
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
settings
note "Edit Apps clicked at: $(click_after 'Freeze when lid closes')"; sleep 2
note "Edit Apps pop-ups: $(ax_dump | grep -E 'AXPopUpButton' | awk -F'|' '{print $2"="$NF}' | tr '\n' ';')"
note "Edit Apps texts: $(ax_dump | grep -E 'AXStaticText\|(Slack|Terminal)' | awk -F'|' '{print $2}' | tr '\n' ';')"
shot_window "104c-head-both-lists-apps"
key 36; sleep 1.2; note "after Return: sheet $(sheet_size)"
note "Set Up clicked at: $(click_after 'Join an iPhone hotspot')"; sleep 2
note "sheet before expanding: $(sheet_size)"
note "tmux list expanded: $(osascript -l JavaScript <<'JS' 2>&1
const se = Application("System Events");
const w = se.processes.byName("Insomnia").windows[0];
let hit = null;
function walk(e, d) {
  if (hit || d > 18) return;
  let r = ""; try { r = e.role(); } catch (x) {}
  if (r === "AXDisclosureTriangle") { hit = e; return; }
  let kids = []; try { kids = e.uiElements(); } catch (x) {}
  for (const k of kids) walk(k, d + 1);
}
walk(w, 0);
if (!hit) { "none"; } else { try { hit.actions.byName("AXPress").perform(); "pressed"; } catch (x) { se.click(hit); "clicked"; } }
JS
)"
sleep 2
note "sheet after expanding: $(sheet_size); screen 1440x900"
note "tmux targets shown: $(ax_dump | grep -c 'work:')"
screencapture -x "$OUT/104c-head-hotspot-30-tmux-full.png"
key 36; sleep 1.2; note "after Return: sheet $(sheet_size)"
close_window
quit_app
defaults write com.apple.dock autohide -bool false; killall Dock
note "t104c done"
