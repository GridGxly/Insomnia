#!/usr/bin/env python3
"""ticks.py DIR...: when the countdown text changed, in each grab folder.

Reads the text area of each screenshot (x 175..245, y 4..26 of the 300x30
capture) as grayscale, marks a frame as changed when at least 5 of its
pixels differ from the previous frame's by more than 40 of 255 levels, and groups changes into
ticks: a tick is a change after at least 300 ms without one (a digit roll
spreads one tick's change over about 200 ms). A gap of more than 1.5 s between
ticks means the countdown held one value for about 2 s, and a tick next to it
moved by 2 seconds.
"""
import os, subprocess, sys

X0, X1, Y0, Y1 = 175, 245, 4, 26
W, H = X1 - X0, Y1 - Y0

def frames(d):
    files = sorted(f for f in os.listdir(d) if f.endswith(".png"))
    raw = subprocess.run(["ffmpeg", "-v", "error", "-framerate", "100", "-pattern_type", "glob",
                          "-i", os.path.join(d, "*.png"), "-fps_mode", "passthrough",
                          "-vf", "crop=%d:%d:%d:%d,format=gray" % (W, H, X0, Y0),
                          "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    n = len(raw) // (W * H)
    assert n == len(files), (n, len(files))
    return [int(f[:-4]) for f in files], [raw[i * W * H:(i + 1) * W * H] for i in range(n)]


def ticks_of(d):
    ms, fr = frames(d)
    changes = []
    for i in range(1, len(fr)):
        a, b = fr[i - 1], fr[i]
        if a == b:
            continue
        if sum(1 for j in range(len(a)) if abs(a[j] - b[j]) > 40) >= 5:
            changes.append(ms[i])
    ticks, last = [], None
    for t in changes:
        if last is None or t - last >= 300:
            ticks.append(t)
        last = t
    return ms, ticks
