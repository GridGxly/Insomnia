#!/usr/bin/env python3
"""holds.py DIR...: finds times when the countdown text showed one value for
at least 1.4 s. Compares the text area (as in ticks.py) of the frame at t
with the frame at t + 1.4 s, every 50 ms; "same" means fewer than 5 pixels
differ by more than 40 levels. A 1 s countdown never keeps one value that
long, so each run of matches is one hold (and the tick before it skipped a
second)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ticks_lib

def same(a, b):
    return sum(1 for j in range(len(a)) if abs(a[j] - b[j]) > 40) < 5

total = 0
for d in sys.argv[1:]:
    ms, fr = ticks_lib.frames(d)
    def at(t):
        i = max(k for k in range(len(ms)) if ms[k] <= t)
        return fr[i]
    holds, inside = [], False
    t = ms[0]
    while t + 1400 <= ms[-1]:
        s = same(at(t), at(t + 1400))
        if s and not inside:
            holds.append(t)
        inside = s
        t += 50
    total += len(holds)
    print("%s: holds starting near (ms): %s" % (d, holds))
print("TOTAL holds: %d in %d captures" % (total, len(sys.argv) - 1))
