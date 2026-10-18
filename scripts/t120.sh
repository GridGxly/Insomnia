#!/bin/bash
# PR 120: the deadline timer fires while the wall clock still reads before the
# deadline. A session loaded from the journal 30 s from its deadline; 8 s
# before it, the clock is stepped back to the start of the current second
# (0.75 to 1 s back). t120.sh REV LABEL
source "$HOME/lab/lib.sh"
rev=$1 label=$2
note "== PR 120, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
sudo -n systemsetup -setusingnetworktime off >/dev/null 2>&1
note "network time: $(sudo -n systemsetup -getusingnetworktime 2>&1)"
for run in 1 2; do
  quit_app
  sudo -n /usr/bin/pmset -a disablesleep 1
  now=$(date -u +%s); ends=$((now + 30))
  ( umask 077
    printf '{"startedAt":"%s","endsAt":"%s","extensions":[]}\n' "$(date -u -r $((now - 20)) +%Y-%m-%dT%H:%M:%SZ)" "$(date -u -r $ends +%Y-%m-%dT%H:%M:%SZ)" > "$SUP/session.json"
    printf '{"sleepDisabledByUs":true}\n' > "$SUP/state.json" )
  mark=$(log_mark)
  open "$APP"
  while [ "$(date -u +%s)" -lt $((ends - 8)) ]; do sleep 0.2; done
  step=$(/usr/bin/python3 -c '
import time, subprocess
while time.time() % 1 < 0.75: time.sleep(0.01)
t = time.time()
s = time.strftime("%m%d%H%M%Y.%S", time.gmtime(t))
subprocess.run(["sudo", "-n", "date", "-u", s], stdout=subprocess.DEVNULL)
print("%.3f s" % (t - int(t)))')
  note "run $run: endsAt $(date -u -r $ends +%H:%M:%SZ); clock stepped back $step"
  while [ "$(date -u +%s)" -lt $((ends + 10)) ]; do sleep 1; done
  note "run $run, 10 s after the deadline: $(log_since "$mark" | grep -E 'session end|sleep restored|deadline' | tr '\n' ' ')"
  state_note
  osascript -e 'tell application "System Events" to tell process "Insomnia" to get title of menu bar item 1 of menu bar 2' >/dev/null 2>&1
  shot "120-$label-run$run"
done
quit_app
sudo -n /usr/bin/pmset -a disablesleep 0
rm -f "$SUP/session.json"
sudo -n systemsetup -setusingnetworktime on >/dev/null 2>&1
sleep 2
note "network time: $(sudo -n systemsetup -getusingnetworktime 2>&1); SleepDisabled $(sleep_disabled)"
