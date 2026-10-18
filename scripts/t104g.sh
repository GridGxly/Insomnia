#!/bin/bash
# PR 104 rerun after the review fixes. t104g.sh REV LABEL
# config.json set by hand as an older one could have it: Slack on both
# lists, TextEdit (an Apple app) and Docker Desktop only on the freeze list,
# and 30 tmux targets. Then the Settings page, Edit Apps, and the hotspot
# sheet with its tmux list open: its size against the screen, scrolled to
# the bottom, a 31st target added through the Add row, closed with Done.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
DOCKER="$HOME/Applications/Docker.app"
note "== PR 104 rerun, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
defaults write com.apple.dock autohide -bool true; killall Dock; sleep 2
install_rev "$rev" || exit 1
quit_app
# A stand-in Docker Desktop (bundle id com.docker.docker), like the Slack one.
mkdir -p "$DOCKER/Contents/MacOS"
printf '#!/bin/sh\nsleep 600\n' > "$DOCKER/Contents/MacOS/Docker"; chmod +x "$DOCKER/Contents/MacOS/Docker"
cat > "$DOCKER/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.docker.docker</string>
<key>CFBundleName</key><string>Docker</string>
<key>CFBundleExecutable</key><string>Docker</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PL
"$LSREG" -f "$DOCKER"
/usr/bin/python3 - "$SUP/config.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
slack, textedit, docker = "com.tinyspeck.slackmacgap", "com.apple.TextEdit", "com.docker.docker"
c["agentList"] = [b for b in c.get("agentList", []) if b not in (slack, textedit, docker)] + [slack]
c["freezeList"] = [b for b in c.get("freezeList", []) if b not in (slack, textedit, docker)] + [slack, textedit, docker]
c["tmuxTargets"] = ["work:%d.0" % i for i in range(1, 31)]
json.dump(c, open(p, "w"), indent=2)
PY
note "config.json set by hand: Slack on agentList and freezeList; TextEdit and Docker Desktop on freezeList only; 30 tmux targets"
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings; ax 'set position of window 1 to {40, 60}' >/dev/null; sleep 0.6
note "Settings page, app rows: $(ax_dump | grep -A1 -E 'AXStaticText\|(Keep running|Freeze when lid closes)\|' | awk -F'|' '{print $2}' | tr '\n' ';')"
shot_window "104g-$label-page"
note "Edit Apps clicked at: $(click_after 'Freeze when lid closes')"; sleep 2
note "Edit Apps rows (name=rule, enabled): $(osascript -l JavaScript <<'JS' 2>&1
const se = Application("System Events");
const w = se.processes.byName("Insomnia").windows[0];
const out = [];
function walk(e, d) {
  if (d > 18) return;
  let r = ""; try { r = e.role(); } catch (x) {}
  if (r === "AXPopUpButton") {
    let n = "", v = "", en = "";
    try { n = e.name() || e.description() || ""; } catch (x) {}
    try { v = String(e.value()); } catch (x) {}
    try { en = String(e.enabled()); } catch (x) {}
    out.push(n + "=" + v + " (enabled " + en + ")");
  }
  let kids = []; try { kids = e.uiElements(); } catch (x) {}
  for (const k of kids) walk(k, d + 1);
}
walk(w, 0);
out.join("; ");
JS
)"
shot_window "104g-$label-apps"
key 36; sleep 1.2; note "after Return: sheet $(sheet_size)"
note "Set Up clicked at: $(click_after 'Join an iPhone hotspot')"; sleep 2
ss=$(sheet_size)
note "hotspot sheet: $ss"
sp=${ss#position }; sp=${sp%%, size*}; sz=${ss##*size }
sx=${sp%,*} sy=${sp#*,} sh=${sz#*,}
# The disclosure row's chevron, found by role; if not, the place measured
# on the reviewed head (34 pt in, 107 pt above the sheet's bottom edge).
pt=$(osascript -l JavaScript <<'JS' 2>&1
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
if (!hit) { "none"; } else { const p = hit.position(), s = hit.size(); Math.round(p[0] + s[0] / 2) + " " + Math.round(p[1] + s[1] / 2); }
JS
)
case "$pt" in none|*rror*) pt="$((sx + 34)) $((sy + sh - 107))"; note "no disclosure triangle in Accessibility; clicking the measured place $pt" ;; *) note "disclosure triangle at $pt" ;; esac
"$HOME/click" ${pt% *} ${pt#* }
sleep 2
vis=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); const s = $.NSScreen.mainScreen; const f = s.frame, v = s.visibleFrame; f.size.width + "x" + f.size.height + ", visible height " + v.size.height + " (from y " + (f.size.height - v.origin.y - v.size.height) + " to " + (f.size.height - v.origin.y) + ")"' 2>&1)
ss=$(sheet_size)
note "sheet with the tmux list open: $ss; screen $vis"
note "tmux targets in Accessibility: $(ax_dump | grep -c 'work:')"
# pos NAME ROLE: position and size of the first ROLE named NAME, or of the
# first ROLE when NAME is empty.
pos() {
  osascript -l JavaScript - "$1" "$2" <<'JS' 2>&1
function run(argv) {
  const se = Application("System Events");
  const w = se.processes.byName("Insomnia").windows[0];
  let hit = null;
  function walk(e, d) {
    if (hit || d > 18) return;
    let r = "", n = "";
    try { r = e.role(); } catch (x) {}
    try { n = e.name() || e.title() || ""; } catch (x) {}
    if (r === argv[1] && (argv[0] === "" || n === argv[0])) { hit = e; return; }
    let kids = []; try { kids = e.uiElements(); } catch (x) {}
    for (const k of kids) walk(k, d + 1);
  }
  walk(w, 0);
  if (!hit) return "none";
  const p = hit.position(), s = hit.size();
  return p[0] + " " + p[1] + " " + s[0] + " " + s[1];
}
JS
}
onscreen() { # x y w h: yes if the whole rect is inside the 1440x900 screen
  [ "$1" != none ] && [ "$2" -ge 0 ] && [ $(($2 + $4)) -le 900 ] && echo yes || echo no
}
d=$(pos Done AXButton); note "Done button (x y w h): $d; on screen: $(onscreen $d)"
screencapture -x "$OUT/104g-$label-hotspot-open-full.png"
note "sheet scroll to bottom: $(osascript -l JavaScript <<'JS' 2>&1
const se = Application("System Events");
const w = se.processes.byName("Insomnia").windows[0];
let sheet = null;
for (const k of w.uiElements()) { try { if (k.role() === "AXSheet") { sheet = k; break; } } catch (x) {} }
let hit = null;
function walk(e, d) {
  if (hit || d > 12) return;
  let r = "", o = "";
  try { r = e.role(); } catch (x) {}
  if (r === "AXScrollBar") {
    try { o = e.attributes.byName("AXOrientation").value(); } catch (x) {}
    if (o === "AXVerticalOrientation") { hit = e; return; }
  }
  let kids = []; try { kids = e.uiElements(); } catch (x) {}
  for (const k of kids) walk(k, d + 1);
}
if (sheet) walk(sheet, 0);
if (!hit) { "no vertical scroll bar in the sheet"; } else { hit.value = 1; "scrolled"; }
JS
)"
sleep 1.5
f=$(pos "" AXTextField); note "Add row text field (x y w h): $f; on screen: $(onscreen $f)"
note "last target in Accessibility: $(ax_dump | grep -o 'work:[0-9]*\.0' | tail -1)"
screencapture -x "$OUT/104g-$label-hotspot-bottom-full.png"
if [ "$(onscreen $f)" = yes ]; then
  set -- $f
  "$HOME/click" $(($1 + $3 / 2)) $(($2 + $4 / 2)); sleep 0.5
  osascript -e 'tell application "System Events" to keystroke "work:31.0"' >/dev/null; sleep 0.5
  a=$(pos Add AXButton); note "Add button (x y w h): $a"
  if [ "$(onscreen $a)" = yes ]; then set -- $a; "$HOME/click" $(($1 + $3 / 2)) $(($2 + $4 / 2)); sleep 1; fi
  note "tmuxTargets in config.json after Add: $(/usr/bin/python3 -c 'import json,sys; t=json.load(open(sys.argv[1])).get("tmuxTargets", []); print(len(t), "targets, last", t[-1] if t else None)' "$SUP/config.json")"
fi
d=$(pos Done AXButton); note "Done button (x y w h): $d; on screen: $(onscreen $d)"
if [ "$(onscreen $d)" = yes ]; then
  set -- $d; "$HOME/click" $(($1 + $3 / 2)) $(($2 + $4 / 2)); sleep 1.2
  note "after clicking Done: sheet $(sheet_size)"
else
  key 36; sleep 1.2; note "Done not on screen; after Return: sheet $(sheet_size)"
fi
close_window
quit_app
"$LSREG" -u "$DOCKER" 2>/dev/null; rm -rf "$DOCKER"
defaults write com.apple.dock autohide -bool false; killall Dock
note "t104g done"
