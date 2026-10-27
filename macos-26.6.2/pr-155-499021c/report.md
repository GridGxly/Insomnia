# Popover macOS 26 VM run at 499021c0

The run completed. Eight of the nine checks passed. Check 4 failed: none of the five 650 ms holds or the one 1500 ms hold ended its session. Each hold was repeated once with another event method, and none of those six retries ended its session either. The quick-click safety check passed. The macOS 27 run passed every hold at the same commit.

## Setup

This second attempt used macOS 26.6.2, build 25G83, with 4 CPUs, 8 GB memory and a 1024 × 768 display at scale 1 on 27 October 2026. Accessibility and Screen Recording preflight checks returned true. The claim ran from 16:23:50Z to 16:35:04Z. The VM stayed running throughout.

The target was `499021c0149795df6d3e3a5003ff979b0db75ab8`, PR #155, branch `integration/menu-bar-popover`. The source came from git archive without changing the source clone's working tree. This attempt installed the supplied prebuilt bundle instead of building the app in the VM. The brief identifies that bundle as built from the target commit with its own build-app.sh on macOS 26.2 using Xcode and Swift 6.3.1.

The ZIP was streamed into the VM without staging another copy on the remote Mac. Its verified SHA-256 was `9eafe982253a575666252837fb566734c6d10c59fcf5264497c8c2d68f5ecc65`. It was extracted with ditto under this run's home-directory folder, outside /tmp. No config.json existed to move aside. The archived commit's unmodified `scripts/install.sh --app <bundle>/Insomnia.app --allow-unverified-origin` exited 0. The installed CDHash was `38f9f13258adea2684dbc78dbdcf061c0f59d853`, exactly as required. The installer verified the sudoers rule and loaded the bundle-pinned recovery agent. Its output and exit code are in `evidence/attempt-2/install.log` and `install-exit-code.txt`.

The first launch wrote `menuBarMode: "pills"` and `defaultPreset: 14400`. Popover was selected in Settings > General > Menu bar, and config.json read `menuBarMode: "popover"`. Settings was closed for the counted popover checks. Finder and empty TextEdit documents supplied the opening apps. Existing helpers compiled during attempt 1 were reused inside this VM. The macOS 27 run's files were read but never changed.

The first attempt's report is preserved as `report-attempt-1.md`, together with its scripts, failed source-build evidence and other files. This attempt's sanitized evidence is under `evidence/attempt-2/`, its scripts under `scripts/attempt-2/`, and its private working copies under `scratch/attempt-2/`.

| Check | Result and counts | Evidence |
|---|---|---|
| 1. Clicks inside | Pass, 10/10 trials, five from Finder and five from TextEdit. All 20 header and Custom clicks kept the popover open. Custom exposed Hours, and Insomnia stayed in front. | `evidence/attempt-2/c1-*-ax.txt`, `run.log` |
| 2. Custom focus | Pass, 2/2 trials, one from each app. Typing 3 without a field click filled Hours, left it focused and enabled Start. TextEdit stayed empty. | `evidence/attempt-2/c2-*-ax.txt`, `pictures/02-custom-TextEdit.png` |
| 3. Esc | Pass, 2/2 trials from TextEdit, with buttons only and with Hours focused. The popover closed, TextEdit came forward and received k. | `evidence/attempt-2/c3-*-ax.txt`, `run.log` |
| 4. End ring | Fail, 0/6 holds ended a fresh CLI-started 2 h session. Five were 650 ms and one was 1500 ms. Alternate glide retries also ended 0/6 sessions. Each left the popover open, session.json present and SleepDisabled 1. The 90 ms quick click passed, preserving the session and its end time with no end log line. | `evidence/attempt-2/c4-*`, `pictures/04-hold-6-failure.png`, `pictures/04-hold-6-retry.png` |
| 5. Arrow | Pass, 2/2 width changes while the popover stayed open. Idle item and popover centres were both 781 pt; after CLI start both were 756 pt; after CLI end both were 781 pt. Error was 0 pt at every sample. | `evidence/attempt-2/c5-geometry.txt`, `pictures/05-after-start.png`, `pictures/05-after-end.png` |
| 6. Command-Tab | Pass, 3/3 valid trials with TextEdit selected. Closure after TextEdit activation took about 0.55 s with the pointer on the item, 0.54 s on the popover and 0.03 s elsewhere. TextEdit received k every time. Six earlier wrong-target setup attempts are excluded. | `evidence/attempt-2/c6-selected-*-watch.txt`, `run.log` |
| 7. Quick cycles | Pass, 12/12 sequences, 42 item clicks. At each nominal 150, 300 and 500 ms gap, three clicks ran twice and four clicks ran twice. Every three-click sequence left Insomnia in front and Custom then 3 filled Hours. Every four-click sequence closed the popover and returned k to TextEdit. | `evidence/attempt-2/c7-*`, `pictures/07-three-clicks-custom.png` |
| 8. Idle rows | Pass, one opening sampled immediately and 11 s later. Rows read Lid open, Hotspot failover off and Wi-Fi On. Settings and Quit were present. No battery row appeared; the VM reports AC Power and has no battery. | `evidence/attempt-2/c8-*`, `pictures/08-idle-rows.png` |
| 9. Other styles | Pass, 3/3 left-click checks and 3/3 right-click menu checks. Pills widened from 34 to 228 pt and exposed Days, Hours and Minutes. Compact opened its duration panel. Minimal started the default 14400 s session with SleepDisabled 1. Every right-click menu included Settings and Quit. The Minimal session ended through the CLI with SleepDisabled 0. | `evidence/attempt-2/c9-*`, `pictures/09-pills-left.png`, `pictures/09-minimal-started.png` |

