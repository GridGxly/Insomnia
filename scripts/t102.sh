#!/bin/bash
# PR 102: App Nap entries put back when the key or its domain is already gone.
# macOS 27 says "Could not find key" / "Domain ... not found." there, not
# "does not exist". t102.sh REV LABEL
source "$HOME/lab/lib.sh"
rev=$1 label=$2
note "== PR 102, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
if [ ! -f "$SUP/config.json" ]; then launch_app; quit_app; fi
python3 - "$SUP/config.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["disableAppNapForAgents"] = True
json.dump(c, open(p, "w"), indent=2)
PY
note "config: disableAppNapForAgents $(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["disableAppNapForAgents"])' "$SUP/config.json")"
defaults write com.apple.Terminal NSAppSleepDisabled -bool NO
defaults delete com.google.Chrome >/dev/null 2>&1
defaults write com.google.Chrome LabMarker -bool YES
defaults delete com.docker.docker >/dev/null 2>&1
nap() {
  local id
  for id in com.apple.Terminal com.google.Chrome com.docker.docker; do
    printf '    %s: %s\n' "$id" "$(defaults read "$id" NSAppSleepDisabled 2>&1 | grep -v '^$' | tail -1)"
  done
}
overrides() { plutil -extract appNapOverrides json -o - "$SUP/state.json" 2>/dev/null | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo "none"; }
note "before any session (Terminal set to 0; Chrome's domain has another key; Docker's domain absent):"
nap

note "-- A: a session ended by Quit"
launch_app
mark=$(log_mark)
start_session
if wait_log "$mark" 'session started until' 20; then note "session started (log: $(log_since "$mark" | grep -m1 'session started until' | cut -c1-90))"; else note "no 'session started' log line within 20 s"; fi
sleep 1
log_since "$mark" | grep -i -E 'app nap' | sed 's/^/    /'
note "during the session (App Nap entries in the journal: $(overrides)):"
nap
quit_app
log_since "$mark" | grep -i -E 'app nap' | sed 's/^/    /'
note "after Quit:"
nap

note "-- B: force quit; before the agent runs, Chrome's key and Docker's whole domain are deleted"
launch_app
mark=$(log_mark)
start_session 1
if wait_log "$mark" 'session started until' 20; then note "1 minute session started; App Nap entries in the journal: $(overrides)"; else note "no 'session started' log line within 20 s"; fi
sleep 1
defaults delete com.google.Chrome NSAppSleepDisabled
defaults delete com.docker.docker
# On macOS 27 a deleted domain leaves an empty plist ("Could not find key");
# removing the file gives the "Domain ... not found" an uninstalled app has.
rm -f "$HOME/Library/Preferences/com.docker.docker.plist"
note "what defaults read says now:"
nap
kill -9 "$(app_pid)"
note "force-quit the app (kill -9); waiting for the agent at the deadline"
for i in $(seq 200); do
  [ ! -e "$SUP/session.json" ] && [ "$(sleep_disabled)" = 0 ] && break
  sleep 1
done
state_note
note "waiting 130 s for two more agent runs"
sleep 130
state_note
note "App Nap entries left in the journal: $(overrides)"
note "agent log lines about App Nap since the force quit:"
log_since "$mark" | grep -E 'NSAppSleepDisabled|App Nap' | sed 's/^/    /' | tail -16
note "after the agent:"
nap

note "-- C: uninstall after a force quit, with Chrome's key and Docker's domain deleted"
launch_app
mark=$(log_mark)
start_session
if wait_log "$mark" 'session started until' 20; then note "session started; App Nap entries in the journal: $(overrides)"; else note "no 'session started' log line within 20 s"; fi
sleep 1
defaults delete com.google.Chrome NSAppSleepDisabled
defaults delete com.docker.docker
# On macOS 27 a deleted domain leaves an empty plist ("Could not find key");
# removing the file gives the "Domain ... not found" an uninstalled app has.
rm -f "$HOME/Library/Preferences/com.docker.docker.plist"
kill -9 "$(app_pid)"
note "force-quit the app; running uninstall.sh"
cd "$SRC" && ./scripts/uninstall.sh > "$OUT/uninstall-102-$label.log" 2>&1
note "uninstall.sh exit $?; its lines about App Nap or failures:"
grep -i -E 'NSAppSleepDisabled|app nap|fail|error|could not' "$OUT/uninstall-102-$label.log" | sed 's/^/    /' | head -12
note "after uninstall:"
nap
state_note
defaults delete com.google.Chrome LabMarker >/dev/null 2>&1
