# Evidence index

- `summary.json` contains all state-probe metrics, posting durations, event destinations and result counts.
- `q1-*-probe.txt` contains the four calibration traces. Mouse coordinates use NSEvent's bottom-left origin, so the ring is 628,634 on the 768 pt screen.
- `q2-results.csv` and `q3-results.csv` contain the requested per-trial counts. Their matching logs contain each successful end and sleep restoration.
- `control-obstructed-*` and `control-clear-*` contain the fresh-session reversal. CG event coordinates use a top-left origin, so the same ring point is 628,134.
- `q2-*-probe.txt` contains listen-only event delivery, active-app status and external focus observation at the press. Matching tree dumps identify the focused window as AXPopover.
- `q4-axpress-*` records the successful Accessibility control.
- `transition-reopen-*` records the successful retry after the additional transition miss retained under rejected/transition.
- `picture-review.json` lists the 15 opened and reviewed pictures with their hashes.
- `final-state.txt`, `final-independent-check.txt`, `config-final-diff.txt` and `claim-release.txt` record cleanup and release.
