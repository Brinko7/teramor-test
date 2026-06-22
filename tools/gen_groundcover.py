#!/usr/bin/env python3
"""Ground-cover decals for Teramor - the scatter that breaks the tiling repeat.

The world ground is a single 16px tile region-repeated across a 1200x900+ area,
so even seamless turf reads as a flat grid once your eye catches the period.
These are small, flat, TRANSPARENT-background accents that ProceduralArea strews
across the Decals layer (under the y-sorted entities) to dapple the ground with
life: grass tufts, wildflowers, pebble scatters, fallen leaves, moss patches and
dry desert brush. Biomes pick which ones suit their floor (see BiomeData
`groundcover_paths`).

All sit on the grounded palette (pixelforge `P`), low-saturation except the
deliberate flower accents. Each has a faint contact shadow so standing tufts read
as grounded rather than pasted.

  gc_tuft.png     16x12  a clump of meadow grass blades
  gc_flowers.png  16x12  grass with a few tiny flower heads (story accent colour)
  gc_pebbles.png  18x12  a scatter of small stones
  gc_leaves.png   18x12  fallen autumn leaves + twigs
  gc_moss.png     18x14  a ragged mossy / fern-floor blotch
  gc_brush.png    18x12  dry sun-bleached tussock + dust (desert/plains)

Run:  python3 tools/gen_groundcover.py
"""

import random

from pixelforge import Canvas, P, asset, lerp, shade, rgb


def _shadow(c, cx, by, rx):
    """A faint translucent contact pool under a standing clump."""
    c.ellipse(cx, by, rx, max(1.0, rx * 0.34), P.SHADOW)


def _blade(c, bx, by, length, lean, ramp):
    """One upright grass blade: dark base, lit tip, a slight lean."""
    x = float(bx)
    for i in range(length):
        y = by - i
        t = i / max(1, length - 1)
        col = ramp[3] if t < 0.34 else (ramp[2] if t < 0.7 else ramp[1])
        if i == length - 1:
            col = ramp[0]                       # lit tip catches the key light
        c.paint(int(round(x)), y, col)
        x += lean * (i / max(1, length - 1))


def gen_tuft(name="gc_tuft.png", seed=101, ramp=None, count=8):
    c = Canvas(16, 12)
    pal = ramp or P.GRASS
    rnd = random.Random(seed)
    _shadow(c, 8, 11, 5.0)
    for _ in range(count):
        bx = rnd.randrange(2, 14)
        by = rnd.randrange(9, 12)
        length = rnd.randrange(4, 8)
        lean = rnd.uniform(-0.45, 0.45)
        _blade(c, bx, by, length, lean, pal)
    c.save(asset(name))
    print("generated", name)


# Muted, deliberately-placed flower accents - the only saturated notes on the
# ground. Kept dusty so they sit in the grounded world, not a candy meadow.
FLOWERS = [
    (rgb(228, 224, 206), rgb(244, 240, 224)),   # white daisy
    (rgb(228, 196, 110), rgb(246, 222, 150)),   # pale gold
    (rgb(196, 122, 130), rgb(220, 158, 162)),   # dusty rose
    (rgb(166, 150, 196), rgb(196, 184, 220)),   # faint lavender
]


def gen_flowers(name="gc_flowers.png", seed=137):
    c = Canvas(16, 12)
    rnd = random.Random(seed)
    _shadow(c, 8, 11, 5.0)
    # A low bed of grass under the blooms.
    for _ in range(5):
        bx = rnd.randrange(2, 14)
        _blade(c, bx, rnd.randrange(9, 12), rnd.randrange(3, 6),
               rnd.uniform(-0.4, 0.4), P.GRASS)
    # Three or four little flower heads on short stems.
    for _ in range(rnd.randint(3, 4)):
        fx = rnd.randrange(3, 13)
        fy = rnd.randrange(3, 7)
        base, lit = FLOWERS[rnd.randrange(len(FLOWERS))]
        c.paint(fx, fy + 1, P.GRASS[2])             # stem
        c.paint(fx, fy + 2, P.GRASS[3])
        # petal ring around a centre, lit on the upper-left.
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            c.paint(fx + dx, fy + dy, base)
        c.paint(fx - 1, fy - 1, lit)
        c.paint(fx, fy, lerp(base, P.EMBER[0], 0.35))   # warm pollen centre
    c.save(asset(name))
    print("generated", name)


