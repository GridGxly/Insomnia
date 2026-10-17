#!/usr/bin/env python3
"""settled.py OUT.png DIR...: one row per grab folder, showing the countdown
value each tick settled on (the frame 30 ms before the next tick, and the
last frame). Ticks are found as in ticks.py. Crop x 150..250, 2x."""
import os, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ticks_lib

out, dirs = sys.argv[1], sys.argv[2:]
rows = []
tmp = tempfile.mkdtemp()
COLS = 12
for k, d in enumerate(dirs):
    ms, ticks = ticks_lib.ticks_of(d)
    names = sorted(f for f in os.listdir(d) if f.endswith(".png"))
    picks = [ms[0]]
    for t in ticks[1:] + [ms[-1] + 31]:
        cand = [m for m in ms if m <= t - 30]
        if cand:
            picks.append(cand[-1])
    lst = os.path.join(tmp, "l%d.txt" % k)
    with open(lst, "w") as f:
        for m in picks:
            f.write("file '%s'\n" % os.path.join(os.path.abspath(d), "%06d.png" % m))
    row = os.path.join(tmp, "r%d.png" % k)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst,
                    "-vf", "crop=100:30:150:0,scale=200:60:flags=lanczos,tile=%dx1:padding=4:color=white" % COLS,
                    "-frames:v", "1", row], check=True)
    rows.append(row)
    print(d, "settled at (ms):", picks)
args = []
for r in rows:
    args += ["-i", r]
subprocess.run(["ffmpeg", "-v", "error", "-y"] + args + ["-filter_complex",
                "".join("[%d]" % i for i in range(len(rows))) + "vstack=inputs=%d" % len(rows), out], check=True)
print("wrote", out)
