## MacBook run on macOS 26.2 at 650c666: the Popover style

Sessions work in the Popover style, but using the popover itself mostly fails on this Mac.

What works:
- The chips start a session, and +30m and Custom extend it.
- The countdown in the bar changes once a minute.
- The sleep check sets SleepDisabled again, both in Popover and in Pills.
- A style change during a session keeps the session.
- Pills, Compact and Minimal behave as they did at `ae56a954`.

What fails, when the popover is Insomnia's only window:
- A click or a hold inside the popover closes it and gives focus back to the app behind it. A chip's action still runs. But Custom, the fields and the end ring cannot be used with the pointer.
- Holding the ring never ended a session (0 of 5 holds).
- Custom never puts the cursor in Hours.
- Esc closes the popover only when a field has the cursor.

With the Settings window open, the same clicks mostly work: 19 of 21 clicks and 9 of 10 holds. All input was synthetic (see below), and the Compact panel, the pills, the menu and Settings took the same input normally.

**Setup.** This was an unattended run on the owner's MacBook Pro (M5), macOS 26.2 (25C56), on 27 October 2026, from 13:38Z to 14:31Z. The Mac was on AC power at 100%, with a dark menu bar and the built-in display only. The commit `650c666b` (integration/menu-bar-popover) was installed with `scripts/install.sh` from a clean checkout. This is the normal build, not the lid simulation build. `config.json` was moved aside first, so the app started from its defaults. A broader temporary sudo rule was present on the Mac during the run, so install.sh's sudo check could not fail. After the install, `/etc/sudoers.d/insomnia` held exactly the four NOPASSWD lines for `pmset -a disablesleep 1`, `pmset -a disablesleep 0`, `pmset -b lowpowermode 1` and `pmset -b lowpowermode 0`. install.sh exited 0 in 17 s. The CDHash is `d05b3f0d2a7891c01069f6161dcba39cb1f8e48a`, and the first launch wrote `menuBarMode: "pills"`. Each style was picked in Settings > General > Menu bar.

Nobody could touch the trackpad or keyboard during the run. Clicks, holds and keys were synthetic events posted at the HID level. Where the pointer could not reach a control, the step used the control's Accessibility action, and the table says so.

insomnia.log stamps whole seconds only. Times with milliseconds come from three sources: a read of insomnia.log every 10 ms that noted when each line appeared, pictures of Insomnia's item and popover every 100 to 135 ms, and reads of the popover's controls through Accessibility every 50 or 100 ms.

