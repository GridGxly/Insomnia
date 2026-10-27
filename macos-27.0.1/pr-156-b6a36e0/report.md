# One-click re-check on macOS 27.0.1

All requested behavior checks passed. Immediate Option release passed 12/12, compared with 1/6 primary trials and 0/5 alternate retries in the previous build. The exposed AXPress action still does nothing in Pills and Compact, the known gap from the previous run. No accepted trial logged the late-click fallback.

Nothing was posted or pushed. All input, Accessibility work and captures occurred inside the claimed test VM. The owner's MacBook UI, installed Insomnia and config were untouched. No VM was started, stopped, cloned or deleted. Other test folders were left untouched.

## Setup

Target commit `b6a36e0de3a74847f07767de16406754c825944e`, branch `integration/menu-bar-oneclick`. The previous run's report, run log and scripts, the diagnostic helper and the target commit's specification and release checks were read. Needed helpers were copied and adapted in this run's folder. The source checkout and previous run folders were unchanged.

The VM ran macOS 27.0.1, build 26A434, at 1440 × 900 and scale 1. Required Accessibility and capture permissions were already available. Window checks found no system prompt covering accepted input targets. No permission was granted.

The staged ZIP matched SHA-256 `b4379f0a05a5db3787209cc6b3c1f12f17d9c9ff08137a23dd7a4834be60d007`. It was extracted with ditto outside /tmp. Existing config.json was moved aside. The target commit's own archived `scripts/install.sh --app <bundle>/Insomnia.app --allow-unverified-origin` completed with exit 0. Its bytes match the target git object. The installed CDHash was `a6e694ef8ea5fbb85c86c94a920fea3762acbded`, also verified after cleanup. The staged ZIP was left unchanged.

First launch wrote fresh defaults. Settings enabled "Start a session with one click" and set the default length to 10 minutes through Minimal's editable field. Pills was then selected and asserted. Config and the [reviewed Settings picture](pictures/setup-settings.png) confirm `oneClickStart=true`, `defaultPreset=600`, `sessionSounds=false` and `defaultFocusField="hours"`. Sounds remained off.

## Checks and counts

A no-start result required no session.json, SleepDisabled 0 and zero new "session started" lines after at least three seconds. Confirmed starts were checked for exactly 600 seconds, SleepDisabled 1 and closed controls. Any session surviving a check was ended through the command line and sleep restoration was checked.

| Check | Result and counts | Evidence under evidence/ |
|---|---|---|
| 1. Option in Pills and Compact | Pass, 16/16. Immediate release 12/12, three trials per style per posting method. Option held 500 ms after release 2/2. Mouse-event flags alone 2/2. Controls opened and nothing started. | `c1-*`; `immediate-timing-audit.json`; [Pills picture](pictures/c1-Pills-immediate-hid-1.png), [Compact picture](pictures/c1-Compact-immediate-hid-1.png) |
| 2. No kept keys | Pass, 2/2. Esc closed the preceding controls. A plain click started 600 seconds and opened nothing in each style. | `c2-*-plain-after-option-*` |
| 3. Popover Option and plain clicks | Pass, 4/4. Flags-only, wrapped Option key events and Option held through the system each opened the popover without a start. A plain click then started 600 seconds and opened nothing. | `c3-Popover-*`; [Popover picture](pictures/c3-Popover-option-flags.png) |
| 4. Context menus | Pass, 11/11. Two right-clicks and one Control-click per style passed 9/9 across Pills, Compact and Minimal. One menu was observed, no session started, and Esc closed it. Plain left-click dismissal at the exposed eye passed 2/2 in Pills and Compact. | `c4-*`; [Menu picture](pictures/c4-Pills-right-1.png) |
| 5. Popover right and Control toggles | Pass, 2/2 pairs, 4/4 actions. The first click opened and the second closed the popover. Nothing started. | `c5-Popover-*` |
| 6. Minimal hold | Pass, 1/1. A confirmed 7200-second command-line session ended after an 800 ms eye hold. One user end, one sleep restoration, no session and SleepDisabled 0. The mixed-button hold was skipped as requested. | `c6-Minimal-plain-hold-*` |
| 7. Holds end sessions | Pass, 2/2 start/end pairs. Both styles started 600 seconds with one click. A 650 ms hold on the end control produced one user end, one sleep restoration, no session and SleepDisabled 0. | `c7-{Pills,Compact}-*` |
| 8. Accessibility press | Known gap reproduced, 2/2. Each eye advertised AXPress. Performing it once with no modifier held returned success but caused no session, controls or menu. | `c8-*-AXPress-*`; action evidence linked below |
| Cleanup | Pass. Full fresh defaults, app quit, Settings closed, no session, SleepDisabled 0 on three independent reads, unchanged CDHash, no temporary entries created or modified during the run, own claim released and VM left running. | `final-state.txt`, `final-independent-check.txt`, `claim-release.txt` |

