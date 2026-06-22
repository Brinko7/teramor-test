#!/usr/bin/env python3
"""Nature & props for Teramor - on the scale grid, grounded palette.

The hero here is the TREE: it must tower over buildings (and dwarf the player)
so the world reads at the right scale. Foliage is built from layered clumps lit
from the upper-left, not a flat lollipop circle.

  tree.png   56x96  broadleaf - textured bark, volumetric canopy
  bush.png   28x22  low shrub
  rock.png   24x18  mossy boulder
  stump.png  22x16  cut stump
  flower.png 12x14  wildflower cluster

Run:  python3 tools/gen_nature.py
"""

import math
import random

from pixelforge import Canvas, P, asset, lerp, shade


def _bark(c, x0, y0, x1, y1):
    """A rounded vertical trunk: lit left, shadow right, with grain."""
    c.rect(x0, y0, x1, y1, P.BARK[2])
    c.vline(x0, y0, y1, P.BARK[1])
    c.vline(x0 + 1, y0, y1, P.BARK[1])
    c.vline(x1, y0, y1, P.BARK[3])
    c.vline(x1 - 1, y0, y1, P.BARK[3])
    rnd = random.Random(7)
    for _ in range(8):                       # vertical bark grooves
        gx = rnd.randint(x0 + 2, x1 - 2)
        gy = rnd.randint(y0, y1 - 6)
        c.vline(gx, gy, min(y1, gy + rnd.randint(3, 7)), P.BARK[3])


def _canopy(c, cx, top, w, h, seed, pal=None):
    """Volumetric foliage: overlapping discs shaded by position (UL light)."""
    pal = pal or P.FOLIAGE
    rnd = random.Random(seed)
    cyc = top + h / 2
    clumps = []
    # Dark base mass first.
    for _ in range(10):
        ang = rnd.random() * 6.283
        rad = rnd.random() ** 0.5
        dx = (w * 0.42) * rad * math.cos(ang)
        dy = (h * 0.42) * rad * math.sin(ang)
        r = rnd.randint(7, 11)
        clumps.append((cx + dx, cyc + dy, r))
    for (x, y, r) in clumps:
        c.disc(x, y, r, pal[3])
    # Mid tone, pulled up-left.
    for (x, y, r) in clumps:
        c.disc(x - 1, y - 1, r - 1, pal[2])
    # Lit highlights on the upper-left of each clump.
    for (x, y, r) in clumps:
        if rnd.random() < 0.7:
            c.disc(x - r * 0.4, y - r * 0.5, max(2, r - 4), pal[1])
    for (x, y, r) in clumps:
        if rnd.random() < 0.4:
            c.disc(x - r * 0.5, y - r * 0.6, max(1, r - 6), pal[0])
    # Shadow pockets lower-right for depth.
    for (x, y, r) in clumps:
        if rnd.random() < 0.4:
            c.disc(x + r * 0.4, y + r * 0.5, max(1, r - 7), pal[4])
    # Ragged leaf specks around the silhouette.
    for (x, y, r) in clumps:
        for _ in range(3):
            sx = x + rnd.randint(-r, r)
            sy = y + rnd.randint(-r, r)
            if rnd.random() < 0.3:
                c.paint(int(sx), int(sy), pal[1])


def gen_tree(name="tree.png"):
    c = Canvas(56, 96)
    # Trunk with a root flare.
    _bark(c, 24, 40, 32, 92)
    c.rect(21, 88, 35, 92, P.BARK[2])         # flare
    c.vline(21, 88, 92, P.BARK[3]); c.vline(35, 88, 92, P.BARK[3])
    c.line(24, 40, 22, 30, P.BARK[2])         # a branch hint into canopy
    c.line(32, 40, 35, 31, P.BARK[2])
    # Canopy (towering, fills the upper two-thirds).
    _canopy(c, 28, 2, 54, 62, seed=4)
    c.rim_light(0.4)
    c.outline(P.OUTLINE, diagonal=True)
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(56x96)")


def gen_bush(name="bush.png"):
    c = Canvas(28, 22)
    _canopy(c, 14, 2, 26, 18, seed=9)
    # A couple of berries.
    rnd = random.Random(3)
    for _ in range(3):
        c.paint(rnd.randint(6, 21), rnd.randint(6, 14), (150, 60, 56, 255))
    c.rim_light(0.4)
    c.outline(P.OUTLINE, diagonal=True)
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(28x22)")


def gen_rock(name="rock.png"):
    c = Canvas(24, 18)
    # Boulder body.
    c.ellipse(12, 12, 11, 7, P.STONE[2])
    c.ellipse(11, 11, 9, 5, P.STONE[1])
    c.ellipse(10, 10, 5, 3, P.STONE[0])
    c.ellipse(14, 14, 7, 3, P.STONE[3])       # ground-contact shadow side
    # Moss on the top-left.
    rnd = random.Random(5)
    for _ in range(14):
        mx = rnd.randint(5, 14); my = rnd.randint(6, 11)
        c.paint(mx, my, P.FOLIAGE[1] if rnd.random() < 0.6 else P.FOLIAGE[2])
    c.rim_light(0.4)
    c.outline(P.OUTLINE, diagonal=True)
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(24x18)")


def gen_stump(name="stump.png"):
    c = Canvas(22, 16)
    c.rect(5, 6, 16, 14, P.BARK[2])
    c.vline(5, 6, 14, P.BARK[1]); c.vline(16, 6, 14, P.BARK[3])
    c.ellipse(11, 6, 6, 2, P.WOOD[1])         # cut top
    c.ellipse(11, 6, 4, 1, P.WOOD[0])
    c.ellipse(11, 6, 2, 1, P.WOOD[2])         # rings
    c.rim_light(0.4)
    c.outline(P.OUTLINE, diagonal=True)
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(22x16)")


def gen_flower(name="flower.png"):
    c = Canvas(12, 14)
    c.vline(5, 7, 13, P.FOLIAGE[2])           # stems
    c.vline(8, 8, 13, P.FOLIAGE[2])
    c.paint(4, 9, P.FOLIAGE[1]); c.paint(9, 10, P.FOLIAGE[1])
    for (fx, fy, col) in [(5, 4, (196, 176, 96, 255)),
                          (8, 6, (150, 110, 150, 255))]:
        c.disc(fx, fy, 2, col)
        c.paint(fx, fy, shade(col, 1.2))
    c.rim_light(0.4)
    c.outline(P.OUTLINE, diagonal=True)
    c.save(asset(name))
    print("generated", name, "(12x14)")


def main():
    gen_tree()
    gen_bush()
    gen_rock()
    gen_stump()
    gen_flower()


if __name__ == "__main__":
    main()
