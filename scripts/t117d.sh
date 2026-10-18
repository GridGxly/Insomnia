#!/bin/bash
# PR 117 follow-up, offline: api.github.com blocked in /etc/hosts, then
# Check for updates (clicked by position, found after the Version row).
# t117d.sh REV
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1
note "== PR 117 offline follow-up, head ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings
ax 'set position of window 1 to {40, 60}' >/dev/null; sleep 0.6
note "scroll: $(scroll_settings 1)"; sleep 1.5
sudo -n /bin/sh -c 'cp /etc/hosts /tmp/hosts.lab && printf "0.0.0.0 api.github.com\n:: api.github.com\n" >> /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder'
note "api.github.com blocked in /etc/hosts"
mark=$(log_mark)
note "Check for updates clicked at: $(click_after "0.1.0 (1)")"
sleep 12
note "shown: $(ax_texts 'release|Could not check|nightly|No stable|newer|Checking' | tr '\n' ' ')"
log_since "$mark" | grep -iE 'release|update|check' | sed 's/^/    /'
shot_window "117d-head-offline"
sudo -n /bin/sh -c 'cp /tmp/hosts.lab /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder'
note "/etc/hosts restored: $(grep -c api.github.com /etc/hosts) api.github.com lines"
close_window
quit_app
note "t117d done"
