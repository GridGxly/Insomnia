#!/bin/bash
# PR 104 follow-up: the hotspot sheet with 30 tmux panes, its tmux list
# opened by clicking the disclosure row at its measured place. t104e.sh [REV]
source "$HOME/lab/lib.sh"; source "$HOME/lab/axlib.sh"
rev=${1:-3a13fa0}
note "== PR 104 tmux follow-up, head ($rev) on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
defaults write com.apple.dock autohide -bool true; killall Dock; sleep 2
install_rev "$rev" || exit 1
quit_app
/usr/bin/python3 - "$SUP/config.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["tmuxTargets"] = ["work:%d.0" % i for i in range(1, 31)]
json.dump(c, open(p, "w"), indent=2)
PY
note "config.json set by hand: 30 tmux targets"
launch_app; bash ~/lab/clearnc.sh >/dev/null
open_settings; ax 'set position of window 1 to {40, 60}' >/dev/null; sleep 0.6
note "Set Up clicked at: $(click_after 'Join an iPhone hotspot')"; sleep 2
note "sheet: $(sheet_size)"
ss=$(sheet_size)
sp=${ss#position }; sp=${sp%%, size*}; sz=${ss##*size }
sx=${sp%,*} sy=${sp#*,} sh=${sz#*,}
# The disclosure row sits 107 pt above the sheet's bottom edge (measured on
# the 2026-10-18 t104c screenshot); its chevron is 34 pt in.
cx=$((sx + 34)) cy=$((sy + sh - 107))
note "clicking the tmux disclosure row at: $cx $cy"
"$HOME/click" $cx $cy
sleep 2
note "sheet after opening the tmux list: $(sheet_size); screen 1440x900"
note "tmux targets listed: $(ax_dump | grep -c 'work:')"
screencapture -x "$OUT/104f-head-hotspot-30-tmux-full.png"
key 36; sleep 1.2; note "after Return: sheet $(sheet_size)"
close_window
quit_app
defaults write com.apple.dock autohide -bool false; killall Dock
note "t104f done"
