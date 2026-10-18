#!/bin/bash
# PR 117 follow-up: the Check for updates button has no accessible name, so
# find the buttons after the Version row and click them by position.
# t117c.sh REV
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1
note "== PR 117 follow-up, head ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings
ax 'set position of window 1 to {40, 60}' >/dev/null; sleep 0.6
note "scroll: $(scroll_settings 1)"; sleep 1.5
after_version() {
  osascript -l JavaScript <<'JS' 2>&1
const se = Application("System Events");
const w = se.processes.byName("Insomnia").windows[0];
const flat = [];
function walk(e, d) {
  if (d > 16) return;
  let r = "", n = "", ds = "", v = "", p = null, s = null;
  try { r = e.role(); } catch (x) {}
  try { n = e.name() || ""; } catch (x) {}
  try { ds = e.description() || ""; } catch (x) {}
  try { v = String(e.value()); } catch (x) {}
  try { p = e.position(); s = e.size(); } catch (x) {}
  flat.push([r, n, ds, v, p, s]);
  let kids = []; try { kids = e.uiElements(); } catch (x) {}
  for (const k of kids) walk(k, d + 1);
}
walk(w, 0);
let i = flat.findIndex(f => f[0] === "AXStaticText" && f[1] === "Version");
flat.slice(i, i + 12).map(f => f[0] + "|" + f[1] + "|" + f[2] + "|" + f[3].slice(0, 50) + "|" + (f[4] ? f[4].join(",") : "") + "|" + (f[5] ? f[5].join(",") : "")).join("\n");
JS
}
rows=$(after_version)
echo "$rows" | sed 's/^/    /'
btn=$(echo "$rows" | awk -F'|' '$1 == "AXButton" {print $5 "|" $6; exit}')
pos=${btn%|*} size=${btn#*|}
bx=$(( ${pos%,*} + ${size%,*} / 2 )) by=$(( ${pos#*,} + ${size#*,} / 2 ))
note "first button after Version: position $pos, size $size; clicking $bx,$by"
mark=$(log_mark)
"$HOME/click" "$bx" "$by"
sleep 8
note "shown: $(ax_texts 'release|Could not check|nightly|No stable|newer|Checking' | tr '\n' ' ')"
log_since "$mark" | grep -iE 'release|update|check' | sed 's/^/    /'
shot_window "117c-head-checked"
sudo -n /bin/sh -c 'cp /etc/hosts /tmp/hosts.lab && printf "0.0.0.0 api.github.com\n:: api.github.com\n" >> /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder'
note "api.github.com blocked in /etc/hosts"
mark=$(log_mark)
"$HOME/click" "$bx" "$by"
sleep 12
note "shown: $(ax_texts 'release|Could not check|nightly|No stable|newer|Checking' | tr '\n' ' ')"
log_since "$mark" | grep -iE 'release|update|check' | sed 's/^/    /'
shot_window "117c-head-offline"
sudo -n /bin/sh -c 'cp /tmp/hosts.lab /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder'
note "/etc/hosts restored: $(grep -c api.github.com /etc/hosts) api.github.com lines"
close_window
quit_app
note "t117c done"
