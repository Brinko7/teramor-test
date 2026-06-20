#!/usr/bin/env python3
"""Procedural pixel-art for the Teramor bear + bear cub (Beast faction).

Two 4x4 directional walk sheets matching the engine convention used by enemy.gd
(rows 0=down, 1=up, 2=left, 3=right; columns are the walk cycle [0,1,0,2], col 0
= stand):

  * enemy_bear.png      - 32x32 frames, 128x128 sheet. A bulky brown bear: heavy
                          shoulder hump, broad barrel body, short rounded ears.
                          Reads BIG next to the 24x40 player (art-bible scale).
  * enemy_bear_cub.png  - 20x20 frames, 80x80 sheet. A small, round, top-heavy
                          cub - clearly the bear's young.

Built on pixelforge.Canvas so each sheet gets its own size. Each frame is drawn
on its own little canvas and outlined in isolation (so outlines never bleed
across frames), then blitted into the sheet. Run to (re)bake both PNGs.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixelforge import Canvas, rgb, P  # noqa: E402

DOWN, UP, LEFT, RIGHT = 0, 1, 2, 3
PHASES = [0, 1, 2, 3]

# --- gait (shared) ----------------------------------------------------------
# near pair = legs closest to camera on a side view; diagonal legs swing
# together (a trot/amble). Front views just lift one leg then the other.

def _near_gait(phase):
    return {0: (0, 0, 0, 0), 1: (1, 1, -1, 0),
            2: (-1, 0, 1, 1), 3: (0, 0, 0, 0)}[phase]


def _far_gait(phase):
    return {0: (0, 0, 0, 0), 1: (-1, 0, 1, 1),
            2: (1, 1, -1, 0), 3: (0, 0, 0, 0)}[phase]


def _pair_lift(phase):
    return {0: (0, 0), 1: (1, 0), 2: (0, 1), 3: (0, 0)}[phase]


# --- bear palette (grounded brown) ------------------------------------------
BR_L = rgb(126, 95, 62)
BR_M = rgb(100, 73, 47)
BR_D = rgb(74, 53, 34)
BR_DD = rgb(52, 37, 24)
MUZZLE = rgb(150, 126, 96)
NOSE = rgb(28, 22, 20)
EYE = rgb(22, 17, 15)
CLAW = rgb(206, 198, 180)
EAR_IN = rgb(118, 84, 78)

# --- cub palette (lighter, warmer) ------------------------------------------
CB_L = rgb(144, 112, 76)
CB_M = rgb(116, 88, 58)
CB_D = rgb(86, 64, 42)
CB_DD = rgb(62, 46, 30)
CB_MUZ = rgb(166, 142, 110)


def _leg(c, x, y_top, y_bot, col, dark, w=3, claws=True):
    if y_bot < y_top:
        y_bot = y_top
    c.rect(x, y_top, x + w - 1, y_bot, col)
    c.rect(x, y_bot, x + w - 1, y_bot, dark)            # paw
    if claws:
        c.paint(x, y_bot, CLAW)
        c.paint(x + w - 1, y_bot, CLAW)


# ============================ ADULT BEAR (32x32) ============================
BFW = BFH = 32
BBASE = 30  # feet baseline row


def bear_side(c, phase):
    nf_dx, nf_lift, nh_dx, nh_lift = _near_gait(phase)
    ff_dx, ff_lift, fh_dx, fh_lift = _far_gait(phase)

    c.rect(3, 17, 5, 20, BR_D)                          # stubby tail (rear/left)

    # far legs (behind body, darker)
    _leg(c, 9 + fh_dx, 23, BBASE - fh_lift, BR_D, BR_DD, w=3)
    _leg(c, 19 + ff_dx, 23, BBASE - ff_lift, BR_D, BR_DD, w=3)

    # body barrel + shoulder hump
    c.ellipse(15, 19, 12, 7, BR_M)
    c.ellipse(20, 13, 6, 5, BR_M)
    c.ellipse(15, 17, 10, 5, BR_L)                      # lit upper back
    c.ellipse(20, 11, 5, 3, BR_L)                       # lit hump
    c.ellipse(14, 24, 9, 2, BR_D)                       # belly shadow

    # head (right), muzzle, ear, eye
    c.ellipse(26, 17, 5, 5, BR_M)
    c.ellipse(25, 15, 4, 3, BR_L)
    c.disc(24, 11, 2, BR_M)
    c.paint(24, 11, EAR_IN)
    c.ellipse(30, 18, 2, 2, MUZZLE)
    c.paint(31, 17, NOSE)
    c.paint(31, 18, NOSE)
    c.paint(27, 16, EYE)

    # near legs (front of body)
    _leg(c, 10 + nh_dx, 23, BBASE - nh_lift, BR_M, BR_DD, w=3)
    _leg(c, 20 + nf_dx, 23, BBASE - nf_lift, BR_M, BR_DD, w=3)


def bear_front(c, phase):
    ll, rl = _pair_lift(phase)
    c.disc(10, 8, 2, BR_M)
    c.disc(20, 8, 2, BR_M)
    c.paint(10, 8, EAR_IN)
    c.paint(20, 8, EAR_IN)
    # head
    c.ellipse(15, 11, 6, 5, BR_M)
    c.ellipse(15, 10, 5, 3, BR_L)
    # muzzle + nose
    c.ellipse(15, 14, 3, 2, MUZZLE)
    c.rect(14, 14, 16, 14, NOSE)
    # eyes
    c.paint(12, 10, EYE)
    c.paint(18, 10, EYE)
    # body
    c.ellipse(15, 21, 9, 6, BR_M)
    c.ellipse(15, 19, 7, 4, BR_L)
    c.ellipse(15, 25, 7, 2, BR_D)
    # front legs
    _leg(c, 8, 24, BBASE - ll, BR_M, BR_DD, w=4)
    _leg(c, 20, 24, BBASE - rl, BR_M, BR_DD, w=4)


def bear_back(c, phase):
    ll, rl = _pair_lift(phase)
    c.disc(10, 8, 2, BR_M)
    c.disc(20, 8, 2, BR_M)
    # back of head
    c.ellipse(15, 11, 6, 4, BR_M)
    c.ellipse(15, 10, 5, 3, BR_L)
    # broad back + spine
    c.ellipse(15, 20, 9, 7, BR_M)
    c.ellipse(15, 18, 7, 4, BR_L)
    c.rect(14, 13, 16, 24, BR_D)                        # spine shadow
    c.rect(13, 25, 17, 25, BR_DD)
    # stubby tail toward viewer
    c.rect(14, 24, 16, 27, BR_D)
    # hind legs
    _leg(c, 8, 24, BBASE - ll, BR_M, BR_DD, w=4)
    _leg(c, 20, 24, BBASE - rl, BR_M, BR_DD, w=4)


# ============================== CUB (20x20) ================================
CFW = CFH = 20
CBASE = 18


def cub_side(c, phase):
    nf_dx, nf_lift, nh_dx, nh_lift = _near_gait(phase)
    ff_dx, ff_lift, fh_dx, fh_lift = _far_gait(phase)

    c.rect(2, 11, 3, 12, CB_D)                          # tail
    # far legs
    _leg(c, 6 + fh_dx, 14, CBASE - fh_lift, CB_D, CB_DD, w=2, claws=False)
    _leg(c, 11 + ff_dx, 14, CBASE - ff_lift, CB_D, CB_DD, w=2, claws=False)
    # round body
    c.ellipse(9, 12, 6, 4, CB_M)
    c.ellipse(9, 11, 5, 3, CB_L)
    c.ellipse(9, 15, 5, 1, CB_D)
    # big head (cubs are top-heavy), ear, muzzle, eye
    c.disc(15, 9, 4, CB_M)
    c.ellipse(14, 8, 3, 2, CB_L)
    c.disc(13, 5, 2, CB_M)
    c.paint(13, 5, EAR_IN)
    c.ellipse(18, 10, 2, 1, CB_MUZ)
    c.paint(19, 10, NOSE)
    c.paint(16, 8, EYE)
    # near legs
    _leg(c, 7 + nh_dx, 14, CBASE - nh_lift, CB_M, CB_DD, w=2, claws=False)
    _leg(c, 12 + nf_dx, 14, CBASE - nf_lift, CB_M, CB_DD, w=2, claws=False)


def cub_front(c, phase):
    ll, rl = _pair_lift(phase)
    c.disc(7, 5, 2, CB_M)
    c.disc(13, 5, 2, CB_M)
    c.paint(7, 5, EAR_IN)
    c.paint(13, 5, EAR_IN)
    c.disc(10, 8, 4, CB_M)                              # big head
    c.ellipse(10, 7, 3, 2, CB_L)
    c.ellipse(10, 10, 2, 1, CB_MUZ)
    c.paint(10, 10, NOSE)
    c.paint(8, 7, EYE)
    c.paint(12, 7, EYE)
    c.ellipse(10, 14, 5, 3, CB_M)                       # body
    c.ellipse(10, 13, 4, 2, CB_L)
    _leg(c, 6, 15, CBASE - ll, CB_M, CB_DD, w=2, claws=False)
    _leg(c, 12, 15, CBASE - rl, CB_M, CB_DD, w=2, claws=False)


def cub_back(c, phase):
    ll, rl = _pair_lift(phase)
    c.disc(7, 5, 2, CB_M)
    c.disc(13, 5, 2, CB_M)
    c.disc(10, 8, 4, CB_M)
    c.ellipse(10, 7, 3, 2, CB_L)
    c.ellipse(10, 14, 5, 4, CB_M)
    c.ellipse(10, 12, 4, 2, CB_L)
    c.rect(9, 9, 11, 16, CB_D)                          # spine
    c.rect(9, 15, 11, 17, CB_D)                         # tail nub
    _leg(c, 6, 15, CBASE - ll, CB_M, CB_DD, w=2, claws=False)
    _leg(c, 12, 15, CBASE - rl, CB_M, CB_DD, w=2, claws=False)


# --- assembly ---------------------------------------------------------------

def _render_sheet(fw, fh, front, back, side, out_name):
    sheet = Canvas(fw * 4, fh * 4)
    rows = {DOWN: front, UP: back, RIGHT: side}
    for facing, fn in rows.items():
        for phase in PHASES:
            f = Canvas(fw, fh)
            fn(f, phase)
            f.outline()
            sheet.blit(f, phase * fw, facing * fh)
    # LEFT = mirror of RIGHT
    for phase in PHASES:
        f = Canvas(fw, fh)
        side(f, phase)
        f.outline()
        for y in range(fh):
            for x in range(fw):
                col = f.at(x, y)
                if col[3]:
                    sheet.paint(phase * fw + (fw - 1 - x), LEFT * fh + y, col)
    path = os.path.join(os.path.dirname(__file__), "..", "assets",
                        "placeholder", "enemies", out_name)
    sheet.save(path)
    return path, sheet


def main():
    bp, bs = _render_sheet(BFW, BFH, bear_front, bear_back, bear_side,
                           "enemy_bear.png")
    cp, cs = _render_sheet(CFW, CFH, cub_front, cub_back, cub_side,
                           "enemy_bear_cub.png")
    print("generated bear sheet  (32x32 frames, 128x128) ->", os.path.normpath(bp))
    print("generated cub sheet   (20x20 frames, 80x80)   ->", os.path.normpath(cp))
    if "--preview" in sys.argv:
        bs.scaled(6).save("/tmp/teramor_bear_preview.png")
        cs.scaled(6).save("/tmp/teramor_cub_preview.png")
        print("previews -> /tmp/teramor_bear_preview.png /tmp/teramor_cub_preview.png")


if __name__ == "__main__":
    main()
