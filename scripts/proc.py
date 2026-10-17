#!/usr/bin/env python3
"""proc.py DIR NAME OUTDIR: turn grab's screenshots into evidence.

DIR holds PNGs named by milliseconds since the first shot. Collapses runs of
identical images, prints how many distinct images there were and when each
appeared, then writes NAME.gif (real timing, 3x) and NAME-sheet.png (the
distinct images, 3x, in order, up to 24).
"""
import os, subprocess, sys, tempfile

src, name, out = sys.argv[1], sys.argv[2], sys.argv[3]
files = sorted(f for f in os.listdir(src) if f.endswith(".png"))
ms = [int(f[:-4]) for f in files]
# One md5 per decoded image, in file order.
lst = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False)
for f in files:
    lst.write("file '%s'\n" % os.path.join(os.path.abspath(src), f))
lst.close()
r = subprocess.run(["ffmpeg", "-v", "error", "-framerate", "100", "-pattern_type", "glob",
                    "-i", os.path.join(os.path.abspath(src), "*.png"),
                    "-fps_mode", "passthrough", "-f", "framemd5", "-"], capture_output=True, text=True, check=True)
hashes = [l.split(",")[-1].strip() for l in r.stdout.splitlines() if l and not l.startswith("#")]
assert len(hashes) == len(files), (len(hashes), len(files))
runs = []  # (start ms, file, hash)
for t, f, h in zip(ms, files, hashes):
    if not runs or runs[-1][2] != h:
        runs.append((t, f, h))
span = (ms[-1] - ms[0]) / 1000.0
print("%s: %d screenshots over %.2f s (one every %.1f ms on average), %d distinct images" % (
    name, len(files), span, 1000.0 * span / max(1, len(files) - 1), len(runs)))
print("  a new image appeared at (ms): " + ", ".join(str(t) for t, _, _ in runs))
# GIF with the real timing: each distinct image held until the next.
cl = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False)
for i, (t, f, _) in enumerate(runs):
    end = runs[i + 1][0] if i + 1 < len(runs) else ms[-1]
    cl.write("file '%s'\nduration %.3f\n" % (os.path.join(os.path.abspath(src), f), max(0.02, (end - t) / 1000.0)))
cl.write("file '%s'\n" % os.path.join(os.path.abspath(src), runs[-1][1]))
cl.close()
gif = os.path.join(out, name + ".gif")
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", cl.name,
                "-vf", "fps=50,scale=iw*3:ih*3:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=none",
                "-loop", "0", gif], check=True)
# Sheet of the distinct images.
sl = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False)
pick = runs[:24]
for t, f, _ in pick:
    sl.write("file '%s'\n" % os.path.join(os.path.abspath(src), f))
sl.close()
cols = 4 if len(pick) > 4 else len(pick)
rows = (len(pick) + cols - 1) // cols
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", sl.name,
                "-vf", "scale=iw*3:ih*3:flags=lanczos,tile=%dx%d:padding=6:color=white" % (cols, rows),
                "-frames:v", "1", os.path.join(out, name + "-sheet.png")], check=True)
