#!/usr/bin/env python3
"""Bakes the ambient town critters — chicken, dog, ground bird — as 4x4 directional
sheets (rows: 0=down, 1=up, 2=left, 3=right; columns are the walk/peck cycle, the
same rig enemy.gd / wildlife.gd animate via dir_util). Built on pixelforge: the
grounded palette, stdlib only, no third-party deps.

Columns per row read as a gentle cycle — col0 neutral, col1/col3 a stepping bob,
col2 a deep peck (head to the ground) — so the WALK_FRAMES [0,1,0,2] cycle ambles
with a peck dip, and the idle peck cycle [0,2,0] lets them nibble in place.

Run:  python3 tools/gen_critters.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas, P, rgb

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "placeholder")

DOWN, UP, LEFT, RIGHT = 0, 1, 2, 3
COLS = 4

# Per-column animation offsets: head dip (peck) and a small leg/step phase.
DIP = [0, 1, 3, 1]      # how far the head drops this column
STEP = [0, 1, 0, -1]    # leg/foot shuffle this column


def put(c, x, y, col):
    c.paint(int(x), int(y), col)


def shadow(c, cx, cy, rx, ry):
    c.ellipse(int(cx), int(cy), int(rx), int(ry), P.SHADOW, fill=True)


# --- Chicken (white hen, red comb) -----------------------------------------

CH_L = rgb(238, 234, 226)
CH_M = rgb(210, 204, 192)
CH_D = rgb(172, 164, 150)
COMB = rgb(196, 74, 66)
BEAK = rgb(228, 160, 72)
LEG = rgb(214, 150, 66)
EYE = P.OUTLINE


def draw_chicken(c, ox, oy, d, phase):
    fw, fh = 18, 18
    dip = DIP[phase]
    base = oy + fh - 2          # ground line (feet)
    cx = ox + fw // 2
    shadow(c, cx, base + 1, 6, 2)
    # legs
    lx = STEP[phase]
    c.line(cx - 2 + lx, base - 4, cx - 2 + lx, base, LEG)
    c.line(cx + 2 - lx, base - 4, cx + 2 - lx, base, LEG)
    # plump body
    by = base - 7
    c.ellipse(cx, by, 5, 4, CH_M, fill=True)
    c.ellipse(cx, by - 1, 5, 3, CH_L, fill=True)
    c.line(cx + 4, by + 1, cx + 5, by + 2, CH_D)   # wing tuck
    # tail (opposite the head)
    if d == LEFT:
        c.rect(cx + 4, by - 2, cx + 6, by - 1, CH_L)
    elif d == RIGHT:
        c.rect(cx - 6, by - 2, cx - 4, by - 1, CH_L)
    elif d == DOWN:
        c.rect(cx - 1, by - 4, cx + 1, by - 3, CH_L)
    # head
    hx = cx + (-3 if d == LEFT else 3 if d == RIGHT else 0)
    hy = by - 4 + dip
    c.disc(hx, hy, 2, CH_L)
    # comb
    put(c, hx, hy - 3, COMB)
    put(c, hx - 1, hy - 2, COMB)
    put(c, hx + 1, hy - 2, COMB)
    # beak + eye(s) by facing
    if d == LEFT:
        put(c, hx - 3, hy, BEAK); put(c, hx - 2, hy, BEAK)
        put(c, hx - 1, hy - 1, EYE)
    elif d == RIGHT:
        put(c, hx + 3, hy, BEAK); put(c, hx + 2, hy, BEAK)
        put(c, hx + 1, hy - 1, EYE)
    elif d == DOWN:
        put(c, hx, hy + 2, BEAK)
        put(c, hx - 1, hy, EYE); put(c, hx + 1, hy, EYE)
    # UP = back of head, no face


# --- Dog (brown street dog) -------------------------------------------------

DG_L = rgb(168, 130, 88)
DG_M = rgb(136, 102, 66)
DG_D = rgb(102, 74, 46)
SNOUT = rgb(150, 114, 76)
NOSE = P.OUTLINE
COLLAR = rgb(120, 70, 60)


def draw_dog(c, ox, oy, d, phase):
    fw, fh = 26, 20
    dip = DIP[phase] // 2
    base = oy + fh - 2
    cx = ox + fw // 2
    shadow(c, cx, base + 1, 9, 2)
    bob = 1 if phase in (1, 3) else 0
    by = base - 6 - bob
    if d in (LEFT, RIGHT):
        sgn = -1 if d == LEFT else 1
        # legs (fore + hind, shuffling)
        s = STEP[phase]
        for fx in (-6, 5):
            c.line(cx + fx + s, by + 2, cx + fx + s, base, DG_D)
            c.line(cx + fx - s, by + 2, cx + fx - s, base, DG_M)
        # body
        c.ellipse(cx, by, 8, 4, DG_M, fill=True)
        c.ellipse(cx, by - 1, 8, 3, DG_L, fill=True)
        c.rect(cx - 1, by + 3, cx + 1, by + 3, COLLAR)
        # tail (up, behind)
        c.line(cx - sgn * 8, by, cx - sgn * 10, by - 3, DG_D)
        # head + snout forward
        hx = cx + sgn * 8
        hy = by - 2 + dip
        c.disc(hx, hy, 3, DG_L)
        c.line(hx - sgn, hy - 4, hx - sgn * 2, hy - 6, DG_D)   # ear
        c.rect(hx + sgn * 2, hy, hx + sgn * 3, hy + 1, SNOUT)   # muzzle
        put(c, hx + sgn * 4, hy, NOSE)
        put(c, hx + sgn, hy - 1, NOSE)                          # eye
    else:
        # front / back: narrower, four legs splayed
        s = STEP[phase]
        for fx in (-4, 4):
            c.line(cx + fx, by + 2, cx + fx, base, DG_D)
        c.ellipse(cx, by, 5, 4, DG_M, fill=True)
        c.ellipse(cx, by - 1, 5, 3, DG_L, fill=True)
        hy = by - 4 + dip
        c.disc(cx, hy, 3, DG_L)
        c.line(cx - 3, hy - 3, cx - 2, hy - 5, DG_D)            # ears
        c.line(cx + 3, hy - 3, cx + 2, hy - 5, DG_D)
        if d == DOWN:
            put(c, cx, hy + 2, NOSE)
            put(c, cx - 1, hy, NOSE); put(c, cx + 1, hy, NOSE)
        else:  # UP: tail tuft showing
            c.rect(cx - 1, by + 1, cx + 1, by + 3, DG_D)


# --- Ground bird (little grey pigeon) --------------------------------------

BD_L = rgb(150, 150, 158)
BD_M = rgb(120, 120, 130)
BD_D = rgb(92, 94, 104)
BREAST = rgb(154, 124, 116)
BBEAK = rgb(222, 150, 70)
FOOT = rgb(196, 120, 96)


def draw_bird(c, ox, oy, d, phase):
    fw, fh = 14, 14
    dip = DIP[phase]
    base = oy + fh - 2
    cx = ox + fw // 2
    shadow(c, cx, base + 1, 4, 1)
    # feet
    put(c, cx - 1, base, FOOT); put(c, cx + 1, base, FOOT)
    by = base - 4
    # body
    c.ellipse(cx, by, 3, 3, BD_M, fill=True)
    c.ellipse(cx, by - 1, 3, 2, BD_L, fill=True)
    # a flutter on the deep-peck column reads as a wing-lift
    if phase == 2:
        c.line(cx - 3, by - 2, cx - 4, by - 3, BD_D)
        c.line(cx + 3, by - 2, cx + 4, by - 3, BD_D)
    # tail opposite head
    if d == LEFT:
        c.rect(cx + 2, by - 1, cx + 4, by, BD_D)
    elif d == RIGHT:
        c.rect(cx - 4, by - 1, cx - 2, by, BD_D)
    elif d == DOWN:
        c.rect(cx - 1, by - 3, cx + 1, by - 2, BD_D)
    # head
    hx = cx + (-2 if d == LEFT else 2 if d == RIGHT else 0)
    hy = by - 3 + dip
    c.disc(hx, hy, 2, BD_D)
    put(c, hx, hy - 1, BD_M)
    if d == LEFT:
        put(c, hx - 2, hy, BBEAK); put(c, hx - 1, hy - 1, EYE)
        c.rect(cx + 1, by + 1, cx + 2, by + 2, BREAST)
    elif d == RIGHT:
        put(c, hx + 2, hy, BBEAK); put(c, hx + 1, hy - 1, EYE)
        c.rect(cx - 2, by + 1, cx - 1, by + 2, BREAST)
    elif d == DOWN:
        put(c, hx, hy + 1, BBEAK)
        put(c, hx - 1, hy, EYE); put(c, hx + 1, hy, EYE)
        c.rect(cx - 1, by + 1, cx + 1, by + 2, BREAST)


def bake(name, fw, fh, draw):
    sheet = Canvas(fw * COLS, fh * 4)
    for d in range(4):
        for col in range(COLS):
            draw(sheet, col * fw, d * fh, d, col)
    sheet.outline()
    sheet.save(os.path.join(OUT, name))
    print("  baked", name, "(%dx%d)" % (sheet.w, sheet.h))


def main():
    bake("critter_chicken.png", 18, 18, draw_chicken)
    bake("critter_dog.png", 26, 20, draw_dog)
    bake("critter_bird.png", 14, 14, draw_bird)


if __name__ == "__main__":
    main()
