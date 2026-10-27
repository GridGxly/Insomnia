# One-click re-check on macOS 26 at b6a36e0d

The run completed. Checks 1 through 7 passed. Check 8 reproduced the known exposed AXPress no-op in Pills and Compact, including one alternate Accessibility call per style. There is no new behavioral finding relative to 08ee3e0f in this VM. No trial logged the delayed-click fallback.

Nothing was posted or pushed. All UI input, pointer movement, Accessibility access and captures ran inside the claimed VM. The owner's MacBook UI, apps and Insomnia configuration were untouched. No VM was started, stopped, cloned or deleted. Other VMs were left alone.

## Setup

The target was commit `b6a36e0de3a74847f07767de16406754c825944e`, branch `integration/menu-bar-oneclick`. The previous run's report, log and scripts were read first. Needed helpers were copied into this run's own folder and adapted. The installer and source came from the exact commit archive without changing its checkout. The relevant behavior in `docs/spec.md` and release checks in `docs/releasing.md` was read. No app build ran during this test.

The system was macOS 26.6.2, build 25G83, with a 1024 by 768 display at scale 1. The assigned VM was already running and idle. Accessibility and screen-recording preflight checks were true, and the existing network fence was active. The screen-access reminder was moved away from the targets without granting permission, then restored during cleanup. A setup guard paused before a click because the window list placed full-screen system containers above Settings. The system-wide Accessibility hit test confirmed that the field belonged to Insomnia, and the guard was supplemented with that check. No blocked click was posted.

The staged ZIP was copied into the VM and verified as SHA-256 `b4379f0a05a5db3787209cc6b3c1f12f17d9c9ff08137a23dd7a4834be60d007`. It was extracted with ditto outside /tmp. Existing config.json was moved aside before the target commit's own `scripts/install.sh --app <bundle>/Insomnia.app --allow-unverified-origin` ran. The installer exited 0. Installed CDHash `a6e694ef8ea5fbb85c86c94a920fea3762acbded` matched before testing and after cleanup. The staged ZIP was left in place and checked again at the end.

First launch wrote fresh defaults. One-click start was enabled in Settings. The Minimal duration field was used to enter 10m, then the requested styles were selected through Settings. Config read 600 seconds before the counted start checks. Sounds stayed off. `pictures/00-setup.png` shows the setup.

## Checks

| Check | Result and counts | Evidence |
|---|---|---|
| 1. Immediate Option release in Pills and Compact | Pass, 12/12 immediate trials. Each style passed 3 primary and 3 alternate postings. Held-500-ms passed 2/2; mouse-flags-only passed 2/2. Total 16/16. Controls opened and nothing started after at least 3 seconds. | `c1-*-delivery.txt`, matching result, AX, log, state and target-window records; `c1-Pills-immediate-1.png`, `c1-Compact-immediate-1.png` |
| 2. No kept keys | Pass, 2/2. Immediately after the first Option trial in each style, Escape closed the controls and a plain 90 ms click started exactly 600 seconds with no controls. SleepDisabled was 1, then 0 after CLI end. | `c2-*-no-kept-keys-*` |
| 3. Popover Option and plain clicks | Pass, 3/3 Option methods and 1/1 plain click. Mouse flags, wrapped Option key events and System Events-held Option opened the popover and started nothing. The plain click started exactly 600 seconds with no popover. | `c3-Popover-*` |
| 4. Context menus | Pass, 6/6 right-clicks and 3/3 Control-clicks across Pills, Compact and Minimal. Each produced exactly one menu-open notification and one menu. All 9/9 Escape dismissals and 2/2 plain-left-click dismissals in Pills and Compact started nothing. | `c4-*`, menu notification traces; `04-Pills-menu.png` |
| 5. Popover toggles | Pass, 2/2 pairs, 4/4 clicks. Right-click and Control-click each opened on the first click and closed on the second, with nothing started. | `c5-Popover-*` |
| 6. Minimal hold through right-click | Pass, 2/2. Each 7200-second session retained its end time while left stayed down through the right-click menu, Escape and release. No end or extend line appeared; SleepDisabled stayed 1. Plain 0.8-second hold ended a separate session, 1/1. | `c6-Minimal-*`, including before-session JSON, during-menu AX/state and button-state traces |
| 7. Holds still end sessions | Pass, 2/2. Pills and Compact each started 600 seconds by one click, then a 650 ms hold on the end control logged user-end and sleep-restored, removed session.json and restored SleepDisabled 0. | `c7-Pills-*`, `c7-Compact-*` |
| 8. Accessibility press | Known gap, 2/2 direct AXPress calls were no-ops. The exposed status item advertised AXPress and the call returned success. Both alternate System Events calls were also no-ops. No session, controls or start line appeared; SleepDisabled stayed 0. | `c8-*-actions.txt`, `c8-*-event.txt`, `c8-*-hit-test.txt`, matching AX/log/state/window records and four `c8-*-failure.png` pictures |
| Cleanup | Pass. Full fresh defaults restored, app quit, Settings closed, no session, SleepDisabled 0 on three independent reads, no new /tmp entries, reminder position restored, claim released and VM left running. | `final-state.txt`, `final-independent-check.txt`, `config-final-diff.txt`, `tmp-new.txt`, `reminder-final.txt`, `claim-release.txt` |

