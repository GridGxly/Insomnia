# Accessibility helpers for the Settings window, added to the lab helpers.
ax() { osascript -e "tell application \"System Events\" to tell process \"Insomnia\" to $1" 2>&1; }
open_menu() {
  local x
  x=$(eye_x)
  "$HOME/click" right $((x + 16)) 15
  sleep 1.2
}
menu_click() { ax "click menu item \"$1\" of menu 1 of menu bar item 1 of menu bar 2" >/dev/null; }
menu_names() { ax 'get name of menu items of menu 1 of menu bar item 1 of menu bar 2'; }
open_settings() {
  open_menu
  menu_click "Settings…"
  sleep 2
}
# Lists "role|name|description|value" for every element of the front window.
ax_dump() {
  osascript -l JavaScript -e '
    const se = Application("System Events");
    const p = se.processes.byName("Insomnia");
    const w = p.windows[0];
    const out = [];
    function walk(e, d) {
      if (d > 14) return;
      let r = "", n = "", ds = "", v = "";
      try { r = e.role(); } catch (x) {}
      try { n = e.name() || ""; } catch (x) {}
      try { ds = e.description() || ""; } catch (x) {}
      try { v = String(e.value()); } catch (x) {}
      if (n || ds || (v && v !== "null")) out.push("  ".repeat(d) + r + "|" + n + "|" + ds + "|" + v.slice(0, 60));
      let kids = [];
      try { kids = e.uiElements(); } catch (x) {}
      for (const k of kids) walk(k, d + 1);
    }
    walk(w, 0);
    out.join("\n");' 2>&1
}
# ax_press ROLE NAME [N]: presses the Nth (default 1st) element of the front
# window with that role whose name or description is NAME. Prints ok or none.
ax_press() {
  osascript -l JavaScript - "$1" "$2" "${3:-1}" <<'JS' 2>&1
function run(argv) {
  const [role, name, nth] = [argv[0], argv[1], Number(argv[2])];
  const se = Application("System Events");
  const w = se.processes.byName("Insomnia").windows[0];
  let seen = 0, hit = null;
  function walk(e, d) {
    if (hit || d > 16) return;
    let r = "", n = "", ds = "";
    try { r = e.role(); } catch (x) {}
    try { n = e.name() || ""; } catch (x) {}
    try { ds = e.description() || ""; } catch (x) {}
    if (r === role && (n === name || ds === name)) { seen++; if (seen === nth) { hit = e; return; } }
    let kids = [];
    try { kids = e.uiElements(); } catch (x) {}
    for (const k of kids) walk(k, d + 1);
  }
  walk(w, 0);
  if (!hit) return "none";
  try { hit.actions.byName("AXScrollToVisible").perform(); } catch (x) {}
  try { hit.actions.byName("AXPress").perform(); } catch (x) { se.click(hit); }
  return "ok";
}
JS
}
# Controls only: buttons, pop-ups, switches, fields, headings, and their values.
ax_controls() { ax_dump | grep -E 'AXButton\|[^|]|AXPopUpButton|AXCheckBox|AXTextField|AXMenuButton|AXHeading\|[^|]|AXRadio|AXSlider|AXSheet'; }
close_window() { ax 'click (first button of window 1 whose subrole is "AXCloseButton")' >/dev/null; sleep 1; }
# Scrolls an element into view without pressing it.
ax_reveal() {
  osascript -l JavaScript - "$1" "$2" <<'JS' 2>&1
function run(argv) {
  const se = Application("System Events");
  const w = se.processes.byName("Insomnia").windows[0];
  let hit = null;
  function walk(e, d) {
    if (hit || d > 16) return;
    let r = "", n = "", ds = "";
    try { r = e.role(); } catch (x) {}
    try { n = e.name() || ""; } catch (x) {}
    try { ds = e.description() || ""; } catch (x) {}
    if (r === argv[0] && (n === argv[1] || ds === argv[1])) { hit = e; return; }
    let kids = [];
    try { kids = e.uiElements(); } catch (x) {}
    for (const k of kids) walk(k, d + 1);
  }
  walk(w, 0);
  if (!hit) return "none";
  try { hit.actions.byName("AXScrollToVisible").perform(); } catch (x) {}
  return "ok";
}
JS
}
# The front window, moved to the top left, captured with a margin.
shot_window() {
  ax 'set position of window 1 to {40, 60}' >/dev/null
  sleep 0.6
  local s w h
  s=$(ax 'get size of window 1' | tr -d ' ')
  w=${s%,*} h=${s#*,}
  screencapture -x -R"30,50,$((w + 20)),$((h + 20))" "$OUT/$1.png"
}
shot_rect() { screencapture -x -R"$2,$3,$4,$5" "$OUT/$1.png"; }
# The right half of the menu bar, with any open status menu below it.
shot_menubar() { shot_rect "$1" 640 0 800 "${2:-34}"; }
# Text values in the front window that match a pattern.
ax_texts() { ax_dump | grep -E 'AXStaticText' | awk -F'|' '{print $2}' | grep -E "$1"; }
config_get() { /usr/bin/python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); print(json.dumps(c.get(sys.argv[2], "(absent)")))' "$SUP/config.json" "$1" 2>&1; }
# scroll_settings FRACTION: sets the Settings window's vertical scroll bar
# (0 top, 1 bottom). SwiftUI forms only build the rows on screen, so a row
# must be scrolled into view before it can be found.
scroll_settings() {
  osascript -l JavaScript - "$1" <<'JS' 2>&1
function run(argv) {
  const se = Application("System Events");
  const w = se.processes.byName("Insomnia").windows[0];
  let hit = null;
  function walk(e, d) {
    if (hit || d > 10) return;
    let r = "", o = "";
    try { r = e.role(); } catch (x) {}
    if (r === "AXScrollBar") {
      try { o = e.attributes.byName("AXOrientation").value(); } catch (x) {}
      if (o === "AXVerticalOrientation") { hit = e; return; }
    }
    let kids = [];
    try { kids = e.uiElements(); } catch (x) {}
    for (const k of kids) walk(k, d + 1);
  }
  walk(w, 0);
  if (!hit) return "none";
  hit.value = Number(argv[0]);
  return "ok";
}
JS
}
# ax_press_label LABEL: presses the first button whose name, description,
# title or a child text is LABEL. Prints ok or none.
ax_press_label() {
  osascript -l JavaScript - "$1" <<'JS' 2>&1
function run(argv) {
  const want = argv[0];
  const se = Application("System Events");
  const w = se.processes.byName("Insomnia").windows[0];
  let hit = null;
  function label(e) {
    const out = [];
    try { out.push(e.name() || ""); } catch (x) {}
    try { out.push(e.description() || ""); } catch (x) {}
    try { out.push(e.title() || ""); } catch (x) {}
    try { for (const k of e.uiElements()) { try { out.push(String(k.value())); } catch (x) {} try { out.push(k.name() || ""); } catch (x) {} } } catch (x) {}
    return out;
  }
  function walk(e, d) {
    if (hit || d > 16) return;
    let r = "";
    try { r = e.role(); } catch (x) {}
    if (r === "AXButton" && label(e).indexOf(want) >= 0) { hit = e; return; }
    let kids = [];
    try { kids = e.uiElements(); } catch (x) {}
    for (const k of kids) walk(k, d + 1);
  }
  walk(w, 0);
  if (!hit) return "none";
  try { hit.actions.byName("AXPress").perform(); } catch (x) { se.click(hit); }
  return "ok";
}
JS
}
# click_after TEXT [ROLE]: clicks the center of the first ROLE (default
# AXButton) that follows, in Accessibility order, the first element whose
# name or value is TEXT. For buttons with no accessible name. Prints the
# point clicked, or none.
click_after() {
  local pt
  pt=$(osascript -l JavaScript - "$1" "${2:-AXButton}" <<'JS' 2>&1
function run(argv) {
  const se = Application("System Events");
  const w = se.processes.byName("Insomnia").windows[0];
  const flat = [];
  function walk(e, d) {
    if (d > 18) return;
    let r = "", n = "", v = "";
    try { r = e.role(); } catch (x) {}
    try { n = e.name() || ""; } catch (x) {}
    try { v = String(e.value()); } catch (x) {}
    flat.push([e, r, n, v]);
    let kids = []; try { kids = e.uiElements(); } catch (x) {}
    for (const k of kids) walk(k, d + 1);
  }
  walk(w, 0);
  const i = flat.findIndex(f => f[2] === argv[0] || f[3] === argv[0]);
  if (i < 0) return "none";
  const hit = flat.slice(i + 1).find(f => f[1] === argv[1]);
  if (!hit) return "none";
  const p = hit[0].position(), s = hit[0].size();
  return Math.round(p[0] + s[0] / 2) + " " + Math.round(p[1] + s[1] / 2);
}
JS
)
  case "$pt" in
    none|*error*) echo "none ($pt)"; return 1 ;;
  esac
  "$HOME/click" ${pt% *} ${pt#* }
  echo "$pt"
}
# sheet_size: the size of the front window's sheet, or none.
sheet_size() {
  osascript -l JavaScript <<'JS' 2>&1
const se = Application("System Events");
const w = se.processes.byName("Insomnia").windows[0];
let out = "none";
for (const k of w.uiElements()) { try { if (k.role() === "AXSheet") { out = "position " + k.position().join(",") + ", size " + k.size().join(","); break; } } catch (x) {} }
out;
JS
}
