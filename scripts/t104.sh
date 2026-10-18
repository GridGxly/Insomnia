#!/bin/bash
# PR 104: the one-page Settings, Edit Apps and the hotspot sheet; then an app
# on both lists in an older config. t104.sh REV LABEL
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
note "== PR 104, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
# A stand-in Slack, so this Mac has a third-party app the lists name.
if [ ! -d "$HOME/Applications/Slack.app" ]; then
  mkdir -p "$HOME/Applications/Slack.app/Contents/MacOS"
  cat > "$HOME/Applications/Slack.app/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.tinyspeck.slackmacgap</string>
<key>CFBundleName</key><string>Slack</string>
<key>CFBundleExecutable</key><string>Slack</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PL
  printf '#!/bin/sh\nsleep 1\n' > "$HOME/Applications/Slack.app/Contents/MacOS/Slack"
  chmod +x "$HOME/Applications/Slack.app/Contents/MacOS/Slack"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$HOME/Applications/Slack.app"
  note "registered a stand-in Slack.app (com.tinyspeck.slackmacgap)"
fi
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings
note "window: $(ax 'get name of window 1'), size $(ax 'get size of window 1')"
note "headings and controls: $(ax_controls | awk -F'|' '{print $2}' | grep . | tr '\n' ';')"
shot_window "104-$label-settings"
note "Edit Apps: $(ax_press AXButton 'Edit Apps…')"
sleep 1.5
shot_window "104-$label-apps"
note "sheet: $(ax_dump | grep -E 'AXPopUpButton|AXStaticText\|(Slack|Terminal)' | awk -F'|' '{print $2"="$NF}' | tr '\n' ';')"
ax_press AXButton Done >/dev/null; sleep 1
note "hotspot: $(ax_press AXButton 'Set Up…')"
sleep 1.5
shot_window "104-$label-hotspot"
ax_press AXButton Done >/dev/null; sleep 1
close_window
quit_app
/usr/bin/python3 - "$SUP/config.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
for k in ("agentList", "freezeList"):
    c[k] = [b for b in c.get(k, []) if b != "com.tinyspeck.slackmacgap"] + ["com.tinyspeck.slackmacgap"]
json.dump(c, open(p, "w"), indent=2)
PY
note "config.json set by hand: com.tinyspeck.slackmacgap on both agentList and freezeList"
launch_app
open_settings
note "Settings summary lines: $(ax_texts 'Slack|Keep running|Freeze when' | tr '\n' ';')"
shot_window "104-$label-both-lists"
ax_press AXButton 'Edit Apps…' >/dev/null; sleep 1.5
note "Edit Apps rule for Slack: $(ax_dump | grep -E 'AXPopUpButton' | awk -F'|' '{print $2"="$NF}' | tr '\n' ';')"
shot_window "104-$label-both-lists-apps"
ax_press AXButton Done >/dev/null; sleep 1
close_window
quit_app
