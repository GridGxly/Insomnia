#!/usr/bin/env python3
"""holdstrip.py OUT.png LABEL=DIR...: one row per grab folder. Each tile is
one value the countdown settled on (shown at least 300 ms), with how long it
stayed on screen; a value shown longer than 1.4 s is labeled in red. Values
are compared on the text area as in ticks.py (fewer than 5 pixels differing
by more than 40 levels counts as the same image), so the animation frames
between two values are left out."""
import os, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ticks_lib

FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

def same(a, b):
    return sum(1 for j in range(len(a)) if abs(a[j] - b[j]) > 40) < 5

out, specs = sys.argv[1], sys.argv[2:]
tmp = tempfile.mkdtemp()
rows = []
for k, spec in enumerate(specs):
    label, d = spec.split("=", 1)
    ms, fr = ticks_lib.frames(d)
    runs = []  # [first index, last index]
    for i in range(len(fr)):
        if runs and same(fr[runs[-1][0]], fr[i]):
            runs[-1][1] = i
        else:
            runs.append([i, i])
    settled = []
    for a, b in runs:
        if ms[b] - ms[a] >= 300:
            if settled and same(fr[settled[-1][0]], fr[a]):
                settled[-1][1] = b
            else:
                settled.append([a, b])
    tiles = []
    for n, (a, b) in enumerate(settled):
        # Shown until the next settled value starts (or the capture ends).
        end = ms[settled[n + 1][0]] if n + 1 < len(settled) else None
        dur = (end - ms[a]) / 1000.0 if end is not None else None
        mid = (a + b) // 2
        src = os.path.join(os.path.abspath(d), "%06d.png" % ms[mid])
        tile = os.path.join(tmp, "t%d_%d.png" % (k, n))
        if dur is None:
            text, color = "end of capture", "gray"
        elif n == 0:
            text, color = "start of capture", "gray"
        else:
            text, color = "%.1f s" % dur, ("red" if dur > 1.4 else "black")
        f = BOLD if color == "red" else FONT
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-vf",
                        "crop=100:30:150:0,scale=200:60:flags=lanczos,pad=200:92:0:0:white,"
                        "drawtext=fontfile='%s':text='%s':fontcolor=%s:fontsize=20:x=(w-tw)/2:y=66" % (f, text, color),
                        tile], check=True)
        tiles.append(tile)
        print(label, n, "%d ms" % ms[a], text)
    lab = os.path.join(tmp, "l%d.png" % k)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "color=white:s=270x92", "-frames:v", "1", "-vf",
                    "drawtext=fontfile='%s':text='%s':fontcolor=black:fontsize=20:x=10:y=(h-th)/2" % (BOLD, label), lab], check=True)
    args = ["-i", lab]
    for t in tiles:
        args += ["-i", t]
    n = len(tiles) + 1
    filt = "".join("[%d]pad=iw+6:ih:0:0:white[p%d];" % (i, i) for i in range(n)) + \
           "".join("[p%d]" % i for i in range(n)) + "hstack=inputs=%d,pad=2000:ih+6:0:0:white" % n
    row = os.path.join(tmp, "r%d.png" % k)
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args + ["-filter_complex", filt, row], check=True)
    rows.append(row)
args = []
for r in rows:
    args += ["-i", r]
if len(rows) == 1:
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", rows[0], out], check=True)
else:
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args + ["-filter_complex",
                    "".join("[%d]" % i for i in range(len(rows))) + "vstack=inputs=%d" % len(rows), out], check=True)
print("wrote", out)
