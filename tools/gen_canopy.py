#!/usr/bin/env python3
"""Bakes the canopy dapple — a small seamless tile of soft, translucent shade
blotches that CanopyFX scrolls across forest zones to read as sunlight filtering
through a thick canopy overhead. Transparent gaps are the light; the dark soft
discs are the leaf-shadow. Wrapped so it tiles seamlessly.

Built on pixelforge (stdlib only). Run: python3 tools/gen_canopy.py
"""

import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas, rgb

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "placeholder")

T = 96  # tile size


def blob(c, cx, cy, rx, ry):
    # Smooth radial falloff (1px steps) so there's no banding — faint at the edge,
    # gently denser toward the middle. Painted large->small; wrapped so it tiles.
    steps = max(rx, ry)
    for i in range(steps, 0, -1):
        t = i / float(steps)              # 1 at edge -> ~0 at centre
        a = int(10 + (1.0 - t) * 52)      # 10 edge -> ~62 centre (gentle)
        col = rgb(26, 34, 30, a)
        erx = max(1, int(rx * t))
        ery = max(1, int(ry * t))
        for dx in (-T, 0, T):
            for dy in (-T, 0, T):
                c.ellipse(cx + dx, cy + dy, erx, ery, col, True)


def main():
    rng = random.Random(11)
    c = Canvas(T, T)
    for _ in range(11):
        rx = rng.randint(12, 24)
        ry = max(8, int(rx * rng.uniform(0.7, 1.0)))
        blob(c, rng.randrange(T), rng.randrange(T), rx, ry)
    c.save(os.path.join(OUT, "canopy_dapple.png"))
    print("  baked canopy_dapple.png (%dx%d, seamless)" % (T, T))


if __name__ == "__main__":
    main()
