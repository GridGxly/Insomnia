#!/bin/bash
# PR 59: duration entry still gives the right session length.
# t59.sh REV LABEL. Types 1 day, 2 hours, 3 minutes into the pills.
source "$HOME/lab/lib.sh"
rev=$1 label=$2
note "== PR 59, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app
x=$(eye_x)
if [ -z "$x" ]; then note "no status item"; exit 1; fi
"$HOME/click" $((x + 16)) 15
sleep 1.5
for k in d 1 h 2 m 3; do
  osascript -e "tell application \"System Events\" to keystroke \"$k\"" >/dev/null
  sleep 0.4
done
sleep 1
shot "59-$label-typed"
key 36
if wait_sleep_disabled; then note "session started from the menu bar; SleepDisabled 1"; else note "session did not start"; exit 1; fi
sleep 3
shot "59-$label-running"
note "session.json length: $(/usr/bin/python3 -c '
import json, sys, datetime
s = json.load(open(sys.argv[1]))
def t(v):
    if isinstance(v, (int, float)): return v
    return datetime.datetime.fromisoformat(v.replace("Z", "+00:00")).timestamp()
print("startedAt %s, endsAt %s, endsAt - startedAt = %d s (1 d 2 h 3 min = 93780 s)" % (s["startedAt"], s["endsAt"], round(t(s["endsAt"]) - t(s["startedAt"]))))
' "$SUP/session.json" 2>&1)"
quit_app
state_note
