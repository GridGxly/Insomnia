#!/bin/bash
# PR 104 rerun, the hotspot sheet with 30 tmux targets. t104h.sh REV LABEL
# t104g.sh clicked the middle of the disclosure row, which does not open it,
# and looked for buttons by name, which these have none of. This one clicks
# the row's chevron end (26 pt in, where t104f.sh clicked), takes the sheet's
# Done and Add buttons by their place in the Accessibility tree, scrolls the
# sheet with its scroll bar, adds a 31st target and closes with Done.
# The Dock is hidden, as in t104f.sh; DOCK=shown t104h.sh ... keeps it.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
note "== PR 104 rerun, hotspot sheet, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
if [ "${DOCK:-}" = shown ]; then dock="Dock shown"; else dock="Dock hidden"; defaults write com.apple.dock autohide -bool true; killall Dock; sleep 2; fi
install_rev "$rev" || exit 1
quit_app
/usr/bin/python3 - "$SUP/config.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["tmuxTargets"] = ["work:%d.0" % i for i in range(1, 31)]
json.dump(c, open(p, "w"), indent=2)
PY
note "config.json: 30 tmux targets, work:1.0 to work:30.0"
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings; ax 'set position of window 1 to {40, 60}' >/dev/null; sleep 0.6
note "Set Up clicked at: $(click_after 'Join an iPhone hotspot')"; sleep 2
note "hotspot sheet, tmux list closed: $(sheet_size)"
# sfind WHAT: x y w h of a sheet element. WHAT is triangle (the disclosure
# row), done (the last button outside the scroll area), field (the Pane
# text field), add (the button after it), scroll (set the sheet's vertical
# scroll bar to 1), or count (tmux target rows built in Accessibility).
sfind() {
  osascript -l JavaScript - "$1" <<'JS' 2>&1
function run(argv) {
  const se = Application("System Events");
  const w = se.processes.byName("Insomnia").windows[0];
  let sheet = null;
  for (const k of w.uiElements()) { try { if (k.role() === "AXSheet") { sheet = k; break; } } catch (x) {} }
  if (!sheet) return "none";
  const flat = [];
  function walk(e, d) {
    if (d > 20) return;
    let r = "", n = "", ds = "", o = "";
    try { r = e.role(); } catch (x) {}
    try { n = e.name() || ""; } catch (x) {}
    try { ds = e.description() || ""; } catch (x) {}
    if (r === "AXScrollBar") { try { o = e.attributes.byName("AXOrientation").value(); } catch (x) {} }
    flat.push({ e: e, r: r, n: n, ds: ds, o: o, d: d });
    let kids = []; try { kids = e.uiElements(); } catch (x) {}
    for (const k of kids) walk(k, d + 1);
  }
  walk(sheet, 0);
  const frame = f => { const p = f.e.position(), s = f.e.size(); return p[0] + " " + p[1] + " " + s[0] + " " + s[1]; };
  const want = argv[0];
  if (want === "count") return String(flat.filter(f => f.r === "AXStaticText" && /^work:\d+\.0$/.test(f.n)).length);
  if (want === "triangle") { const f = flat.find(f => f.r === "AXDisclosureTriangle"); return f ? frame(f) : "none"; }
  if (want === "done") { const g = flat.filter(f => f.r === "AXButton" && f.d === 2); return g.length ? frame(g[g.length - 1]) : "none"; }
  const i = flat.findIndex(f => f.r === "AXTextField" && f.ds === "Pane");
  if (want === "field") return i < 0 ? "none" : frame(flat[i]);
  if (want === "add") { const f = i < 0 ? null : flat.slice(i + 1).find(f => f.r === "AXButton"); return f ? frame(f) : "none"; }
  if (want === "scroll") { const f = flat.find(f => f.r === "AXScrollBar" && f.o === "AXVerticalOrientation"); if (!f) return "no vertical scroll bar"; f.e.value = 1; return "scroll bar set to 1"; }
  return "none";
}
JS
}
# onscreen x y w h: yes if the whole rect is inside the screen's visible area.
vtop=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); const s = $.NSScreen.mainScreen; s.frame.size.height - s.visibleFrame.origin.y - s.visibleFrame.size.height' 2>&1)
vbot=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); const s = $.NSScreen.mainScreen; s.frame.size.height - s.visibleFrame.origin.y' 2>&1)
onscreen() { [ "$1" != none ] && [ "$#" -eq 4 ] && [ "$2" -ge "$vtop" ] && [ $(($2 + $4)) -le "$vbot" ] && echo yes || echo no; }
middle() { echo "$(($1 + $3 / 2)) $(($2 + $4 / 2))"; }
# shot_sheet NAME: the Settings window and its sheet, cropped to both.
shot_sheet() {
  local s w h ss sy sh bottom
  s=$(ax 'get size of window 1' | tr -d ' '); w=${s%,*} h=${s#*,}
  ss=$(sheet_size); sy=${ss#position *,}; sy=${sy%%, size*}; sh=${ss##*,}
  bottom=$((60 + h)); [ "$ss" != none ] && [ $((sy + sh)) -gt "$bottom" ] && bottom=$((sy + sh))
  screencapture -x -R"30,50,$((w + 20)),$((bottom - 40))" "$OUT/$1.png"
}
note "screen: $(osascript -l JavaScript -e 'ObjC.import("AppKit"); const s = $.NSScreen.mainScreen; s.frame.size.width + "x" + s.frame.size.height' 2>&1), visible from y $vtop to y $vbot ($dock)"
t=$(sfind triangle); note "disclosure row (x y w h): $t"
if [ "$t" != none ]; then set -- $t; "$HOME/click" $(($1 + 26)) $(($2 + $4 / 2)); note "clicked the chevron at $(($1 + 26)) $(($2 + $4 / 2))"; sleep 2; fi
ss=$(sheet_size); sy=${ss#position *,}; sy=${sy%%, size*}; sh=${ss##*,}
note "hotspot sheet, tmux list open: $ss; bottom edge at y $((sy + sh)); on screen: $( [ "$sy" -ge "$vtop" ] && [ $((sy + sh)) -le "$vbot" ] && echo yes || echo no)"
note "tmux target rows in Accessibility: $(sfind count)"
d=$(sfind done); note "Done (x y w h): $d; on screen: $(onscreen $d)"
shot_sheet "104h-$label${DOCK:+-dock}-open"
note "$(sfind scroll)"; sleep 1.5
f=$(sfind field); note "after scrolling, Pane field (x y w h): $f; on screen: $(onscreen $f)"
a=$(sfind add); note "Add (x y w h): $a; on screen: $(onscreen $a)"
shot_sheet "104h-$label${DOCK:+-dock}-bottom"
if [ "$(onscreen $f)" = yes ] && [ "$(onscreen $a)" = yes ]; then
  "$HOME/click" $(middle $f); sleep 0.6
  osascript -e 'tell application "System Events" to keystroke "work:31.0"' >/dev/null; sleep 0.6
  "$HOME/click" $(middle $a); sleep 1.5
  note "after Add: tmux target rows in Accessibility $(sfind count); config.json $(/usr/bin/python3 -c 'import json,sys; t=json.load(open(sys.argv[1])).get("tmuxTargets", []); print(len(t), "targets, last", t[-1] if t else None)' "$SUP/config.json")"
  shot_sheet "104h-$label${DOCK:+-dock}-added"
fi
d=$(sfind done); note "Done (x y w h): $d; on screen: $(onscreen $d)"
if [ "$(onscreen $d)" = yes ]; then
  "$HOME/click" $(middle $d); sleep 1.5
  note "after clicking Done: sheet $(sheet_size)"
else
  key 36; sleep 1.5; note "Done not on screen; after Return: sheet $(sheet_size)"
fi
note "tmuxTargets in config.json at the end: $(/usr/bin/python3 -c 'import json,sys; t=json.load(open(sys.argv[1])).get("tmuxTargets", []); print(len(t))' "$SUP/config.json")"
close_window
quit_app
defaults write com.apple.dock autohide -bool false; killall Dock
note "t104h done"
