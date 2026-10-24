# PR 147 at b892819: the three Settings fixes

Runs on October 24, 2026 (UTC), in the macOS 27.0.1 (26A434) VM. Each run started from default settings (config.json removed) and put the old file back at the end. `scripts/t147.sh` ran them, with the shared helpers in `../../scripts` (`lib.sh`, `axlib.sh`, `clearnc.sh`, `click.c`). `scripts/ax147.js` has the Accessibility helpers these runs added. The smoke run added its `pickafter`, `toggle` and `where` modes; the other runs used the same file without them.

- `head`: b892819, installed from source with `scripts/install.sh`. Parts 1 and 2 (battery, Edit Apps) count. Its part 3 (hotspot) does not: the script's first way of closing Terminal raised an Automation prompt that stalled each step for 2 minutes, and the typed password went into the Hotspot name field. Its part 3 screenshots are left out.
- `head3b`: part 3 again on the same install, after the script was fixed (`PARTS=3`). This is the hotspot run that counts.
- `control`: e98c38d, the head before the fix commit, all three parts.
- `t147s-head.log` and the `147s-head-*` images: `scripts/t147s.sh`, a smoke run of the whole page at b892819, installed again from source. It covers the page top to bottom, Edit Apps moving Slack between Freeze and Keep running, and Countdown and "Show the countdown in the menu bar" during a session. Its section headings have no Accessibility name, so the log reads "none" for them; the page images show them. A first smoke run went to the e98c38d install by mistake and is left out.

An earlier part 3 rerun, `head3`, is left out. Its Escape went to Finder, not the sheet, so it showed nothing either way. `head3b` clicks the sheet's top edge first, which makes the sheet take the key.

The published `t147.sh` reads the VM's keychain password from `LAB_KEYCHAIN_PASSWORD`. The run used the VM's password in its place. Nothing else differs.
