# #155 at 499021c in a macOS 26.6.2 VM

The popover checks from the macOS 27 run, repeated on macOS 26.6.2 (25G83). The VM can't build the app, so it ran a bundle built from `499021c` on a MacBook (CDHash `38f9f13258adea2684dbc78dbdcf061c0f59d853`).

- `report.md`, `run.log`, `evidence/` and `pictures/` hold the full run. Eight of the nine checks passed. The end ring's holds failed 0 of 6 here.
- `ring-diagnosis/` holds a second run that found why. A macOS screen-access reminder sat over the ring and got the press instead of Insomnia. With the reminder moved aside, the same bundle ended 13 of 13 popover holds, and 3 of 3 each in Pills, Compact and Minimal. A press on End session through Accessibility also ended the session.
