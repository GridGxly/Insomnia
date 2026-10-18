#!/bin/bash
# PR 117: the version in Settings and Check for updates. t117.sh REV LABEL
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=$1 label=$2
note "== PR 117, $label ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
note "bundle: CFBundleShortVersionString $(defaults read "$HOME/Applications/Insomnia.app/Contents/Info" CFBundleShortVersionString 2>/dev/null) (after install)"
mark=$(log_mark)
install_rev "$rev" || exit 1
launch_app; bash ~/lab/clearnc.sh >/dev/null
note "launch line: $(log_since "$mark" | grep -m1 'launched')"
open_settings
note "scroll: $(scroll_settings 1)"; sleep 1
note "controls at the bottom: $(ax_controls | tail -12 | tr "\n" ";" | tr -s " ")"
note "Version row: $(ax_dump | grep -A2 'AXStaticText|Version|' | tr '\n' ' ' | tr -s ' ')"
mark=$(log_mark)
note "press Check for updates: $(ax_press_label 'Check for updates')"
for _ in $(seq 20); do sleep 1; ax_texts 'release|Could not check|No stable' | grep -q . && break; done
sleep 1
note "shown: $(ax_texts 'release|Could not check|nightly|No stable' | tr '\n' ' ')"
log_since "$mark" | grep -iE 'release|update|check' | sed 's/^/    /'
shot_window "117b-$label-checked"
# Offline: api.github.com resolves to nowhere.
sudo -n /bin/sh -c 'cp /etc/hosts /tmp/hosts.lab && printf "0.0.0.0 api.github.com\n:: api.github.com\n" >> /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder'
note "api.github.com blocked in /etc/hosts"
mark=$(log_mark)
note "press Check for updates: $(ax_press_label 'Check for updates')"
for _ in $(seq 30); do sleep 1; ax_texts 'Could not check' | grep -q . && break; done
note "shown: $(ax_texts 'release|Could not check|nightly' | tr '\n' ' ')"
log_since "$mark" | grep -iE 'release|update|check' | sed 's/^/    /'
shot_window "117b-$label-offline"
sudo -n /bin/sh -c 'cp /tmp/hosts.lab /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder'
note "/etc/hosts restored"
close_window
quit_app
