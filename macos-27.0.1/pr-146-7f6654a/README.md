# PR 146 at 7f6654a: `Insomnia --session` from a shell

Runs in the macOS 27.0.1 (26A434) VM. Each run installed its commit from a clean checkout with `scripts/install.sh`, started from default settings (config.json removed) and put the old file back at the end. `scripts/t146.sh` ran both, with the shared helpers in `../../scripts` (`lib.sh`, `axlib.sh`, `clearnc.sh`, `click.c`) and `t145lib.sh` from `../pr-145-732de03/scripts`.

- `t146-7f6654a.log` and the `146-head2-*` images: 7f6654a, the head. This is the run that counts. It ran on October 26, 2026 (UTC).
- `t146-37f87d5.log`: 37f87d5, the head before the fix commit, on October 24. It shows the bug 7f6654a fixes: in part 4, the second `extend 2147483647` at the 30 day cap exits 0. Every other part matches the head run. Its images are left out, since they match the head's.

The logs print the VM's home folder as `~`. Nothing else is changed.
