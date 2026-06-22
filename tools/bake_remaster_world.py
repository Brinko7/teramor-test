#!/usr/bin/env python3
"""Bake remaster world tiles (Eastward palette) for the in-engine slice.

A seamless 32px grass tile (warm, textured) — the ground for the additive
remaster-slice scene. Tiles are per-pixel deterministic so they repeat without a
visible seam; blades/flowers stay in the interior. Stdlib only.

Run:  python3 tools/bake_remaster_world.py -> assets/remaster/grass32.png
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402

GRASS = [(148,170,108,255),(122,148,88,255),(100,126,70,255),(80,104,56,255),(60,84,44,255)]
FLOW  = [(244,238,210,255),(244,206,108,255),(220,108,96,255),(170,134,206,255)]
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "remaster", "grass32.png"))

def main():
    N = 32
    c = Canvas(N, N)
    for y in range(N):
        for x in range(N):
            h = (x*374761393 + y*668265263) & 0xFFFF
            t = ((h ^ (h >> 7)) % 7)
            c.paint(x, y, GRASS[1] if t < 3 else GRASS[2])
    rnd = random.Random(11)
    for _ in range(26):                      # blades (kept off the edges)
        bx = rnd.randrange(2, N-2); by = rnd.randrange(3, N-2)
        c.paint(bx, by, GRASS[3]); c.paint(bx, by-1, GRASS[0] if rnd.random()<0.5 else GRASS[1])
    for _ in range(3):                       # a few flowers
        c.paint(rnd.randrange(3, N-3), rnd.randrange(3, N-3), FLOW[rnd.randrange(len(FLOW))])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    c.save(OUT)
    print("wrote %s (%dx%d, seamless)" % (OUT, N, N))

if __name__ == "__main__":
    main()
