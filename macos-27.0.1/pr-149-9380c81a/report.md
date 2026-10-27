## End-to-end test in a VM on macOS 27.0.1, head 9380c81a

At this pull request's head (9380c81a) the session ends at its deadline. It does so even when the deadline timer fires while the clock still reads a fraction of a second before the deadline. In both runs the log shows `session end (timer)` and `sleep restored` in the deadline second, `session.json` is gone and SleepDisabled is 0. On main (2ed30d4), in the same setup, the session was still running 10 s after the deadline. The countdown was stuck at 00:00 and sleep was still disabled. This matches what #120's test found at 5d8c3dd.

The commit tested is 9380c81a0aa6eb6fe7534facf3738029dd156eb3, the head of this pull request when the test ran. The head moved from 7ceb33a3 through 6d912705 and 2582bb34 to 9380c81a while the test waited for the VM. Each of those commits changes only `Tests/InsomniaTests/DeadlineTimerTests.swift`. `git diff 7ceb33a3 9380c81a -- Sources Package.swift scripts` prints nothing. Only 9380c81a was built.

### Setup

A Tart VM on the maintainer's Mac mini, macOS 27.0.1 (26A434) with Xcode 27.0 (27A266a).

```
$ sw_vers
ProductName:		macOS
ProductVersion:		27.0.1
BuildVersion:		26A434
$ sysctl -n hw.model
VirtualMac2,1
$ sysctl -n machdep.cpu.brand_string
Apple M6 (Virtual)
```

Each build was installed from a clean checkout of its exact commit with that commit's own `scripts/install.sh`. The checkout was the VM's clone of the repository, detached at the commit. Its ignored `.build` folder was kept, so the release build was incremental. Both installs exited 0.

| | main | this PR |
|---|---|---|
| `git rev-parse HEAD` | `2ed30d4a353d9710bbd89ee2dd1a7e86990ffd0a` | `9380c81a0aa6eb6fe7534facf3738029dd156eb3` |
| `git status --short` | (empty) | (empty) |
| Installed app cdhash | `0663487dec2e0676a01be3744b83cced7ca0cb69` | `dc656adfcc4918e54c52649abb7ca8a79667edb9` |

Settings were the defaults. `config.json` held the default value of every setting these two builds read, and it did not change during the test.

The script is #120's [`t120.sh`](https://github.com/krishhgg/Insomnia/blob/993a22162bbc68945b974969fa92ac62b394f7a9/scripts/t120.sh) at 993a221, run again without changes. Main has moved since then, so I checked the files the script writes against what the app reads. `Session.swift`, `RuntimeState.swift` and the `Store` code are the same at 76e517d (main in #120's test), 2ed30d4 and 9380c81a. The script did this twice per build:

1. Turned network time off.
2. Wrote a `session.json` ending 30 s from now and a `state.json` saying Insomnia had disabled sleep. Then it opened the app, which loads the session from them.
3. 8 s before the deadline, it stepped the clock back to the start of the current second with `date`.
4. 10 s after the deadline, it read the log from the run's mark, checked for `session.json`, read SleepDisabled and took a screenshot.

A sampler ran `pmset -g | grep SleepDisabled` about once a second for the whole test. The script turned network time back on after each build. At the end network time was on, no session was running and SleepDisabled was 0.

### Results

| | main 2ed30d4 | this PR 9380c81a |
|---|---|---|
| Run 1 | endsAt 10:13:20Z, clock stepped back 0.753 s | endsAt 10:14:55Z, clock stepped back 0.764 s |
| Run 1, 10 s after the deadline | no end in the log; `session.json` still there; SleepDisabled 1 | `session end (timer)` and `sleep restored` at 10:14:55Z; no `session.json`; SleepDisabled 0 |
| Run 2 | endsAt 10:14:00Z, clock stepped back 0.763 s | endsAt 10:15:35Z, clock stepped back 0.762 s |
| Run 2, 10 s after the deadline | same as run 1 | `session end (timer)` and `sleep restored` at 10:15:35Z; no `session.json`; SleepDisabled 0 |
| Menu bar, 10 s after the deadline | eye, 00:00 and the end button | the idle eye |

The log lines that matter, main run 1. The session loads, and nothing about it follows up to the check at 10:13:30Z:

```
2026-10-27T10:12:56Z [info] insomnia: reconcile: session valid until 2026-10-27T10:13:20Z
2026-10-27T10:13:01Z [info] insomnia: hotspot join skipped: no hotspotSSID configured
2026-10-27T10:13:06Z [info] insomnia: hotspot join skipped: no hotspotSSID configured
```

This PR, run 1:

```
2026-10-27T10:14:30Z [info] insomnia: reconcile: session valid until 2026-10-27T10:14:55Z
2026-10-27T10:14:35Z [info] insomnia: hotspot join skipped: no hotspotSSID configured
2026-10-27T10:14:40Z [info] insomnia: hotspot join skipped: no hotspotSSID configured
2026-10-27T10:14:55Z [info] insomnia: session end (timer)
2026-10-27T10:14:55Z [info] insomnia: sleep restored
2026-10-27T10:14:55Z [info] insomnia: notify: Session ended - Time is up. Sleep is back to normal.
```

Run 2 of each build shows the same lines with its own times. `pmset -g | grep SleepDisabled` at each check:

| | main | this PR |
|---|---|---|
| Run 1 | 10:13:30Z ` SleepDisabled 1` | 10:15:05Z ` SleepDisabled 0` |
| Run 2 | 10:14:10Z ` SleepDisabled 1` | 10:15:44Z and 10:15:47Z ` SleepDisabled 0` |

With this PR the samples change from 1 to 0 in the deadline second, 10:14:55Z and 10:15:35Z. On main they stay at 1 through the check.

Menu bar crops, 10 s after the deadline (the right side of the menu bar, and the status item alone):

- main: `main-2ed30d4-run1-menubar.png`, `main-2ed30d4-run1-item.png`, `main-2ed30d4-run2-menubar.png`, `main-2ed30d4-run2-item.png`
- this PR: `head-9380c81a-run1-menubar.png`, `head-9380c81a-run1-item.png`, `head-9380c81a-run2-menubar.png`, `head-9380c81a-run2-item.png`

The full log lines of each run, from its mark to the check, are in `insomnia-main-2ed30d4-run1.log`, `insomnia-main-2ed30d4-run2.log`, `insomnia-head-9380c81a-run1.log` and `insomnia-head-9380c81a-run2.log`. The script's own output is `t120-output.log`, and the SleepDisabled samples are in `sleepdisabled-samples.txt`.

### Not covered

- How long main stays past the deadline. The script checked only at 10 s.
- A timer that fires early on its own, without a clock step. The step stands in for it.
- 7ceb33a3, 6d912705 and 2582bb34 were not built. They differ from 9380c81a only in `Tests/`.
- The unit tests, including `DeadlineTimerTests`, were not run in the VM.
- The end notification on screen. Notifications are not allowed for the app in the VM, so only the log line shows it.
- A build from a fresh clone. Each build reused the VM's clone and its ignored build folder.
- macOS 26 and real hardware. The VM has no lid, battery or Wi-Fi.