| Step | Result at `650c666b` |
|---|---|
| P1, picker | Menu bar shows Popover, with the line "The eye and its countdown. Any click opens a popover." The item becomes the closed eye alone, 26 pt. |
| P1, open and close | A left click opens the popover under the eye, and a second left click closes it. A right click opens it, and so does a Control-click. No menu appears with either. |
| P1, idle popover | "Not keeping your Mac awake", the chips 30m to 3d, and Custom. The rows read Lid open, "100% · On power adapter", Hotspot failover off and Wi-Fi On (no network name). Settings… and Quit Insomnia are at the bottom. |
| P1, Esc | **Fails.** Esc leaves the popover open. It was sent through System Events and at the HID level, with the fields hidden or out (13:41:01Z to 13:41:33Z, 13:52:56Z, 14:28:01Z). Esc closed it only once a field had the cursor (14:27:57Z, Settings window open). |
| P1, a click inside | **Fails.** With no other Insomnia window open, a click on Custom or on the header text closes the popover, and Finder or TextEdit comes back in front. From 13:42Z to 14:08Z, about 33 such clicks were tried and one worked (13:46:35Z). After 14:15Z, 1 of 6 worked, the first one after the Settings window closed. A listening event tap saw two copies of each failing mouse-down: one for Insomnia and one with no target app (pid 0). The click that worked at 13:46:35Z came as one copy. A click at the same spot on Insomnia's Settings window, moved there for the test, reached that window. |
| P2, open over TextEdit | The empty TextEdit document is in front, then the eye is clicked. Insomnia becomes the active app, but System Events still names TextEdit frontmost. |
| P2, Custom and 3 | **Fails.** The click on Custom closed the popover, and TextEdit came back in front. With the fields put out through Accessibility, a typed 3 reached neither Hours nor the document, which stayed empty. |
| P2, Esc, then k | **Fails** for Esc, which left the popover open. After a click on the eye closed it, k reached the document ("k"). |
| P2, a click on the bar | Passes. A click on an empty part of the bar (980,16) closes the popover. TextEdit is in front, and k reaches it ("kk"). |
| P2, Settings window open | The first try (14:16:59Z, TextEdit in front before the eye click) failed: the click on Custom closed the popover. The second (14:27:52Z, TextEdit had quit by then) worked. The click on Custom brings the fields out, a click in Hours puts the cursor there, 3 fills Hours and Start turns blue. Esc then closes the popover. |
| P3, start from 1h | The click starts the session: "session started until 14:54:22Z (3600s requested)" (stamped 13:54:27Z). SleepDisabled read 1 at 13:54:24Z. The popover closed with the click. The bar shows the eye and 59m, 57 pt. Reopened, the header reads "Awake until 7:54 AM, 57m left". |
| P3, 130 s of the bar | The popover was closed from 13:57:21Z to 13:59:33Z, with one sample a second. The width stayed 57 pt. The text changed only at 13:57:23Z (56m), 13:58:23Z (55m) and 13:59:23Z (54m). OCR read no text in the first sample. |
| P4, +30m | The click logs "session extended by 1800s until 15:24:22Z" at 14:00:05Z. The header reads "Awake until 8:24 AM, 1h 24m left", and the bar "1h 24m", 76 pt. The popover closed with the click. |
| P4, Custom 15, Return | **Fails** with the pointer: the click on Custom closed the popover, and so did a click in Minutes. Through Accessibility (Custom pressed, 15 set in Minutes), Return logs "session extended by 900s until 15:39:22Z" at 14:00:19Z. The popover stays open and the fields go away. The header reads "Awake until 8:39 AM, 1h 39m left", and the bar "1h 39m". |
| P5, quick click on the ring | A 90 ms click logs nothing, and the end time stays 15:39:22Z. The popover closed with the click. |
| P5, full hold, Settings closed | **Fails**, 0 of 5. Two 0.9 s holds (14:01:12Z, 14:01:23Z) and three 0.65 s holds (14:16:22Z to 14:16:34Z) were tried. Each time the popover closed, and the session kept running with no log line. In the three timed holds, the popover was gone about 200 ms after the hold began, well before the 0.65 s were up. |
| P5, full hold, Settings open | 9 of 10 ended the session: 4 of 5 at 0.65 s and 5 of 5 at 1.5 s. The miss was the first, a 0.65 s hold at 14:10:44Z, where the popover closed. A hit logs "session end (user)", "sleep restored" and "notify: Session ended - Ended by you. Sleep is back to normal." with SleepDisabled 0. The popover stays open on the idle view. |
| P5, the ring's Accessibility action | AXPress on End session at 14:01:59Z logs the same three lines. SleepDisabled reads 0, and the eye closes. |
| P5, hold cut by a right-click | The first try (14:01:46Z, Settings closed) does not count, since with Settings closed the mouse-down on the ring already closes the popover (row above). Repeated twice with Settings open (14:30:33Z, 14:30:41Z), the popover closes at the right-click on the bar. The session keeps running (end time 16:30:23Z, no end line), and reopened, the ring is at rest. |
| P5, the arrow after an end | When a session ends with the popover open, the item shrinks from 76 to 26 pt but the popover stays at x 1036. Its arrow then points about 50 pt left of the eye (14:01:59Z, 14:06:57Z and 14:10:49Z). A new open centers it again. |
| P6, Custom | **Fails.** With Settings closed, the click on Custom closed the popover (14:02:38Z). With Settings open, the click brings the fields out, but the cursor is not in Hours. No caret shows, and Accessibility reports the popover itself as focused. A typed 3 lands nowhere (14:29:06Z, 14:29:11Z). |
| P6, 24 in Hours | With Hours focused through Accessibility, 24 typed gives Hours a red border. Start stays grey (disabled), and Return starts nothing. |
| P6, 2 in Hours, Return | Start turns blue. Return logs "session started until 16:02:48Z (7200s requested)" (stamped 14:02:54Z). The popover stays open with "Awake until 9:02 AM, 1h 59m left". |
| P7, Popover | `sudo -n pmset -a disablesleep 0` ran at 14:05:16.547Z, and `pmset -g` read SleepDisabled 1 again 8.6 s later. The log shows "sleep check: SleepDisabled reads 0 during the session; setting it again" at 14:05:24Z and "sleep check: SleepDisabled set again" at 14:05:29Z. After the end at 14:06:57Z (P8), SleepDisabled read 0, and still 0 at 14:08:00Z. |
| P7, Pills | The same command ran at 14:18:36.963Z, and SleepDisabled read 1 again after 16.1 s. The two log lines came at 14:18:52Z and 14:18:57Z. After the end by hold at 14:19:34Z, SleepDisabled read 0, and still 0 at 14:20:36Z. |
| P8, `--session end` with the popover open | Sent at 14:06:57.134Z, it exits 0 at .298Z and prints the status after the end: "no session is running", as at `ae56a954`. "session end (user)" appeared at 57.158Z, and "sleep restored" with the notify line at 57.184Z (26 ms). |
| P8, the frames | 34 frames, 103 to 131 ms apart, from 14:06:56.254Z to 14:07:00.321Z. The frame at 57.102Z shows "Awake until 9:02 AM, 1h 55m left", and the next, at 57.219Z, "Not keeping your Mac awake". No frame shows Ending…, which is too short to catch at this rate. The popover stays open. |
| P9, Pills | Switched from Popover, the picker line reads "Duration pills and the countdown beside the eye." Idle, the eye is alone, 34 pt. A left click opens Days, Hours and Minutes on Hours (228 pt). 2 and Return log "session started until 16:18:15Z (7200s requested)", and the bar shows the eye, 1:59:53 and the ring, 120 pt. A 1.5 s hold logs "session end (user)" at 14:19:34.949Z and "sleep restored" at 34.982Z, and the bar is back to 34 pt. A right click opens the menu. Same as at `ae56a954`. |
| P9, Compact | The picker line reads "Only the eye. A click opens the pills in a panel." Idle, the eye is alone, 34 pt. A click opens the panel on Days, Hours and Minutes. 2 and Return log "session started until 16:20:52Z (7200s requested)", and the panel shows 1:59:54 and the ring. A quick click on the ring logs nothing and keeps the end time. A 0.65 s hold logs "session end (user)" at 14:21:03.259Z and "sleep restored" at 03.294Z. The panel stays open on the pills. Same as at `ae56a954`. |
| P9, Minimal | The picker line reads "A ring for the time left. Click adds, hold ends." 30m and Return in Default session length save `defaultPreset: 1800`. One click logs "session started until 14:52:43Z (1800s requested)", and the arc shows around the eye, 34 pt. A 0.65 s hold logs "session end (user)" at 14:22:51.586Z and "sleep restored" at .611Z, with no "session extended" line. Same as at `ae56a954`. Default session length was set back to 4h (14400) after. |
| P9, Popover again | Popover was picked again, and a left click opens the popover (14:23:36Z). Switched from Popover to Compact (14:23:43Z), a left click opens the panel, and a right click opens the menu (the Lid and Wi-Fi lines, Settings…, Quit Insomnia). Pills was picked from Popover at 14:18:07Z (the Pills row) and from Compact at 14:24:01Z. Both times a left click opens the pills, and a right click opens the menu. |
| P9, test mistake | In the first Minimal try (14:21:31Z), the Settings window did not open, so those steps ran in Compact. Nothing was logged and the config did not change. The try was rerun, and the Minimal row is from the rerun. |
| P10, one 2 h session | The click on the 2h chip at 14:08:47Z set the end to 16:08:47Z. The style went Popover, Pills, Compact, Minimal, Popover between 14:09:01Z and 14:09:22Z. The end time stayed 16:08:47Z, and Insomnia had one menu bar item at each step. No log line at all appeared from the first switch to the last. The bar showed: Pills, 1:59:41 and the ring, 120 pt; Compact, the eye alone; Minimal, the arc; Popover, the eye and 1h 59m. |
| P10, open popover on a switch | The popover was open when Pills was picked. It was still there at 14:09:04.952Z and gone at 05.056Z, before the pick finished at 05.792Z. |
| End state | No session, SleepDisabled 0, and Low Power Mode off on battery and AC as before the run. No process is stopped that was not stopped before. `config.json` matches the launch defaults (`menuBarMode: "pills"`, `defaultPreset: 14400`). TextEdit's document was closed without saving, and TextEdit quit. A picture opened in Preview by mistake at 14:28:14Z was closed, and Preview quit. `650c666b` stays installed, and the sudoers file still holds the four lines. |

