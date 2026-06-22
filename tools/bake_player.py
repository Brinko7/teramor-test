#!/usr/bin/env python3
"""Bake the new Eastward-style player rig into a game-ready directional walk
sheet — the first engine-integration step (additive: produces an asset, touches
no scenes).

Layout matches the engine's convention: 4 columns (walk phases) x 8 rows
(facings S, SE, E, NE, N, NW, W, SW). The hand-authored front / side / back
views fill the cardinals; diagonals reuse the nearest side (mirrored for the
west-facing rows), the same mirror scheme the current sheets use.

Run:  python3 tools/bake_player.py  ->  assets/remaster/player_walk.png (+ preview)
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
import gen_player_anim as fa  # noqa: E402
import gen_player_dirs as d   # noqa: E402

FW, FH, COLS, ROWS = 84, 120, 4, 8
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..",
                                    "assets", "remaster", "player_walk.png"))

def mirror(src):
    out = Canvas(src.w, src.h)
    for y in range(src.h):
        for x in range(src.w):
            out.paint(src.w-1-x, y, src.at(x, y))
    return out

def cell(row, phase):
    if row == 0:               return fa.frame(phase)            # S  (front)
    if row in (1, 2, 3):       return d.side_frame(phase)        # SE/E/NE -> facing right
    if row == 4:               return d.back_frame(phase)        # N  (back)
    return mirror(d.side_frame(phase))                           # NW/W/SW -> facing left

def main():
    sheet = Canvas(FW*COLS, FH*ROWS)
    for r in range(ROWS):
        for p in range(COLS):
            sheet.blit(cell(r, p), p*FW, r*FH, mode="over")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    # a readable preview (rows = facings, cols = phases) on the grass tone
    prev = Canvas(sheet.w+8, sheet.h+8); prev.rect(0, 0, prev.w-1, prev.h-1, (126,160,120,255))
    prev.blit(sheet, 4, 4, mode="over")
    prev.scaled(1).save("/tmp/player_sheet.png")
    print("wrote %s (%dx%d, 8 dirs x 4 phases)" % (OUT, sheet.w, sheet.h))

if __name__ == "__main__":
    main()
