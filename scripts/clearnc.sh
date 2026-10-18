#!/bin/bash
# Closes notification banners and alerts on screen (Notification Center's
# Close or Clear actions), so screenshots show only the app.
for _ in 1 2 3 4; do
osascript -l JavaScript -e '
  const se = Application("System Events");
  let n = 0;
  try {
    const p = se.processes.byName("NotificationCenter");
    function walk(e, d) {
      if (d > 12) return;
      let acts = [];
      try { acts = e.actions(); } catch (x) {}
      for (const a of acts) {
        let desc = "";
        try { desc = a.description() + " " + a.name(); } catch (x) {}
        if (/Close|Clear/.test(desc)) { try { a.perform(); n++; return; } catch (x) {} }
      }
      let kids = [];
      try { kids = e.uiElements(); } catch (x) {}
      for (const k of kids) walk(k, d + 1);
    }
    for (const w of p.windows()) walk(w, 0);
  } catch (x) {}
  "closed " + n;' 2>&1
sleep 1
done