def _pebble(c, cx, cy, r, rnd):
    base = P.STONE[2]
    c.ellipse(cx, cy + 1, r + 0.4, r * 0.7, P.SHADOW)   # contact shadow
    c.ellipse(cx, cy, r, r * 0.8, base)
    c.ellipse(cx, cy, r, r * 0.8, P.STONE[3], fill=False)  # grounded edge
    c.paint(cx - 1, cy - 1, P.STONE[0])                 # lit cap
    if r > 2:
        c.paint(cx, cy - 1, P.STONE[1])


def gen_pebbles(name="gc_pebbles.png", seed=151):
    c = Canvas(18, 12)
    rnd = random.Random(seed)
    spots = []
    for _ in range(6):
        for _try in range(8):
            cx = rnd.randrange(3, 15)
            cy = rnd.randrange(4, 10)
            if all((cx - px) ** 2 + (cy - py) ** 2 > 9 for px, py in spots):
                spots.append((cx, cy))
                _pebble(c, cx, cy, rnd.choice([2, 2, 3]), rnd)
                break
    c.save(asset(name))
    print("generated", name)


# Warm fallen-leaf litter (autumn floor / forest duff).
LEAF = [rgb(176, 104, 52), rgb(150, 128, 64), rgb(122, 74, 42),
        rgb(96, 116, 60), rgb(160, 88, 44)]


def gen_leaves(name="gc_leaves.png", seed=173):
    c = Canvas(18, 12)
    rnd = random.Random(seed)
    for _ in range(10):
        lx = rnd.randrange(1, 16)
        ly = rnd.randrange(2, 11)
        col = LEAF[rnd.randrange(len(LEAF))]
        # a tiny 2-3px leaf: a short diagonal with a lit shoulder.
        c.paint(lx, ly, col)
        c.paint(lx + 1, ly, shade(col, 0.82))
        if rnd.random() < 0.7:
            c.paint(lx + (1 if rnd.random() < 0.5 else -1), ly - 1, shade(col, 1.12))
        c.paint(lx, ly + 1, P.SHADOW)
    # a couple of bare twigs.
    for _ in range(2):
        tx = rnd.randrange(2, 14)
        ty = rnd.randrange(3, 10)
        c.line(tx, ty, tx + rnd.randint(2, 4), ty + rnd.randint(-1, 1), P.BARK[2])
    c.save(asset(name))
    print("generated", name)


def gen_moss(name="gc_moss.png", seed=191):
    c = Canvas(18, 14)
    rnd = random.Random(seed)
    cx, cy = 9, 8
    rx, ry = 7.0, 5.0
    # A ragged organic blotch: scatter weighted-dark foliage dots inside an
    # ellipse mask so the edge stays soft/irregular (transparent fringe).
    for _ in range(150):
        ax = rnd.uniform(-1, 1)
        ay = rnd.uniform(-1, 1)
        if ax * ax + ay * ay > 1.0:
            continue
        x = int(round(cx + ax * rx))
        y = int(round(cy + ay * ry))
        edge = ax * ax + ay * ay
        if edge > 0.55 and rnd.random() < edge:        # thin the rim
            continue
        roll = rnd.random()
        col = P.FOLIAGE[3] if roll < 0.5 else (P.FOLIAGE[2] if roll < 0.82 else P.FOLIAGE[4])
        if rnd.random() < 0.12:
            col = P.FOLIAGE[1]                          # rare lit moss highlight
        c.paint(x, y, col)
    # a few short fern fronds standing off the top.
    for _ in range(3):
        fx = rnd.randrange(5, 14)
        _blade(c, fx, rnd.randrange(7, 9), rnd.randrange(3, 5),
               rnd.uniform(-0.3, 0.3), P.FOLIAGE)
    c.save(asset(name))
    print("generated", name)


def gen_brush(name="gc_brush.png", seed=211):
    c = Canvas(18, 12)
    rnd = random.Random(seed)
    _shadow(c, 9, 11, 5.5)
    # Sparse, pale, dry blades fanning out.
    for _ in range(9):
        bx = rnd.randrange(3, 15)
        by = rnd.randrange(9, 12)
        _blade(c, bx, by, rnd.randrange(4, 8), rnd.uniform(-0.6, 0.6), P.GRASS_DRY)
    # a couple of soil pebbles + dust specks at the base.
    for _ in range(3):
        c.paint(rnd.randrange(3, 15), rnd.randrange(9, 12), P.SOIL[3])
    for _ in range(4):
        c.paint(rnd.randrange(2, 16), rnd.randrange(8, 12), shade(P.GRASS_DRY[0], 1.08))
    c.save(asset(name))
    print("generated", name)


def main():
    gen_tuft()
    gen_flowers()
    gen_pebbles()
    gen_leaves()
    gen_moss()
    gen_brush()


if __name__ == "__main__":
    main()
