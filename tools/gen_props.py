#!/usr/bin/env python3
"""Settlement & camp props for Teramor - grounded palette, foot-anchored.

Replaces the flat placeholder props with shaded, volumetric ones on the scale
grid. Bases sit at the bottom of each canvas.

  tent.png     44x36  canvas A-frame tent
  campfire.png 26x22  stone ring + burning logs
  barrel.png   16x24  hooped wooden barrel
  crate.png    18x18  braced wooden crate
  fence.png    16x18  rail-fence segment (tiles horizontally)
  well.png     30x40  stone well with a shingled roof

Run:  python3 tools/gen_props.py
"""

import math
import random

from pixelforge import Canvas, P, asset, lerp, shade


def gen_tent(name="tent.png"):
    c = Canvas(44, 36)
    canvas_l = (170, 150, 116, 255)
    canvas_m = (140, 122, 92, 255)
    canvas_d = (108, 92, 68, 255)
    # Ridge pole tips.
    c.paint(6, 8, P.WOOD[3]); c.paint(38, 8, P.WOOD[3])
    # Two sloped canvas panels meeting at a ridge.
    for y in range(9, 34):
        t = (y - 9) / 25
        halfw = int(4 + 17 * t)
        c.rect(22 - halfw, y, 22, y, canvas_m)          # left panel (lit)
        c.rect(22, y, 22 + halfw, y, canvas_d)          # right panel (shade)
        c.paint(22 - halfw, y, canvas_d)
        c.paint(22 + halfw, y, shade(canvas_d, 0.85))
    c.line(22, 8, 22, 33, canvas_l)                     # lit ridge
    c.line(6, 33, 22, 8, lerp(canvas_l, canvas_m, 0.4))  # lit left eave
    # Dark triangular entrance with tied-back flaps.
    for y in range(18, 34):
        t = (y - 18) / 16
        hw = int(1 + 6 * t)
        c.rect(22 - hw, y, 22 + hw, y, (40, 34, 28, 255))
    c.line(22 - 7, 33, 22, 19, canvas_l)
    c.line(22 + 7, 33, 22, 19, canvas_d)
    # Guy-rope + peg.
    c.line(6, 9, 1, 33, P.WOOD[4]); c.paint(1, 33, P.METAL[3])
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(44x36)")


def gen_campfire(name="campfire.png"):
    c = Canvas(26, 22)
    # Ring of stones.
    rnd = random.Random(4)
    for ang in range(0, 360, 45):
        sx = 13 + int(9 * math.cos(math.radians(ang)))
        sy = 16 + int(5 * math.sin(math.radians(ang)))
        c.ellipse(sx, sy, 3, 2, P.STONE[2])
        c.ellipse(sx, sy - 1, 2, 1, P.STONE[1])
        c.paint(sx + 1, sy + 1, P.STONE[3])
    # Charred logs.
    c.line(8, 17, 18, 13, P.BARK[3]); c.line(8, 14, 18, 18, P.BARK[3])
    c.line(8, 17, 18, 13, P.BARK[2])
    # Flames (ember ramp), tapering up.
    c.ellipse(13, 13, 4, 5, P.EMBER[3])
    c.ellipse(13, 12, 3, 4, P.EMBER[2])
    c.ellipse(13, 11, 2, 3, P.EMBER[1])
    c.ellipse(13, 10, 1, 2, P.EMBER[0])
    c.paint(13, 7, P.EMBER[0])
    c.outline()
    c.save(asset(name))
    print("generated", name, "(26x22)")


def gen_barrel(name="barrel.png"):
    c = Canvas(16, 24)
    # Staves (bulging barrel body).
    for x in range(3, 13):
        t = abs(x - 7.5) / 4.5
        col = lerp(P.WOOD[1], P.WOOD[3], t)
        c.vline(x, 4, 22, col)
    c.ellipse(8, 4, 5, 2, P.WOOD[1])                    # top rim
    c.ellipse(8, 4, 4, 1, P.WOOD[2])
    # Iron hoops.
    for hy in (7, 14, 21):
        c.hline(2, 13, hy, P.METAL[3])
        c.hline(2, 13, hy - 1, P.METAL[1])
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(16x24)")


def gen_crate(name="crate.png"):
    c = Canvas(18, 18)
    c.shade_rect(2, 2, 15, 16, P.WOOD[1], P.WOOD[2], P.WOOD[3])
    c.frame(2, 2, 15, 16, P.WOOD[4])                    # corner posts
    c.vline(2, 2, 16, P.WOOD[3]); c.vline(15, 2, 16, P.WOOD[3])
    c.line(3, 3, 14, 15, P.WOOD[3]); c.line(14, 3, 3, 15, P.WOOD[3])  # X brace
    c.line(3, 3, 14, 15, P.WOOD[1])
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(18x18)")


def gen_fence(name="fence.png"):
    c = Canvas(16, 18)
    # Two posts + two rails; designed to tile horizontally.
    for px in (2, 13):
        c.rect(px, 4, px + 1, 16, P.WOOD[2])
        c.vline(px, 4, 16, P.WOOD[1]); c.vline(px + 1, 4, 16, P.WOOD[3])
        c.paint(px, 4, P.WOOD[1])
    for ry in (7, 12):
        c.rect(0, ry, 15, ry + 1, P.WOOD[2])
        c.hline(0, 15, ry, P.WOOD[1]); c.hline(0, 15, ry + 1, P.WOOD[3])
    c.outline()
    c.save(asset(name))
    print("generated", name, "(16x18)")


def gen_well(name="well.png"):
    c = Canvas(30, 40)
    # Stone curb.
    c.ellipse(15, 30, 12, 5, P.STONE[2])
    c.rect(3, 26, 27, 30, P.STONE[2])
    c.ellipse(15, 26, 12, 4, P.STONE[1])
    c.ellipse(15, 26, 9, 3, (30, 34, 44, 255))          # dark water shaft
    rnd = random.Random(6)
    for sy in range(27, 31):                            # block seams
        for sx in range(4, 27, 4):
            c.paint(sx + (sy % 2), sy, P.STONE[3])
    # Posts + shingled roof.
    c.rect(4, 8, 6, 27, P.WOOD[3]); c.rect(24, 8, 26, 27, P.WOOD[3])
    for y in range(2, 12):
        t = (y - 2) / 10
        hw = int(2 + 13 * t)
        col = P.ROOF[1] if (y % 2 == 0) else P.ROOF[2]
        c.rect(15 - hw, y, 15 + hw, y, col)
        c.paint(15 - hw, y, P.ROOF[3]); c.paint(15 + hw, y, P.ROOF[3])
    c.rect(13, 1, 17, 2, P.WOOD[2])                     # ridge
    # Bucket rope + bucket.
    c.vline(15, 12, 22, P.WOOD[4])
    c.rect(13, 22, 17, 25, P.WOOD[2]); c.hline(13, 17, 22, P.WOOD[1])
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(30x40)")


def main():
    gen_tent()
    gen_campfire()
    gen_barrel()
    gen_crate()
    gen_fence()
    gen_well()


if __name__ == "__main__":
    main()