## Finding and comparison

The ring did not end any session under either event method. This reproduces a hold-to-end failure in the tested macOS 26 setup. A physical mouse trial was not possible, so the result does not identify the underlying cause.

For example, the first hold posted down at epoch `1793118451.659238` and up at `1793118452.317137`, a measured 658 ms. Accessibility before and after showed an enabled End session button at `618,124,20,20`, the running-session header, and the same open popover. The isolated app-log slice contained only:

```text
2026-10-27T16:27:32Z [info] insomnia: hotspot join skipped: no hotspotSSID configured
```

There was no `session end (user)` or `sleep restored` line in that slice. The longer primary hold measured 1504 ms and also left the session running. The alternate helper glided the pointer into the same Accessibility-derived target, rested for 250 ms, then held for the requested interval. All six such retries failed. Every trial had zero standard Insomnia windows open. Each isolated log and Accessibility snapshot was saved before the still-running session was ended through the CLI. Those CLI ends restored sleep, and the final state was clean.

The primary five short holds measured 654 to 665 ms; the long hold measured 1504 ms. The nominal 90 ms quick click measured 98 ms. Evidence includes `c4-1-events.txt`, `c4-1-before-ax.txt`, `c4-1-after-ax.txt`, `c4-1-log.txt`, and the corresponding files for trials 2 through 6 and their retries. The 1.5 s failure and retry pictures show the running header and ring still present.

At the same commit, macOS 27 passed 6/6 holds. That run built its own bundle in the VM and had a different CDHash. This run used the supplied macOS 26.2-built bundle. The observed difference therefore does not isolate macOS version from build-toolchain differences. The other eight checks agree with macOS 27. The omitted battery row also agrees. Command-Tab timing was comparable. Pills needed a geometry-targeting retry on macOS 27; here the script waited an extra second for the item to settle, and its first right-click succeeded.

Compared with the earlier macOS 26.2 run at 650c666, the inside-click closure, missing Custom focus, Esc failure and arrow offset did not recur. The ring failure here left the popover open, unlike the earlier cases where the press closed it.

## Setup corrections and limits

The copied Command-Tab script assumed two Tab taps would select TextEdit. This VM also had Terminal in the switcher. The initial HID attempts selected Terminal, and their System Events retries selected Finder. All six closed the popover. The input guard withheld k while Terminal was in front. The valid trials used three Tab taps with Command held, verified TextEdit activation separately from popover closure, and verified that TextEdit received k. These are the three counted results.

The C2 picture notes initially used the prefix evidence/ even though the files were written to pictures/. run.log records that correction. The final process-count formatter used a pgrep option unavailable on this macOS; separate supported `pgrep -x` absence assertions passed for both apps. The published final-state evidence records this formatting limit.

All input was synthetic. Both ring methods posted at the HID event tap; the retry changed pointer delivery to a glide and rest. No physical input, display sleep, Space switch, alternate display, Reduce Motion or battery-powered behavior was tested. Closure timings use 10 ms watcher polling plus event-loop and window-query overhead. The app log has whole-second timestamps. Measured cycle intervals were 152 to 158 ms, 301 to 315 ms and 505 to 515 ms.

Every selected picture was opened and visually reviewed. It shows only Insomnia's own status-item rectangle and, where present, a separate capture of its popover. Other pixels are transparent. The 25 selected pictures are under pictures/; `evidence/attempt-2/picture-review.json` records the review. The six item-only switcher-setup pictures are under rejected/attempt-2/switcher-setup/. Unmasked intermediate captures stay under scratch/attempt-2/rejected/ and are not PR attachments. No evidence files were deleted. The report, run log, selected pictures and sanitized evidence omit VM account names, passwords, host names and addresses. Scripts and scratch material are private working files.

## End state

Cleanup completed at 16:34:34Z. Insomnia is quit, config.json matches the first-launch defaults exactly, no session.json exists and SleepDisabled is 0. TextEdit's two documents were closed without saving, and TextEdit is quit. The /tmp entry set gained nothing. An independent final check passed at 16:35:02Z and also read `sleepDisabledByUs=false`, `lowPowerSetByUs=false` and an empty frozenProcesses list.

The claim was released at 16:35:04Z after evidence export. The VM remains running, and the staged ZIP on the remote Mac remains in place with its original checksum. No VM was started, stopped, cloned or deleted. Other VMs were left alone. No MacBook UI event, Accessibility request, screenshot, app launch, app quit or Insomnia configuration change occurred. Nothing was posted or pushed.
