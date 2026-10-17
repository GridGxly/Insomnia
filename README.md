# Pull request evidence

Screenshots, recordings and logs from end-to-end runs of open pull requests, linked from the test-report comment on each pull request. Nothing here is built or shipped. This branch has no shared history with `main`, and pushing it starts no workflow.

Runs used two Tart VMs on the maintainer's Mac mini:

- macOS 27.0 (26A428) with Xcode 27.0: each version installed from source with `scripts/install.sh`.
- macOS 26.6.2 (25G83) with Command Line Tools only: each version installed with `scripts/install.sh --allow-unverified-origin --app`, using a bundle built from the same commit in the macOS 27 VM. The Command Line Tools there cannot build the app (no SwiftUI macro plugin).

Each "main" run is b6a7499. Each "pr" run is the pull request's head at the time of the run.

## Folders

- `pr-59`, `pr-98`, `pr-100`, `pr-102`, `pr-108`, `pr-111`, `pr-122`: images and logs for one pull request each.
- `logs`: the full run logs, one line per step, times in UTC.
- `scripts`: the test scripts, run in the VMs as the admin user over SSH. `lib.sh` has the shared steps. `click.c` posts mouse clicks. `grab.swift` takes ScreenCaptureKit screenshots of a menu bar area about 120 times a second. The Python scripts turn those into GIFs and tick counts.

## Runs in the logs that do not count

- `logs/run-lab27.log`, PR 111 main: "session did not start" (the click missed). The rerun is in `logs/run-extra27.log`.
- `logs/run-lab27.log`, PR 102 main and head: the script checked before the session finished its 5 s start check, so no App Nap entries were written yet. The reruns, which wait for the "session started until" log line, are in `logs/run-extra27.log`.
- The `.mov` recordings from `t111.sh` are not used. `screencapture -v` recorded only some frames. `grab.swift` replaced it.
