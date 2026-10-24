// osascript -l JavaScript ax147.js MODE ARGS...: Accessibility helpers for
// the PR 147 run, over Insomnia's front window or its sheet.
//   find SCOPE TEXT ROLE   first ROLE after the element named TEXT, scrolled
//                          into view: "x y w h enabled"
//   button SCOPE NAME      the AXButton named NAME, or the sheet's last
//                          top-level button for "Done": "x y w h enabled"
//   popup PREFIX           pop-up whose name or description starts with
//                          PREFIX, scrolled into view: "name | value | enabled"
//   pick PREFIX ITEM       opens that pop-up and presses ITEM
//   menu SCOPE NAME ITEM   opens the menu button NAME and presses ITEM
//   texts SCOPE            static texts, joined by " ; "
//   rows                   the sheet's app rows: text, then pop-up value
//                          and enabled
function run(argv) {
  const se = Application("System Events");
  const proc = se.processes.byName("Insomnia");
  const w = proc.windows[0];
  function sheetOf() {
    for (const k of w.uiElements()) { try { if (k.role() === "AXSheet") return k; } catch (x) {} }
    return null;
  }
  function flat(root) {
    const out = [];
    function walk(e, d) {
      if (d > 22) return;
      let r = "", n = "", ds = "", v = "";
      try { r = e.role(); } catch (x) {}
      try { n = e.name() || ""; } catch (x) {}
      try { ds = e.description() || ""; } catch (x) {}
      try { v = String(e.value()); } catch (x) {}
      out.push({ e: e, r: r, n: n, ds: ds, v: v, d: d });
      let kids = []; try { kids = e.uiElements(); } catch (x) {}
      for (const k of kids) walk(k, d + 1);
    }
    walk(root, 0);
    return out;
  }
  function root(scope) {
    if (scope === "sheet") { const s = sheetOf(); if (!s) throw new Error("no sheet"); return s; }
    return w;
  }
  function frame(f) {
    try { f.e.actions.byName("AXScrollToVisible").perform(); delay(0.4); } catch (x) {}
    const p = f.e.position(), s = f.e.size();
    let en = ""; try { en = String(f.e.enabled()); } catch (x) {}
    return Math.round(p[0]) + " " + Math.round(p[1]) + " " + Math.round(s[0]) + " " + Math.round(s[1]) + " " + en;
  }
  function pressItem(holder, item) {
    delay(0.7);
    const items = flat(holder).filter(f => f.r === "AXMenuItem");
    const hit = items.find(f => f.n === item);
    if (!hit) return "no item " + item + " (have " + items.map(f => f.n).join(",") + ")";
    hit.e.actions.byName("AXPress").perform();
    return "ok";
  }
  const mode = argv[0];
  try {
    if (mode === "find") {
      const all = flat(root(argv[1]));
      const i = all.findIndex(f => f.n === argv[2] || f.v === argv[2] || f.ds === argv[2]);
      if (i < 0) return "none";
      const hit = all.slice(i + 1).find(f => f.r === argv[3]);
      return hit ? frame(hit) : "none";
    }
    if (mode === "button") {
      const all = flat(root(argv[1])).filter(f => f.r === "AXButton");
      let hit = all.find(f => f.n === argv[2] || f.ds === argv[2]);
      if (!hit && argv[2] === "Done" && argv[1] === "sheet") {
        const top = all.filter(f => f.d === 2);
        hit = top[top.length - 1];
      }
      return hit ? frame(hit) : "none";
    }
    if (mode === "popup" || mode === "pick") {
      const all = flat(w);
      const hit = all.find(f => f.r === "AXPopUpButton" && (f.n.startsWith(argv[1]) || f.ds.startsWith(argv[1])));
      if (!hit) return "no pop-up " + argv[1];
      try { hit.e.actions.byName("AXScrollToVisible").perform(); delay(0.4); } catch (x) {}
      if (mode === "popup") {
        let en = ""; try { en = String(hit.e.enabled()); } catch (x) {}
        return (hit.n || hit.ds) + " | " + hit.v + " | enabled " + en;
      }
      hit.e.actions.byName("AXPress").perform();
      return pressItem(hit.e, argv[2]);
    }
    if (mode === "menu") {
      const all = flat(root(argv[1]));
      const hit = all.find(f => (f.r === "AXMenuButton" || f.r === "AXPopUpButton") && (f.n === argv[2] || f.ds === argv[2]));
      if (!hit) return "no menu button " + argv[2];
      hit.e.actions.byName("AXPress").perform();
      return pressItem(hit.e, argv[3]);
    }
    if (mode === "field") {
      const hit = flat(root(argv[1])).find(f => f.r === "AXTextField" && (f.ds === argv[2] || f.n === argv[2]));
      if (!hit) return "none";
      let sub = ""; try { sub = hit.e.subrole(); } catch (x) {}
      try { hit.e.focused = true; } catch (x) {}
      delay(0.3);
      let foc = ""; try { foc = String(hit.e.focused()); } catch (x) {}
      return frame(hit) + " " + sub + " focused " + foc;
    }
    if (mode === "buttons") {
      return flat(root(argv[1])).filter(f => f.r === "AXButton").map(f => {
        let en = ""; try { en = String(f.e.enabled()); } catch (x) {}
        return (f.n || f.ds || "(no name)") + " (enabled " + en + ")";
      }).join(" ; ");
    }
    if (mode === "texts") {
      return flat(root(argv[1])).filter(f => f.r === "AXStaticText").map(f => f.n || f.v).filter(t => t && t !== "null").join(" ; ");
    }
    if (mode === "rows") {
      const out = [];
      for (const f of flat(root("sheet"))) {
        if (f.r === "AXStaticText" && f.n) out.push(f.n);
        if (f.r === "AXPopUpButton") { let en = ""; try { en = String(f.e.enabled()); } catch (x) {} out.push("[" + f.v + ", enabled " + en + "]"); }
      }
      return out.join(" ");
    }
  } catch (x) {
    return "error: " + x;
  }
  return "unknown mode " + mode;
}
