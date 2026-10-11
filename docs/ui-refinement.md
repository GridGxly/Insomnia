# Menu bar and settings

Left-click the eye or countdown for quick actions. The 30m, 1h, 2h and 4h
buttons start a session or add time. Right-click or Control-click toggles the
configured default duration, initially four hours. Settings > General manages
presets and the default. The existing hold-to-end control remains available.

Settings is a resizable window with General, Lid actions and Advanced pages.
Command-1, Command-2 and Command-3 switch pages. Secondary options use
disclosures, and app lists initially show four names. Native Liquid Glass,
system fonts and adaptive materials provide the appearance. Reduce Motion
uses opacity transitions for the eye and countdown.

AppKit still owns the status item and settings window. SwiftUI draws their
content; the existing SessionManager, configuration store, journal and
recovery services own lifecycle and persistence. The countdown is isolated
from the eye and controls. Password reads and app scans run only when their
settings are visible; resolved app names are cached. No performance benchmark
or percentage speedup is claimed. No dependencies were added.

## Preview

Run `./scripts/preview-app.sh` with an Xcode toolchain that supports Swift 6.2.
The separate debug bundle uses temporary data and fixture power, process,
backstop, login-item and password services. Its timer does not prevent sleep.
Production release builds exclude this preview mode.

Optional flags:

- `--ui-preview-menu`: show the same quick menu in a regular window.
- `--ui-preview-light`: force light appearance in the preview.
- `--ui-preview-compact`: use a consistent 740 by 540 content size.
- `--ui-preview-popover`: open the actual status-item popover after launch.
- `--ui-preview-active`: start a fixture session before opening that popover.

Quit the existing preview before rebuilding. [Dark menu](assets/ui/menu-dark.png),
[dark settings](assets/ui/settings-dark.png) and
[light settings](assets/ui/settings-light.png) are native captures from the
isolated preview. The title-bar sharing indicator belongs to macOS.

## Validation limits

Native checks covered quick start, extension, ending, settings navigation,
disclosures, app selection and preset editing in the fixture environment.
Actual Command-drag and saved-position persistence need a manual macOS check.
Gesture forwarding has unit coverage. Real power and lid-close behavior were
not exercised by the preview. The menu hides debug build notices but retains
recovery warnings; simulation builds still identify themselves in logs.
