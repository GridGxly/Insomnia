#!/usr/bin/env python3
"""timestrip.py OUT.png DIR START_MS END_MS STEP_MS COLS: the countdown area
(x 150..250 of the 300x30 capture, 2x) at fixed times, each labeled with its
time since the capture started."""
import os, subprocess, sys, tempfile
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
out, d, start, end, step, cols = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:7])
ms = sorted(int(f[:-4]) for f in os.listdir(d) if f.endswith(".png"))
tmp = tempfile.mkdtemp()
tiles = []
for n, t in enumerate(range(start, end + 1, step)):
    m = max(x for x in ms if x <= t)
    tile = os.path.join(tmp, "%03d.png" % n)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(d, "%06d.png" % m), "-vf",
                    "crop=100:30:150:0,scale=200:60:flags=lanczos,pad=200:88:0:0:white,"
                    "drawtext=fontfile='%s':text='%.1f s':fontcolor=black:fontsize=20:x=(w-tw)/2:y=64" % (FONT, t / 1000.0),
                    tile], check=True)
    tiles.append(tile)
rows = (len(tiles) + cols - 1) // cols
subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "1", "-i", os.path.join(tmp, "%03d.png"), "-vf",
                "tile=%dx%d:padding=6:color=white" % (cols, rows), "-frames:v", "1", out], check=True)
print("wrote", out, len(tiles), "tiles")
