# Pull request evidence

Screenshots, recordings and logs from end-to-end runs of open pull requests, linked from the test-report comment on each pull request. Nothing here is built or shipped. This branch has no shared history with `main`, and pushing it starts no workflow.

Runs used two Tart VMs on the maintainer's Mac mini:

- macOS 27.0 (26A428) with Xcode 27.0: each version installed from source with `scripts/install.sh`.
- macOS 26.6.2 (25G83) with Command Line Tools only: each version installed with `scripts/install.sh --allow-unverified-origin --app`, using a bundle built from the same commit in the macOS 27 VM. The Command Line Tools there cannot build the app (no SwiftUI macro plugin).

Each "main" run is b6a7499, except the October 18 runs below, which use 76e517d. Each "pr" or "head" run is the pull request's head at the time of the run.

## Folders

- `pr-59`, `pr-98`, `pr-100`, `pr-102`, `pr-108`, `pr-111`, `pr-122`: images and logs for one pull request each.
- `macos-27.0.1`: every run again, on the macOS 27 VM after its update to macOS 27.0.1 (26A434), the newest release on October 17, 2026. Same commits and scripts; `scripts/run-latest.sh` runs them in order. The macOS 26 VM stays on 26.6.2, the version GitHub's hosted macOS 26 runner uses.
- `macos-27.0.1`, October 18 (UTC) runs on the same macOS 27.0.1 VM: `pr-74`, `pr-84`, `pr-91`, `pr-93`, `pr-99`, `pr-104`, `pr-116`, `pr-117`, `pr-120`. Their logs are `macos-27.0.1/run-full-lab27.log` (`scripts/run-full.sh`) and `macos-27.0.1/run-followup*-lab27.log` (`scripts/run-followup.sh`, given the follow-up names in order). `axlib.sh` has the Accessibility helpers these scripts share, `hold.c` holds the left mouse button for a set time, `move.c` moves the pointer, and `clearnc.sh` closes notification banners before a screenshot.
- `macos-27.0.1`, October 18 (UTC) reruns after the contributors' fixes, on the same VM: PR 74 at 43f7523, PR 117 at 1516b95 and PR 104 at 43281e6. Each ran next to a control: main at ad96f8b for PR 74, and the head reviewed before the fix for the others (099f650 for PR 117, 3a13fa0 for PR 104). Their files start with `rerun-` in `pr-74`, `pr-104` and `pr-117`. The logs are `macos-27.0.1/run-fix-lab27.log` (`scripts/run-fix.sh 74 117 104`), `run-fix2-lab27.log` (`run-fix.sh 104h`) and `run-fix3-lab27.log` (`run-fix.sh 104dock`). PR 74 reused `t74.sh`. For PR 117, `tls-lab.sh` and `tls-server.py` put a local stand-in for `api.github.com` in the VM: a throwaway test CA, trusted in the VM's System keychain only during the run, `/etc/hosts` entries, and an HTTPS server that answers with an older Latest release or with a 302 to another host. `tls-lab.sh down` removed all of it afterwards. `pr-117/rerun-standin-requests.txt` is that server's request log. `t104f.sh` is the earlier probe that found where the tmux disclosure row opens.
- `logs`: the full run logs, one line per step, times in UTC.
- `scripts`: the test scripts, run in the VMs as the admin user over SSH. `lib.sh` has the shared steps. `click.c` posts mouse clicks. `grab.swift` takes ScreenCaptureKit screenshots of a menu bar area about 120 times a second. The Python scripts turn those into GIFs and tick counts.

## Runs in the logs that do not count

- `logs/run-lab27.log`, PR 111 main: "session did not start" (the click missed). The rerun is in `logs/run-extra27.log`.
- `logs/run-lab27.log`, PR 102 main and head: the script checked before the session finished its 5 s start check, so no App Nap entries were written yet. The reruns, which wait for the "session started until" log line, are in `logs/run-extra27.log`.
- The `.mov` recordings from `t111.sh` are not used. `screencapture -v` recorded only some frames. `grab.swift` replaced it.
- `macos-27.0.1/run-full-lab27.log`, PR 117 and PR 104: the scripts found no Check for updates, Edit Apps… or Set Up… button. In these builds on macOS 27, the Settings buttons have no Accessibility name. The follow-up scripts click them by position, after a nearby text: PR 117 in `run-followup2-lab27.log` (online) and `run-followup3-lab27.log` (offline), PR 104 in `run-followup2-lab27.log`. The PR 104 Settings page screenshot taken in that run counts.
- `macos-27.0.1/run-full-lab27.log`, PR 93: the holds started 4 s after SleepDisabled turned 1, not after the "session started until" log line. The reruns, which wait for it, are in `run-followup-lab27.log` (light menu bar) and `run-followup3-lab27.log` (dark menu bar).
- `macos-27.0.1/run-followup-lab27.log`, PR 117 (`t117b.sh`): stopped by hand before it finished; /etc/hosts was put back afterwards. PR 104 (`t104b.sh`): buttons not found, as above.
- `macos-27.0.1/run-fix-lab27.log`, PR 104 hotspot steps (`t104g.sh`): the click on the middle of the disclosure row did not open the tmux list, and the script looked for Done and Add by name, which they don't have. Its typed `work:31.0` went into the Hotspot name field instead; the config was put back after the run. The hotspot checks that count are in `run-fix2-lab27.log` and `run-fix3-lab27.log` (`t104h.sh`). The Settings page and Edit Apps steps in `run-fix-lab27.log` count.