All 44 accepted result records are in [results.tsv](evidence/results.tsv). Each has delivery times and flags, a window-under-pointer record, Accessibility state, power state and full trial log. [summary.json](summary.json) checks the evidence counts, immediate-release timing, single-menu window IDs, action results, final config and reviewed picture hashes.

## Findings and comparison

The immediate-release failure seen at `08ee3e0f` did not reproduce. All 12 current trials passed with Option present on both delivered mouse events and released 0.109 to 0.500 ms after mouse-up. The helper requested 90 ms clicks; delivered holds ranged from 90.79 to 101.12 ms because of scheduling. Both posting methods passed in both styles. See the [timing audit](evidence/immediate-timing-audit.json), [Pills primary delivery](evidence/c1-Pills-immediate-hid-1-delivery.txt) and [Compact alternate delivery](evidence/c1-Compact-immediate-session-1-delivery.txt).

The exposed AXPress gap is unchanged. The action list contains AXPress and the action returns code 0. All standard modifier-key bits are clear. The raw event flag value is 536870912 in both trials. The three-second observation shows no session, SleepDisabled 0 and no opened controls. See [Pills actions](evidence/c8-Pills-AXPress-actions.txt), [Pills action result](evidence/c8-Pills-AXPress-events.txt), [Compact action result](evidence/c8-Compact-AXPress-events.txt) and their matching AX, state and log records. This records the available Accessibility element; physical VoiceOver behavior remains untested.

Full trial logs were searched after every observation, retaining lines containing "status item". None contains "status item: a click handled late counts as an Option-click". The stall fallback was not exercised by this run. The other accepted behavior results match the previous run's valid checks. Minimal's ordinary hold passed again.

## Exclusions and limits

A premature check began while Settings setup was still in progress, leaving Minimal selected when the helper expected Pills. That check was stopped and any surviving session was ended. Its takes and ledger are preserved under `rejected/setup-overlap/` and excluded from all counts above. Setup was repeated sequentially. Every accepted style selection was then asserted against config before trials began. A subsequent setup retry found the default already set to 10 minutes and was made idempotent. These were setup errors, not app findings.

The hold-through-right-click test was deliberately skipped because macOS 27 does not deliver that right press while left is held, as established by the earlier diagnostic run. No attempt was made to treat it as an app regression.

Input was synthetic. Physical mouse, trackpad and VoiceOver behavior were not tested. The delivery trace observes system event delivery rather than the app's internal modifier values. App log timestamps have whole-second precision. The tested subset does not cover every release check, appearance or motion setting.

All 7 selected pictures were opened and visually reviewed. Each contains only Insomnia's item, controls, menu, popover or Settings, with no private identifier, network name, notification or other app window. [picture-review.json](picture-review.json) records their hashes. Rejected takes and unredacted working material remain under rejected/. Scripts, scratch data and source archive are private working material. The report, run log, sanitized evidence, selected pictures, summary and picture review are review artifacts.

## End state

The full final config equals fresh first-launch defaults, including `menuBarMode="pills"`, `oneClickStart=false`, `sessionSounds=false`, `defaultFocusField="hours"` and `defaultPreset=14400`. Insomnia is quit, Settings is closed, no session remains and SleepDisabled is 0. The journal records no outstanding sleep ownership, Low Power Mode ownership or frozen processes. The temporary-directory audit found nothing created or modified during the run. The claim was released and the VM was left running. See the [independent final check](evidence/final-independent-check.txt) and [claim release](evidence/claim-release.txt).
