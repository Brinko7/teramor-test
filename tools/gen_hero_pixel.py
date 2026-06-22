#!/usr/bin/env python3
"""Teramor hero — Eastward-style hand-authored pixel art. A clean break from the
procedural 3D/metaball renderers.

Method: deliberate 2D pixel art. Clean filled shapes, a warm COLORED outline
(not black), soft 2-3 tone cel shading with a top-left light, and an expressive
face. Warm, muted, cozy palette. Stdlib only (via pixelforge Canvas).

Run:  python3 tools/gen_hero_pixel.py   ->  /tmp/hero_px.png (+ scaled)
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402

def rgb(r, g, b, a=255): return (r, g, b, a)

# ---- warm, muted Eastward-ish palette (light -> dark per material) ----
INK   = rgb(56, 40, 46)        # colored outline (deep warm plum-brown)
INKL  = rgb(96, 70, 74)        # softer internal line
SK    = [rgb(248,214,180), rgb(234,190,152), rgb(208,158,122), rgb(172,120,92)]
BLUSH = rgb(226,150,130)
HR    = [rgb(154,106,62), rgb(124,82,46), rgb(96,60,36), rgb(70,44,26)]
GRN   = [rgb(128,152,98), rgb(100,126,76), rgb(76,100,58), rgb(56,76,44)]   # cloak/hood
LEA   = [rgb(178,134,86), rgb(148,106,64), rgb(114,80,46), rgb(86,58,34)]   # leather
CRM   = [rgb(228,210,176), rgb(200,180,146), rgb(166,146,114)]              # shirt/cream
TRO   = [rgb(126,120,134), rgb(100,94,110), rgb(76,72,88)]                  # trousers
BOOT  = [rgb(104,74,52), rgb(78,54,38), rgb(54,38,28)]
MTL   = [rgb(200,204,212), rgb(154,160,172), rgb(112,118,132)]
GOLD  = [rgb(240,200,120), rgb(206,158,80)]

W, H = 72, 96

def fill_ell(c, cx, cy, rx, ry, col):
    c.ellipse(cx, cy, rx, ry, col, fill=True)

def vshade(c, x0, y0, x1, y1, light, mid, dark):
    """A soft 3-tone column fill: lit on the upper-left, core shadow lower-right."""
    c.rect(x0, y0, x1, y1, mid)
    c.rect(x0, y0, x0+1, y1, light)
    c.rect(x1-1, y0, x1, y1, dark)
    c.rect(x0, y1-1, x1, y1, dark)

def main():
    c = Canvas(W, H)
    cx = 36

    # ---------- CLOAK behind the shoulders (drapes down) ----------
    fill_ell(c, cx, 58, 23, 33, GRN[2])
    c.rect(cx-21, 42, cx+21, 88, GRN[2])
    c.rect(cx+9, 42, cx+21, 88, GRN[3])              # right side in shadow
    c.rect(cx-21, 42, cx-19, 88, GRN[1])             # lit left edge
    for fy in (50, 62, 74):                           # fold creases
        c.line(cx-13, fy, cx-12, fy+7, GRN[3])
        c.line(cx+3, fy+4, cx+4, fy+11, GRN[3])
        c.line(cx-6, fy+2, cx-6, fy+8, GRN[1])

    # ---------- LEGS: trousers + boots ----------
    for s in (-1, 1):
        lx = cx + s*8
        vshade(c, lx-5, 64, lx+4, 84, TRO[0], TRO[1], TRO[2])   # trouser
        c.rect(lx-5, 82, lx+4, 90, BOOT[1])                      # boot
        c.rect(lx-5, 82, lx-4, 90, BOOT[0])                      # boot lit edge
        c.rect(lx-5, 88, lx+5, 90, BOOT[2])                      # sole
        c.rect(lx-5, 82, lx+4, 83, BOOT[0])                      # boot cuff lip
    c.rect(cx-2, 64, cx+1, 84, TRO[2])                           # inner-leg seam shadow

    # ---------- TORSO: cream shirt under a green tunic + leather belt ----------
    fill_ell(c, cx, 50, 16, 18, GRN[1])
    c.rect(cx-15, 40, cx+15, 60, GRN[1])
    c.rect(cx+6, 40, cx+15, 62, GRN[2])              # right shadow
    c.rect(cx+12, 42, cx+15, 60, GRN[3])
    c.rect(cx-15, 40, cx-13, 60, GRN[0])             # lit left edge
    c.rect(cx-15, 57, cx+15, 60, GRN[2])             # hem shadow
    # collar V of cream shirt
    c.rect(cx-4, 38, cx+4, 43, CRM[0]); c.paint(cx, 42, CRM[2])
    c.line(cx-4, 38, cx, 43, GRN[2]); c.line(cx+4, 38, cx, 43, GRN[2])
    # satchel strap across the chest + a pouch
    for yy in range(40, 62):
        c.paint(cx-12+(yy-40)*1, yy, LEA[2]); c.paint(cx-11+(yy-40)*1, yy, LEA[3])
    fill_ell(c, cx+12, 60, 5, 5, LEA[1]); c.rect(cx+13, 60, cx+16, 64, LEA[2])  # pouch
    # belt
    c.rect(cx-15, 60, cx+15, 64, LEA[2]); c.rect(cx-15, 60, cx+15, 60, LEA[1])
    c.rect(cx-2, 60, cx+2, 64, GOLD[0]); c.paint(cx+1, 63, GOLD[1])

    # ---------- ARMS (hang at the sides, leather gloves) ----------
    for s in (-1, 1):
        ax = cx + s*16
        vshade(c, ax-3, 42, ax+3, 57, GRN[0], GRN[1], GRN[2])   # sleeve
        c.rect(ax-3, 55, ax+3, 58, LEA[1])                       # glove cuff
        fill_ell(c, ax, 62, 4, 4, LEA[1])                        # glove (fist)
        c.paint(ax+2, 64, LEA[2]); c.paint(ax+2, 63, LEA[2])     # shadow
        c.paint(ax-2, 60, LEA[0])                                # lit knuckle
        c.paint(ax, 62, LEA[2])                                  # knuckle line

    # ---------- NECK + HEAD ----------
    c.rect(cx-4, 33, cx+3, 39, SK[2])
    fill_ell(c, cx, 24, 12, 13, SK[1])
    c.rect(cx-12, 16, cx-4, 30, SK[0])               # lit left of face (subtle)
    c.rect(cx+7, 18, cx+11, 32, SK[2])               # shaded right cheek/jaw
    c.rect(cx+9, 20, cx+11, 30, SK[3])
    fill_ell(c, cx, 30, 8, 5, SK[1])                 # rounded chin
    # pointed half-elf ears
    for s in (-1, 1):
        ex = cx + s*12
        c.line(ex, 22, ex+s*2, 19, SK[1]); c.paint(ex+s*1, 24, SK[2])
    # blush
    for bx in (cx-7, cx-6): c.paint(bx, 27, BLUSH)
    for bx in (cx+6, cx+7): c.paint(bx, 27, BLUSH)

    # ---------- FACE ----------
    for s in (-1, 1):
        ex = cx + s*5
        c.rect(ex-1, 21, ex+1, 24, rgb(250,248,242))             # eye white
        c.rect(ex-1 if s<0 else ex, 22, ex if s<0 else ex+1, 24, rgb(70,52,70))  # iris
        c.paint(ex-1 if s<0 else ex, 22, rgb(250,248,242))       # catchlight
    c.line(cx-7, 18, cx-3, 19, HR[2]); c.line(cx+3, 19, cx+7, 18, HR[2])  # brows
    c.paint(cx, 26, SK[2]); c.paint(cx, 27, SK[3])               # nose
    c.line(cx-2, 30, cx+2, 30, rgb(158,92,82)); c.paint(cx, 31, rgb(190,120,108))  # mouth

    # ---------- HAIR: tousled, framing the face ----------
    fill_ell(c, cx, 15, 13, 9, HR[1])
    c.rect(cx-13, 13, cx-9, 27, HR[1]); c.rect(cx+9, 13, cx+13, 27, HR[2])
    for bx, by in ((cx-8,18),(cx-4,19),(cx,18),(cx+4,19),(cx+8,18)):
        c.line(bx, 11, bx, by, HR[1])
    c.rect(cx+8, 12, cx+13, 22, HR[3])               # right side in shadow
    for hx, hy in ((cx-7,9),(cx-3,8),(cx+1,9),(cx-5,12)):   # highlight strands
        c.paint(hx, hy, HR[0])
    c.line(cx-7, 10, cx-1, 9, HR[0])

    # ---------- OUTLINE pass (colored) + a few internal separations ----------
    c.outline(INK, diagonal=False)
    for s in (-1, 1):                                # arm/body separation
        c.line(cx+s*13, 43, cx+s*13, 57, INKL)

    c.save("/tmp/hero_px.png")
    c.scaled(6).save("/tmp/hero_px_6x.png")
    print("wrote /tmp/hero_px.png (%dx%d)" % (W, H))

if __name__ == "__main__":
    main()