Text evidence is under `evidence/`; named pictures are under `pictures/`. All 57 primary result records are present. 55 meet the expected behavior and two record the known AXPress gap. The two AXPress retries are separate corroborating attempts. Each primary trial has its delivery record, target-window record, AX tree, full log slice and state result. An empty pointer-event trace for AXPress means no mouse or key event was observed. The direct action record gives its own timestamp and modifier flags; hit-test diagnostics record released modifier keys for both clients.

Every nothing-started result checked absence of session.json, SleepDisabled 0 and no new session-start line after the wait. A session file with SleepDisabled 1 would have counted as a start even before its confirmation line. Every surviving session was ended through the app's CLI. Full unfiltered logs were preserved in addition to the old filtered helper output. Per-trial searches and complete-log searches contain zero occurrences of `status item: a click handled late counts as an Option-click`.

## Findings and comparison

### Immediate Option release still passes

All 12 immediate trials passed, compared with 6/6 primary immediate trials at 08ee3e0f. This run also included the six required alternate postings. Both mouse events carried Option, flags 524288, in every immediate trial. The following plain click still started 600 seconds in both styles. All other requested pointer and hold behaviors matched the previous run.

| Immediate trial | Option release after mouse-up, ms | Delivered mouse press, ms |
|---|---|---|
| Pills-immediate-1 | 0.427 | 96.499 |
| Pills-immediate-2 | 0.101 | 95.527 |
| Pills-immediate-3 | 0.650 | 95.842 |
| Pills-immediate-alt-1 | 0.642 | 98.689 |
| Pills-immediate-alt-2 | 0.458 | 95.067 |
| Pills-immediate-alt-3 | 0.619 | 95.451 |
| Compact-immediate-1 | 0.320 | 100.949 |
| Compact-immediate-2 | 0.641 | 99.380 |
| Compact-immediate-3 | 0.704 | 97.670 |
| Compact-immediate-alt-1 | 0.470 | 99.106 |
| Compact-immediate-alt-2 | 0.263 | 93.949 |
| Compact-immediate-alt-3 | 0.386 | 101.031 |

The helper requested a 90 ms press. The table records delivered timing, including scheduling variation.

### The exposed AXPress no-op remains

The element at the idle eye was an unnamed `AXMenuBarItem`, subrole `AXMenuExtra`, with AXPress. Direct AXPress returned success, value 0, in both styles. The alternate System Events calls returned without an error and had the same no-op result. Hit tests identified Insomnia's status item, and the target-window records showed no covering system window. Checked modifier keys were released. The raw global flags were 536870912, with no Option, Control, Shift or Command bits.

This matches the known gap in the previous run. The external tree did not expose the separate named SwiftUI eye button, so these results do not establish whether that button's own accessibility callback works. They do not isolate a cause among the native status-item proxy, app routing and the operating system.

## Limits and artifact review

Input was synthetic. Physical mouse, trackpad and VoiceOver activation were not tested. No display-sleep, real-lid or audio test was requested. The simultaneous run on another system is outside this report. Routine Wi-Fi-port lookup errors remain in the full app logs and are unrelated to these checks.

Every selected picture was opened and visually reviewed. Selected pictures contain only the requested Insomnia regions or its Settings window, with no private identifier, network name, notification or unrelated app window. `picture-review.json` records their reviewed hashes. Raw intermediate captures remain in `rejected/`. Text copies omit private paths, account identifiers, unrelated window titles and a default network-utility identifier; original copies remain in `rejected/unredacted/`.

`report.md`, `run.log`, `picture-review.json`, `pictures/` and sanitized `evidence/` are review artifacts. `scripts/`, `scratch/` and `rejected/` are private working material and are not intended for a pull request. No files were posted or pushed.

## End state

The full final config matches the first-launch defaults, including `menuBarMode="pills"`, `oneClickStart=false`, `sessionSounds=false`, `defaultFocusField="hours"` and `defaultPreset=14400`. Insomnia is quit, Settings is closed and session.json is absent. SleepDisabled was 0 on three independent final reads. The recovery journal has no owned sleep or Low Power Mode change and no frozen process. No new /tmp entry remains. The reminder was returned to its original position without permission granted. The claim was released and the VM was left running.
