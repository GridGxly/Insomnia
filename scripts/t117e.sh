#!/bin/bash
# PR 117 rerun after the review fixes. t117e.sh REV LABEL
# The real check and the offline check as before, then two checks against
# the local stand-in for api.github.com from tls-lab.sh (started by the run
# script): one whose Latest release, v0.0.9, is older than this build, and
# one where api.github.com answers every request with a 302 to evil.test.
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
TLS="$HOME/lab-tls"
note "== PR 117 rerun, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
mark=$(log_mark)
launch_app; bash ~/lab/clearnc.sh >/dev/null
note "launch line: $(log_since "$mark" | grep -m1 'launched')"
open_settings
ax 'set position of window 1 to {40, 60}' >/dev/null; sleep 0.6
note "scroll: $(scroll_settings 1)"; sleep 1.5
note "App section texts: $(ax_texts 'Version|0\.1\.0|Asks GitHub|installer' | tr '\n' ';')"
check() {
  local m
  m=$(log_mark)
  note "$1: Check for updates clicked at: $(click_after '0.1.0 (1)')"
  sleep "$2"
  note "$1: shown: $(ax_texts 'release|Could not check|nightly|No stable|newer|higher|Latest|Checking' | tr '\n' ' ')"
  log_since "$m" | grep -iE 'release|update|check' | sed 's/^/    /'
  shot_window "117e-$label-$1"
}
check github 10
sudo -n /bin/sh -c 'cp /etc/hosts /tmp/hosts.lab && printf "0.0.0.0 api.github.com\n:: api.github.com\n" >> /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder'
note "api.github.com blocked in /etc/hosts"
check offline 12
sudo -n /bin/sh -c 'cp /tmp/hosts.lab /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder'
note "/etc/hosts restored: $(grep -c api.github.com /etc/hosts) api.github.com lines"
if pgrep -f "lab/tls-server.py" >/dev/null; then
  note "$(bash ~/lab/tls-lab.sh hosts-on)"
  for m in older redirect; do
    note "$(bash ~/lab/tls-lab.sh mode $m)"
    n=$(wc -l < "$TLS/requests.log" 2>/dev/null || echo 0)
    check "standin-$m" 10
    note "standin-$m: requests the stand-in saw:"
    tail -n +"$((n + 1))" "$TLS/requests.log" | sed 's/^/    /'
  done
  note "$(bash ~/lab/tls-lab.sh hosts-off)"
else
  note "no stand-in server running; stand-in checks skipped"
fi
close_window
quit_app
note "t117e done"