### A likely cause, from the code

In `watchForDismissal`, the global mouse-down monitor calls `dismissUnlessOnItem`, which skips only the item's frame. A copy of a click inside the popover that goes outside the app, such as the one with no target app above, would close the popover and give focus back. Custom's focus is set in `focusHoursIfOut` on the `customShown` change, possibly before the fields exist. These are readings of the code. They were not tested.

### Pictures

- P1: `P1/P1-pills-idle-before.png`, `P1/P1-pills-menu-before.png`, `P1/P1-picker-pills.png`, `P1/P1-picker-popover.png`, `P1/P1-popover-idle-bar.png`, `P1/P1-popover-idle.png`, `P1/P1-after-second-left-click.png`, `P1/P1-right-click-open.png`, `P1/P1-control-click-open.png`, `P1/P1-popover-custom-out-after-esc.png` (still open after Esc).
- P2: `P2/P2-open-over-textedit.png`, `P2/P2-custom-out.png`, `P2/P2-after-typed-3.png` (Hours empty, Start dim), `P2/P2c-typed-3.png` (Settings open: 3 in Hours).
- P3: `P3/P3-popover-running.png`, `P3/P3-bar-running.png`.
- P4: `P4/P4-before-extend.png`, `P4/P4-after-30m.png`, `P4/P4-custom-15.png`, `P4/P4-after-custom-15.png`, `P4/P4-bar-after.png`.
- P5: `P5/P5-before.png`, `P5/P5-bar-after.png` (still running after the holds), `P5/P5-after-ax-end.png` (the arrow off the eye), `P5/P5-bar-after-end.png`, `P5/P5j-reopened-after-interrupted-hold.png`.
- P6: `P6/P6b-custom-clicked.png` (no caret), `P6/P6-custom-out.png`, `P6/P6-hours-24.png`, `P6/P6-hours-2.png`, `P6/P6-running-2h.png`, `P6/P6-bar-running-2h.png`.
- P8: `P8/P8-before.png`, `P8/P8-burst-sheet.png`, which shows the frames from 14:06:56.850Z to 57.468Z with their times. `P8/P8-frame-before-end.png` and `P8/P8-frame-after-end.png` are the frames at 57.102Z and 57.219Z.
- P9, Pills: `P9/P9-pills-picker.png`, `P9/P9-pills-idle.png`, `P9/P9-pills-open.png`, `P9/P9-pills-typed-2.png`, `P9/P9-pills-running-2h.png`, `P9/P9-pills-after-end.png`, `P9/P9-pills-menu.png`.
- P9, Compact: `P9/P9-compact-picker.png`, `P9/P9-compact-idle.png`, `P9/P9-compact-panel-open.png`, `P9/P9-compact-running.png`, `P9/P9-compact-after-hold.png`.
- P9, Minimal: `P9/P9-minimal-picker.png`, `P9/P9-minimal-idle.png`, `P9/P9-minimal-arc-start.png`, `P9/P9-minimal-after-end.png`.
- P9, Popover again: `P9/P9-popover-again-open.png`, `P9/P9-after-popover-compact-left.png`, `P9/P9-after-popover-compact-menu.png`, `P9/P9-after-popover-pills-left.png`, `P9/P9-after-popover-pills-menu.png`.
- P10: `P10/P10-popover-open-before-switch.png`, `P10/P10-pills.png`, `P10/P10-compact.png`, `P10/P10-minimal.png`, `P10/P10-popover.png`.

