# Helpers for the PR 145 run, sourced after lib.sh and axlib.sh.
P=145
# Sets left, width and rx (the end ring's x) from the status item.
geom() {
  local pos size
  pos=$(ax 'get position of menu bar item 1 of menu bar 2' | tr -d ' ')
  size=$(ax 'get size of menu bar item 1 of menu bar 2' | tr -d ' ')
  left=${pos%,*} width=${size%,*}
  rx=$((left + width - 12))
}
# What the bar reads from the status item to the clock, by OCR of a 4x crop.
bar_text() {
  geom
  local w=$((1440 - left + 4))
  screencapture -x -R"$((left - 4)),0,$w,30" /tmp/bar.png
  sips -z 120 $((w * 4)) /tmp/bar.png --out /tmp/bar4.png >/dev/null
  "$HOME/ocr" --fast /tmp/bar4.png 2>/dev/null | grep -v IOService | cut -f2
}
in_session() { [ -e "$SUP/session.json" ]; }
sess() { if in_session; then echo "session.json present"; else echo "session.json absent"; fi; }
front() { osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1; }
# Ends a running session from the menu.
end_any() {
  if in_session && [ -n "$(app_pid)" ]; then
    open_menu; menu_click "End session"; sleep 5
  fi
  key 53
}
# Quits, puts back the pristine config.json plus the JSON keys given, launches.
fresh_launch() {
  end_any; quit_app
  cp "$HOME/config.pristine.json" "$SUP/config.json"
  if [ -n "${1:-}" ]; then
    /usr/bin/python3 - "$SUP/config.json" "$1" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c.update(json.loads(sys.argv[2]))
json.dump(c, open(p, "w"), indent=2)
PY
  fi
  launch_app; bash ~/lab/clearnc.sh >/dev/null
  note "launched pid $(app_pid) with config.json pristine${1:+ plus $1}"
}
# Starts a session (minutes typed into Minutes if given) and waits for the log.
begin() {
  local m
  m=$(log_mark)
  start_session "${1:-}"
  if wait_log "$m" 'session started until' 30; then
    note "session started: $(log_since "$m" | grep -m1 'session started until' | cut -c1-120)"
    sleep 2
    return 0
  fi
  note "no session start in the log: $(log_since "$m" | tr '\n' ' ' | cut -c1-300)"
  return 1
}
# The epoch second the running session ends, from its start line.
ends_at() {
  local iso
  iso=$(grep 'session started until' "$LOG" | tail -1 | sed -E 's/.*until ([0-9T:-]+Z).*/\1/')
  date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$iso" +%s
}
# ax_pick POPUP ITEM: opens the pop-up button POPUP in the front window and
# presses its menu item ITEM. Prints ok or what was missing.
ax_pick() {
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
    if (r === "AXPopUpButton" && (n === argv[0] || ds === argv[0])) { hit = e; return; }
    let kids = [];
    try { kids = e.uiElements(); } catch (x) {}
    for (const k of kids) walk(k, d + 1);
  }
  walk(w, 0);
  if (!hit) return "no pop-up " + argv[0];
  hit.actions.byName("AXPress").perform();
  delay(0.6);
  for (const m of hit.uiElements()) {
    let items = [];
    try { items = m.uiElements(); } catch (x) {}
    for (const it of items) {
      let n = "";
      try { n = it.name() || ""; } catch (x) {}
      if (n === argv[1]) { it.actions.byName("AXPress").perform(); return "ok"; }
    }
  }
  return "no item " + argv[1];
}
JS
}
popup_value() { ax_dump | grep -E "AXPopUpButton\|$1" | awk -F'|' '{print $NF}'; }
