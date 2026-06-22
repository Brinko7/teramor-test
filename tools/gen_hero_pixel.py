#!/usr/bin/env python3
"""Teramor hero — Eastward-density hand-authored pixel art.

Deliberate 2D pixel art (no renderer): clean shapes, warm COLORED outlines, and
dense, hand-placed shading + detail in the Eastward vibe — 5-tone material ramps
for soft volume, fabric folds, hair strands, stitched leather, and a fully
detailed face. Warm, muted, cozy palette. Stdlib only (pixelforge Canvas).

Run:  python3 tools/gen_hero_pixel.py   ->  /tmp/hero_px.png (+ scaled)
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402

def rgb(r, g, b, a=255): return (r, g, b, a)

# ---- warm muted palette, 5 tones (0=highlight .. 4=core shadow) ----
SK    = [rgb(252,222,190), rgb(240,200,164), rgb(222,176,138), rgb(188,140,106), rgb(150,104,80)]
SK_HI = rgb(255,238,214)
BLUSH = rgb(230,156,136)
FRECK = rgb(198,138,104)
HR    = [rgb(170,122,74), rgb(142,100,58), rgb(114,78,44), rgb(88,58,32), rgb(64,42,24)]
GRN   = [rgb(150,172,116), rgb(122,146,92), rgb(98,122,72), rgb(74,98,55), rgb(54,74,42)]
LEA   = [rgb(192,148,98), rgb(162,120,74), rgb(130,94,54), rgb(100,70,40), rgb(74,50,30)]
CRM   = [rgb(240,226,196), rgb(216,198,164), rgb(186,166,130), rgb(150,130,100)]
TRO   = [rgb(136,130,146), rgb(112,106,124), rgb(88,82,102), rgb(64,60,78)]
BOOT  = [rgb(118,86,60), rgb(92,66,44), rgb(68,48,32), rgb(46,32,22)]
GOLD  = [rgb(248,214,134), rgb(222,172,94), rgb(168,122,60)]
INK   = rgb(50, 36, 44)          # main outline
GRN_OL= rgb(42, 58, 36)          # cloak-colored outline
LEA_OL= rgb(58, 38, 24)
WHITE = rgb(250, 248, 242)

W, H = 84, 120

def ell(c, cx, cy, rx, ry, col): c.ellipse(cx, cy, rx, ry, col, fill=True)
def R(c, x0, y0, x1, y1, col): c.rect(x0, y0, x1, y1, col)

def main():
    c = Canvas(W, H)
    cx = 42

    # ================= CLOAK (behind, draped with folds) =================
    ell(c, cx, 70, 27, 42, GRN[3])
    R(c, cx-25, 46, cx+25, 104, GRN[3])
    # broad light/shadow over the drape
    R(c, cx-25, 46, cx-22, 104, GRN[2])               # lit left edge
    R(c, cx+12, 46, cx+25, 104, GRN[4])               # shadow right
    # vertical fold ridges (light) + valleys (dark) — clean drape lines
    for fx in (cx-17, cx-9, cx+3): c.line(fx, 50, fx, 102, GRN[2])
    for fx in (cx-13, cx-4, cx+8): c.line(fx, 50, fx, 104, GRN[4])
    # frayed lit hem
    for hx in range(cx-24, cx+25, 3): c.paint(hx, 103, GRN[2])

    # ================= LEGS (trousers + boots) =================
    for s in (-1, 1):
        lx = cx + s*10
        R(c, lx-6, 76, lx+5, 100, TRO[1])             # trouser base
        R(c, lx-6, 76, lx-4, 100, TRO[0])             # lit outer
        R(c, lx+2, 76, lx+5, 100, TRO[2])             # inner shadow
        R(c, lx-6, 96, lx+5, 100, TRO[3])             # knee/hem shadow
        for ky in (84, 92): R(c, lx-5, ky, lx+4, ky, TRO[2])   # fabric creases
        # boot
        R(c, lx-6, 98, lx+5, 112, BOOT[1])
        R(c, lx-6, 98, lx-4, 112, BOOT[0])
        R(c, lx+3, 100, lx+5, 112, BOOT[2])
        R(c, lx-6, 98, lx+5, 99, BOOT[0])             # cuff lip
        R(c, lx-7, 110, lx+6, 112, BOOT[3])           # sole
        c.line(lx-3, 104, lx+2, 104, BOOT[3])         # lace line
    R(c, cx-3, 76, cx+2, 100, TRO[3])                 # inner-leg seam

    # ================= TORSO (cream shirt + green tunic + belt) =================
    ell(c, cx, 58, 19, 21, GRN[1])
    R(c, cx-18, 44, cx+18, 72, GRN[1])
    # light & shadow modelling
    R(c, cx-18, 44, cx-15, 72, GRN[0])                # lit left
    R(c, cx+8, 44, cx+18, 74, GRN[2])
    R(c, cx+14, 46, cx+18, 72, GRN[3])               # right core shadow
    R(c, cx-18, 68, cx+18, 72, GRN[3])               # hem shadow
    # chest fold creases
    c.line(cx-9, 50, cx-5, 60, GRN[2]); c.line(cx+6, 52, cx+3, 62, GRN[3])
    c.line(cx-12, 60, cx-9, 66, GRN[2])
    # cream collar (V) + a laced neckline
    R(c, cx-5, 42, cx+5, 48, CRM[1]); R(c, cx-5, 42, cx-3, 48, CRM[0])
    c.paint(cx, 46, CRM[2]); c.paint(cx-1, 47, CRM[3])
    c.line(cx-5, 42, cx, 48, GRN[3]); c.line(cx+5, 42, cx, 48, GRN[3])
    for ly in (44, 46): c.paint(cx-3, ly, LEA[3]); c.paint(cx+3, ly, LEA[3])   # lacing
    # satchel strap across the chest (stitched leather)
    for i in range(26):
        sx = cx-14 + i; sy = 46 + i
        c.paint(sx, sy, LEA[2]); c.paint(sx+1, sy, LEA[3])
        if i % 3 == 0: c.paint(sx, sy, LEA[0])        # stitch glints
    # belt + buckle + pouch
    R(c, cx-18, 70, cx+18, 75, LEA[2]); R(c, cx-18, 70, cx+18, 70, LEA[1])
    R(c, cx-18, 74, cx+18, 75, LEA[4])
    R(c, cx-3, 69, cx+3, 76, GOLD[1]); R(c, cx-3, 69, cx+3, 70, GOLD[0]); c.paint(cx+2, 74, GOLD[2])
    ell(c, cx+15, 74, 6, 6, LEA[1]); R(c, cx+11, 72, cx+19, 75, LEA[2]); c.paint(cx+17, 76, LEA[3])  # pouch
    c.paint(cx+15, 73, LEA[0])

    # ================= ARMS (sleeves + gloves) =================
    for s in (-1, 1):
        ax = cx + s*19
        R(c, ax-4, 46, ax+4, 68, GRN[1])              # sleeve
        R(c, ax-4, 46, ax-2, 68, GRN[0]); R(c, ax+2, 46, ax+4, 68, GRN[3])
        c.line(ax-2, 54, ax-1, 62, GRN[2])            # sleeve fold
        R(c, ax-4, 66, ax+4, 69, LEA[2])              # glove cuff
        ell(c, ax, 73, 5, 5, LEA[1])                  # gloved fist
        R(c, ax-4, 71, ax-2, 75, LEA[0])              # lit edge
        c.paint(ax+3, 75, LEA[3]); c.paint(ax+2, 74, LEA[3])
        c.line(ax-1, 71, ax-1, 75, LEA[3])            # finger groove
        c.line(ax+1, 71, ax+1, 75, LEA[3])

    # ================= NECK + HEAD =================
    R(c, cx-5, 36, cx+4, 42, SK[3]); R(c, cx-5, 36, cx-3, 42, SK[2])   # neck (shadowed)
    ell(c, cx, 23, 14, 15, SK[2])                     # head
    # skin modelling: lit upper-left, shadow right + jaw + under-nose
    ell(c, cx-3, 20, 9, 9, SK[1])
    R(c, cx-11, 13, cx-3, 22, SK[1]); c.paint(cx-9, 15, SK[0]); c.paint(cx-8, 14, SK_HI)
    R(c, cx+8, 16, cx+13, 32, SK[3])                  # shaded right cheek
    R(c, cx+10, 20, cx+13, 30, SK[4])
    ell(c, cx, 31, 9, 5, SK[2]); ell(c, cx, 36, 6, 2, SK[3])       # jaw rounding + soft under-chin
    # pointed half-elf ears with inner shadow
    for s in (-1, 1):
        ex = cx + s*13
        c.line(ex, 24, ex+s*3, 19, SK[2]); c.line(ex+s*1, 24, ex+s*3, 20, SK[3])
        c.paint(ex+s*1, 22, SK[1])
    # blush + freckles
    for bx in (cx-9, cx-8, cx-7): c.paint(bx, 28, BLUSH)
    for bx in (cx+7, cx+8, cx+9): c.paint(bx, 28, BLUSH)
    for fx, fy in ((cx-7,26),(cx-5,27),(cx+6,26),(cx+8,27),(cx,29)): c.paint(fx, fy, FRECK)

    # ================= FACE detail =================
    # eyebrows (hair-toned, slightly arched)
    c.line(cx-9, 18, cx-3, 17, HR[2]); c.paint(cx-9, 19, HR[3])
    c.line(cx+3, 17, cx+9, 18, HR[2]); c.paint(cx+9, 19, HR[3])
    # eyes: clean + symmetric — lid shadow, white, hazel iris, pupil, catchlight
    for s in (-1, 1):
        ox = cx + s*6
        R(c, ox-2, 20, ox+1, 20, SK[3])               # upper-lid shadow
        R(c, ox-2, 21, ox+1, 23, WHITE)               # sclera
        R(c, ox-1, 21, ox+1, 23, rgb(112,146,92))     # hazel iris
        c.paint(ox, 22, rgb(56,44,40))                # pupil
        c.paint(ox-1, 21, WHITE)                       # catchlight (upper-left)
        c.paint(ox-2, 23, SK[3]); c.paint(ox+1, 23, SK[3])   # lower-lid corners
    # nose: bridge highlight + a soft right shadow + nostril hint
    c.paint(cx-1, 24, SK[1]); c.paint(cx-1, 26, SK[0])
    c.paint(cx+1, 26, SK[3]); c.paint(cx+1, 27, SK[4]); c.paint(cx, 28, SK[3])
    # mouth: a soft slight smile with a lit lower lip
    c.line(cx-3, 31, cx+3, 31, rgb(150,86,78)); c.paint(cx-4, 30, rgb(150,86,78)); c.paint(cx+4, 30, rgb(150,86,78))
    R(c, cx-2, 32, cx+2, 32, rgb(196,124,112))

    # ================= HAIR (chunky clean locks, swept fringe) =================
    ell(c, cx, 12, 15, 10, HR[2])                     # solid crown mass
    R(c, cx-15, 12, cx-11, 28, HR[2]); R(c, cx+11, 12, cx+15, 28, HR[3])   # side locks
    # swept fringe: three soft lock-dips over the forehead (a clean wavy edge)
    ell(c, cx-8, 13, 5, 4, HR[2]); ell(c, cx, 14, 5, 4, HR[2]); ell(c, cx+8, 13, 5, 4, HR[2])
    R(c, cx-10, 16, cx+9, 17, HR[3])                  # soft shadow tucked under the fringe
    # right side falls into core shadow
    ell(c, cx+8, 12, 7, 9, HR[3]); R(c, cx+11, 11, cx+15, 27, HR[4])
    # one clean sheen band catching the upper-left light
    ell(c, cx-5, 8, 8, 3, HR[1]); c.line(cx-10, 7, cx+1, 6, HR[0]); ell(c, cx-6, 8, 3, 2, HR[0])
    # a couple of chunky lock separations (define strands, not a picket fence)
    c.line(cx-4, 7, cx-6, 16, HR[4]); c.line(cx+4, 8, cx+3, 16, HR[4])
    R(c, cx-15, 12, cx-14, 26, HR[1])                 # lit left-lock edge

    # ================= OUTLINES (colored, selective) =================
    c.outline(INK, diagonal=False)
    # internal separations in matching colored ink
    for s in (-1, 1):
        c.line(cx+s*15, 47, cx+s*15, 66, GRN_OL)      # arm / body
    c.line(cx-18, 70, cx+18, 70, LEA_OL)              # belt top edge

    c.save("/tmp/hero_px.png")
    c.scaled(5).save("/tmp/hero_px_6x.png")
    print("wrote /tmp/hero_px.png (%dx%d)" % (W, H))

if __name__ == "__main__":
    main()
