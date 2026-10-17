#!/bin/bash
# PR 108: the recovery agent between sessions.
# t108.sh REV LABEL
source "$HOME/lab/lib.sh"
rev=$1 label=$2
note "== PR 108, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app
mark=$(log_mark)
start_session 1
if wait_sleep_disabled; then note "1 minute session started from the menu bar"; else note "session did not start"; exit 1; fi
if wait_log "$mark" 'session end' 100; then note "$(log_since "$mark" | grep 'session end' | tail -1)"; else note "no session end within 100 s"; fi
sleep 3
state_note
backstop_execs "108-$label-idle-1"
note "waiting 130 s for two agent runs"
sleep 130
state_note
backstop_execs "108-$label-idle-2"
note "log lines from the agent since the session ended:"
log_since "$mark" | grep -i -E 'backstop|recover' | sed 's/^/    /' | tail -10
note "-- force quit mid-session, then the agent recovers at the deadline"
mark=$(log_mark)
start_session 1
wait_sleep_disabled && note "1 minute session started"
sleep 3
kill -9 "$(app_pid)"
note "force-quit the app (kill -9)"
for i in $(seq 200); do
  [ ! -e "$SUP/session.json" ] && [ "$(sleep_disabled)" = 0 ] && break
  sleep 1
done
state_note
log_since "$mark" | grep -i -E 'backstop|recover|restored|session end' | sed 's/^/    /' | tail -10
backstop_execs "108-$label-after-agent-recovery"
note "-- the next session started and ended from the app"
launch_app
mark=$(log_mark)
start_session 1
wait_sleep_disabled && note "1 minute session started"
wait_log "$mark" 'session end' 100 && note "$(log_since "$mark" | grep 'session end' | tail -1)"
sleep 3
backstop_execs "108-$label-after-next-session"
quit_app
state_note