The item pictures cover the status item's own frame across the bar's height. The popover, panel or menu in each picture comes from a capture of Insomnia's windows only, so nothing behind them shows. The P8 frames after the end also show the bar's Wi-Fi icon, which moves into the item's old place.

Evidence: `run.log` (lines from 13:38:17Z to 14:31:09Z), `insomnia-run.log`, `P0/install.log`, `P0/sudoers-after-install.txt`, `P0/config.defaults.json`, `P2/p2-activations.txt`, `P3/p3-bar-130s.txt`, `P7/p7-popover-pmset.txt`, `P7/p7-pills-pmset.txt`, `P8/p8-log.txt`, `P8/burst/times.txt`, `P8/burst-ocr.txt`, `P9/p9-pills-end-log.txt`, `P9/p9-compact-end-log.txt`, `P9/p9-minimal-end-log.txt`, `P10/p10-to-Pills-axpop.txt`, `P5/p5j-1-axpop.txt`.

### Limits

- No real trackpad or keyboard input was possible. The popover's failures showed with every way of posting events that was tried. These were warped and gliding clicks, rests of 0 to 600 ms before the press, the HID and session event taps, and a HID-state source. A click by hand was not tried. The Compact panel, the pills, the menu and Settings took the same events normally.
- Why the Settings window being open matters was not worked out. The counts are what was seen.
- In P4 and P6, the Custom fields were filled through Accessibility where pointer clicks closed the popover.
- Ending… was not seen in the popover. The end took 26 ms, under one frame.
- Display sleep was not tried, since the display must not sleep tonight.
- The battery row was seen on AC only ("100% · On power adapter"). The Mac stayed on AC.
- macOS 27 and a light menu bar were not tried.
- Reduce Motion was not tried.
- A looping LaunchDaemon for the sleep check was not tried.
- An end that waits for its retry (a busy recovery lock) was not set up.
- Test mistakes, none of them product failures:
  - P1: the first Control-click was not sent, and it was rerun at 13:40:59Z. The click on Custom at 13:41:51Z was not sent either; the run log corrects it.
  - P3: the first 130 s record ran with the popover open by mistake and is not used. The valid record is `P3/p3-bar-130s.txt`.
  - P5: the frame recording failed to start for the two 0.9 s holds, so those holds have no frames.
  - P9: the first Minimal try ran in Compact (row above) and was rerun.
  - At the end, a q meant for Command-Q went into TextEdit's save sheet as text. The sheet's Delete then removed the unsaved document, so nothing was saved.
- Other displays and a Space change were not tried.
- Steps ran once, except where counts are given.
