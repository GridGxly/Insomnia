#!/bin/bash
cd ~ && source ~/lab/lib.sh; source ~/lab/axlib.sh; source ~/lab/t145lib.sh
pgrep -x Insomnia >/dev/null || { launch_app; sleep 6; }
echo "before: $(config_get countdownStyle)"
open_settings >/dev/null 2>&1; sleep 2
scroll_settings 0 >/dev/null 2>&1; sleep 1
echo "pick: $(ax_pick Countdown 'End time')"
echo "immediately: $(config_get countdownStyle)"
sleep 2; echo "2 s later: $(config_get countdownStyle)"
echo "pick back: $(ax_pick Countdown 'Time left')"
sleep 2; echo "2 s later: $(config_get countdownStyle)"
close_window >/dev/null 2>&1
