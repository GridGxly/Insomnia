# macOS 26 ring diagnosis at 499021c0

The repeatable failure in this VM was a test-window obstruction. An already-present macOS screen-access reminder covered the End session ring and received its mouse events. The separate probe still read the left button as held. After the reminder moved away, all 13 requested Popover holds and all nine other-style holds ended their sessions.

## Setup

The run used macOS 26.6.2, build 25G83, on 27 October 2026. The display was 1024 × 768 at scale 1. The VM was already running. The claim began at 16:42:17Z and was released at 17:02:34Z. No VM was started, stopped, cloned or deleted. Other VMs were left alone.

The installed bundle remained at commit `499021c0149795df6d3e3a5003ff979b0db75ab8`, PR #155. Its CDHash was verified before launch and after cleanup as `38f9f13258adea2684dbc78dbdcf061c0f59d853`. No reinstall or app rebuild was necessary. Source files were read from the target commit with `git show`; read-only tree and grep queries located the relevant paths. No checkout, edit or build ran in that clone. The prior macOS 26 and 27 reports, the original macOS 26 run log, its posting scripts and every C4 hold log and Accessibility snapshot were reviewed. The older macOS 26.2 report was also reviewed.

Every session started with `Insomnia --session start 7200`. Surviving sessions ended with `--session end`. Counted holds requested 650 ms. The original HID-system-state posting helper was reused without changing its event source or click-state fields. The separate Swift probe created no window. Its nominal polling interval was 10 ms. Accessibility and Screen Recording preflight checks were already true.

All UI operations, Accessibility queries and screen captures ran inside the claimed VM from the host Mac. No MacBook UI event, Accessibility query, screenshot, app launch, app quit or Insomnia configuration change occurred. Nothing was posted or pushed.

## Answers

| Question | Result and counts | Evidence |
|---|---|---|
| 1. Does the synthetic hold register? | Yes, 4/4 probes. Primary and glide posting each produced held state 1 on the desktop and on the ring. Desktop primary: 66 held samples; desktop glide: 66; ring primary: 66; ring glide: 65. Mouse location stayed fixed during every hold. Neither initial ring hold ended its session while the reminder covered the ring. No alternate source or click-state field was needed. | `evidence/q1-*-probe.txt`, `evidence/q1-ring-*-log.txt`, `evidence/summary.json`, `scripts/probe.swift` |
| 2. Does the Popover ring end the session? | With the obstruction moved away: Settings open, 5/5; Settings closed after a header click, 5/5; Settings closed without a prior click, 3/3. All 13 logged both `session end (user)` and `sleep restored`, removed the session and left SleepDisabled 0. The popover stayed open on its idle view. | `evidence/q2-results.csv`, `evidence/q2-*-log.txt`, `evidence/q2-*-before-tree.txt`, `evidence/q2-*-after-ax.txt` |
| 3. Do the other rings work? | Pills, 3/3; Compact, 3/3; Minimal eye, 3/3. All nine logged both required lines and left no session with SleepDisabled 0. | `evidence/q3-results.csv`, `evidence/q3-*-log.txt`, `evidence/q3-*-probe.txt` |
| 4. Where does the press go? | In the fresh-session reversal, the obstructed hold ended 0/1 sessions and down/up targeted reminder window 58. With the reminder away and the popover reopened, the hold ended 1/1 and down/up targeted Insomnia window 292. In the 13 requested unobstructed trials, down/up targeted the popover in 13/13, Insomnia was active at the press in 13/13, and Accessibility named the popover as `AXFocusedWindow` in 13/13. AXPress on End session ended 1/1 sessions with both required log lines and SleepDisabled 0. | `evidence/control-{obstructed,clear}-probe.txt`, corresponding `*-log.txt`, `evidence/q2-*-probe.txt`, `evidence/q2-*-before-tree.txt`, `evidence/q4-axpress-*` |
| 5. Harness artifact or app problem? | The repeatable failure reproduced here is an obstruction in the test setup. Global held state and pointer stability were valid, but the reminder received the physical press. Moving that window away and reopening the popover restored the unchanged app's behavior. The 13/13 normal Popover results and 9/9 comparisons do not reproduce the reported general macOS 26 ring failure. | Controlled window-destination reversal, the four independent state probes, all requested hold logs and final-state checks |

## What intercepted the ring

The ring's Accessibility rectangle was `618,124,20,20`, so the hold point was `628,134` in top-left screen coordinates. The reminder occupied `382,118,260,364`. It covered that point. The listen-only annotated-session tap reported the window under the pointer and the handler window as 58, owned by UserNotificationCenter. The event's target process was that system app, not Insomnia. A window-list read agreed, even though Insomnia remained active and Accessibility still reported its popover as the focused window.

For example, the obstructed press at epoch `1793119664.124934` targeted process 2104, window 58. Its release also targeted window 58. After the reminder moved to `20,350`, the press at `1793119799.376326` targeted Insomnia process 7880, window 292. The same coordinate and posting method then ended the session. The later fresh-session reversal repeated both outcomes. The traces retain additional copies with target PID 0 separately. Those copies are not treated as proof of delivery to Insomnia.

