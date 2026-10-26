#!/bin/bash
# PR 146: Insomnia --session from a shell. t146.sh REV LABEL
#   1. start, status, a second start, extend, end, usage errors
#   2. an end sent just before a start, and a start just before an end
#   3. two command lines at once: two starts, then two extends
#   4. extend at the 30 day cap
#   5. an end refused while another process holds the recovery lock, and
#      the app's retry once the lock is free
#   6. a start while the pills are open
#   7. a start while the app isn't running, then a launch
# Starts from default settings (config.json removed) and puts the old file
# back at the end.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"; source "$HOME/lab/t145lib.sh"
rev=$1 label=$2
CLI="$APP/Contents/MacOS/Insomnia"
now_s() { /usr/bin/python3 -c 'import time; print("%.2f" % time.time())'; }
# cli ARGS...: one command line, timed: "exit N in T s: output"
cli() {
  local s e out rc
  s=$(now_s)
  out=$("$CLI" --session "$@" 2>&1); rc=$?
  e=$(now_s)
  echo "exit $rc in $(/usr/bin/python3 -c "print('%.1f' % ($e - $s))") s: $out"
}
# bg NAME ARGS...: one command line in the background, its result in /tmp/146-NAME
bg() {
  local n=$1; shift
  ( out=$("$CLI" --session "$@" 2>&1); echo "exit $? : $out" > "/tmp/146-$n" ) &
}
left_files() { ls -a "$SUP" | grep -c '^session-command\.'; }
state() { echo "$(sess), SleepDisabled $(sleep_disabled), command files left $(left_files)"; }
end_clean() {
  if in_session; then note "end to reset: $(cli end)"; sleep 1; fi
}

note "== PR 146 session command line, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
end_any; quit_app
install_rev "$rev" || exit 1
note "Info.plist InsomniaSessionCommandVersion: $(/usr/libexec/PlistBuddy -c 'Print :InsomniaSessionCommandVersion' "$APP/Contents/Info.plist" 2>&1)"
[ -f "$SUP/config.json" ] && cp "$SUP/config.json" "$OUT/146-$label-config-saved.json"
rm -f "$SUP/config.json"
note "config.json removed: the app starts from its defaults"
launch_app; bash ~/lab/clearnc.sh >/dev/null
m0=$(log_mark)

note "-- 1. start, status, extend, end"
note "status: $(cli status)"
note "start 120: $(cli start 120)"; note "state: $(state)"
sleep 1; geom; note "status item width $width; bar: $(bar_text | tr '\n' ' ')"
shot_menubar "146-$label-1-started"
note "status: $(cli status)"
note "start 60 again: $(cli start 60)"
note "extend 60: $(cli extend 60)"
note "status: $(cli status)"
sleep 1; note "bar: $(bar_text | tr '\n' ' ')"
shot_menubar "146-$label-1-extended"
note "end: $(cli end)"; note "state: $(state)"
sleep 1; geom; note "status item width $width"
shot_menubar "146-$label-1-ended"
note "end with no session: $(cli end)"
note "extend with no session: $(cli extend 60)"
note "usage: start 0: $(cli start 0)"
note "usage: start abc: $(cli start abc)"
note "usage: nothing: $(cli)"

note "-- 2. end then start, start then end"
bg e1 end; sleep 0.3; bg s1 start 120; wait
note "end sent first: $(cat /tmp/146-e1)"; note "start sent 0.3 s later: $(cat /tmp/146-s1)"
note "state: $(state); status: $(cli status)"
end_clean
bg s2 start 120; sleep 0.3; bg e2 end; wait
note "start sent first: $(cat /tmp/146-s2)"; note "end sent 0.3 s later: $(cat /tmp/146-e2)"
note "state: $(state); status: $(cli status)"
end_clean

note "-- 3. two command lines at once"
bg a start 120; bg b start 120; wait
note "start 120 (a): $(cat /tmp/146-a)"; note "start 120 (b): $(cat /tmp/146-b)"
note "status: $(cli status)"
bg c extend 600; bg d extend 600; wait
note "extend 600 (c): $(cat /tmp/146-c)"; note "extend 600 (d): $(cat /tmp/146-d)"
note "status: $(cli status)"
note "state: $(state)"

note "-- 4. extend at the cap"
note "extend 2147483647: $(cli extend 2147483647)"
note "extend 2147483647 again: $(cli extend 2147483647)"
note "status: $(cli status)"

note "-- 5. end while another process holds the recovery lock"
lockf -k "$SUP/.recovery.lock" sleep 12 &
lp=$!; sleep 1
note "lock held by pid $lp"
m=$(log_mark)
note "end: $(cli end)"; note "state: $(state)"
wait "$lp"; note "lock released at $(date -u +%H:%M:%SZ)"
for i in $(seq 90); do in_session || break; sleep 1; done
note "after ${i} s: state: $(state)"
note "log since the end: $(log_since "$m" | grep -i -E 'session command|recovery lock|session ended|retry|end' | cut -c1-170 | tr '\n' ';')"
end_clean

note "-- 6. a start while the pills are open"
x=$(eye_x); "$HOME/click" $((x + 16)) 15; sleep 1.5
geom; note "pills open: status item width $width"
shot_menubar "146-$label-6-pills-open"
note "start 120: $(cli start 120)"; sleep 1.5
geom; note "status item width $width; bar: $(bar_text | tr '\n' ' ')"
shot_menubar "146-$label-6-after-start"
key 53; sleep 1
geom; note "after Escape: status item width $width; status: $(cli status)"
note "state: $(state)"
end_clean

note "-- 7. the app not running"
quit_app; note "app pid: '$(app_pid)'"
note "start 120: $(cli start 120)"
note "state: $(state)"
m=$(log_mark)
launch_app; sleep 8
note "after a launch: state: $(state)"
note "log since the launch: $(log_since "$m" | grep -i -E 'session command|session started' | cut -c1-170 | tr '\n' ';')"

note "-- the app's session command lines"
log_since "$m0" | grep 'session command' | cut -c1-200
end_any; quit_app
rm -f "$SUP/config.json"
[ -f "$OUT/146-$label-config-saved.json" ] && cp "$OUT/146-$label-config-saved.json" "$SUP/config.json"
note "t146 done ($label)"