The reminder requested direct screen and audio access for the remote session's process. Its only controls were Allow and Open System Settings. It exposed no Don't Allow, close or cancel control. Escape did not remove it. No permission was granted. Only its window position changed, through Accessibility inside the VM, and cleanup restored its original position. No picture of that reminder is selected for review.

The initial ring probes and the stopped first Q2 batch reproduced the old symptom: an open popover, a running header and ring, and no end log. Their obstructed takes remain under `rejected/obstructed/`. The four initial state probes remain in `evidence/` because they directly answer question 1. The original run's app-window-only picture composition could hide this obstruction, since it showed Insomnia's own window without whatever covered it.

## Which code path is implicated

`Motion.holdDuration` is 0.6 s. The Popover uses `HoldToEndButton` with its default SwiftUI `DragGesture(minimumDistance: 0)` path. Pills uses that same path. Compact and Minimal use the AppKit `StatusItemPressArea` path.

The separate probe read button state 1 during the failed obstructed holds, and pointer movement was 0 pt. The deadline checks for a held left button and movement within 12 pt therefore do not explain the repeatable failure. The observed failure happened before Insomnia's gesture could receive the press: WindowServer routed it to the covering system window. Once the press reached the popover, the same gesture and completion checks succeeded in all 13 requested trials. AXPress also confirmed that the end action and sleep restoration worked.

This is external observation of the unchanged app. It does not assert an internal call trace of `begin`, `release` or the hold task.

## Limits and setup corrections

All input was synthetic. No physical mouse, trackpad, display-sleep, Space-switch or other-display test was performed. The prior macOS 27 run passed 6/6 holds, but it used a different build and CDHash. It is comparison evidence, not an OS-only experiment. The older macOS 26.2 run's press-dismissal failure differs from this retained open-popover symptom.

The key-window observation is external. `AXFocusedWindow` pointed to the popover in all 13 normal trials, while the popover element's own `AXFocused` flag read 0. The native `NSWindow.isKeyWindow` property was not inspected inside Insomnia. Active-app and focused-window status alone did not prove that a pointer event would reach that window; the destination trace was necessary.

One extra same-popover transition retry did not end its session after the reminder moved away, despite the tap targeting Insomnia. Reopening the popover and retrying that same CLI-started session ended it, 1/1. The later fresh-session reversal then gave 0/1 obstructed and 1/1 clear. This single transition miss is retained under `rejected/transition/`, with the successful retry in `evidence/transition-reopen-*`. Its internal gesture or focus cause was not established. It is excluded from the 13 requested fresh trials and prevents claiming that every unobstructed transition works.

The earlier run did not save global event-destination traces. This run reproduced its symptom in the retained VM and identified a covering window, but cannot retroactively prove the destination of every original hold.

The first probe version tried to query the private event-source state by its global state ID. That query stalled before producing samples. A stack sample identified the stalled query, the process was stopped, and those takes were retained under `rejected/`. The corrected probe reports NSEvent, HID and combined-session state. Its four Q1 runs averaged 9.970 to 9.990 ms between samples. Observation mode can have longer gaps while reading Accessibility and window information.

A quoting error affected only the first Q1 count formatter, not the saved probe records; run.log records the corrected counts. The first extra reversal wrapper stopped on an empty filtered log, so the corrected wrapper preserves empty logs and uses fresh sessions. Q3 setup first used a status menu to open Settings while still in Popover style, which opens a popover on right-click instead. The route was corrected before a comparison hold. Pills then exposed only its status-item wrapper through Accessibility. Its ring target was verified in an item-only crop and the settled geometry before all three counted holds. Setup takes were preserved.

The 13 requested Popover holds measured 652.201 to 657.146 ms. The nine other-style holds measured 652.423 to 657.810 ms. These durations are down/up posting times. App logs have whole-second timestamps. The separate probe and event tap ran outside Insomnia, so they cannot establish the exact time its main thread read a check.

## Pictures and files

All 15 selected pictures were opened and visually reviewed. They show only Insomnia's item and its popover or Compact panel. No selected picture contains a user name, host name, address, network name, notification or another app's window. `evidence/picture-review.json` lists each selected file and its reviewed SHA-256. The blank AXPress after-picture and the setup-only Pills picture remain under `rejected/selection/`. Unmasked intermediate captures remain under rejected folders. No evidence files were deleted.

`report.md`, `run.log`, `pictures/` and `evidence/` are the review artifacts. `scripts/`, `scratch/` and `rejected/` are private working material. `scratch/vm-final/` retains the exact final VM working folder, including helper binaries and the scripts present there. `scripts/summarize.py` generated `evidence/summary.json` from the exported records.

## End state

Cleanup passed at 17:01:30Z and an independent check passed at 17:02:08Z. Insomnia is quit, Settings is closed, the entire config matches the initial defaults, `menuBarMode` is `pills`, `defaultPreset` is 14400, no session exists and SleepDisabled is 0. State reads `sleepDisabledByUs=false`, `lowPowerSetByUs=false` and an empty frozen-process list. No probe process remains. The /tmp entry set gained nothing, so no test-owned file remains there. The installed CDHash is unchanged.

The claim was released at 17:02:34Z after export. The VM remains running. Evidence is in `evidence/final-state.txt`, `evidence/final-independent-check.txt`, `evidence/config-final-diff.txt` and `evidence/claim-release.txt`.
