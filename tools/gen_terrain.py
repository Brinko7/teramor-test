#!/usr/bin/env python3
"""Ground tiles for Teramor - seamless, grounded, on the 16px grid.

Builds the terrain the whole world stands on: grass (the default fill), bare
dirt, a trodden path, and water. Every tile is SEAMLESS (periodic value noise),
so it tiles across a 640x480 ground with no visible grid. Tones are pulled from
the grounded palette in pixelforge - low-contrast, earthy, a little dusty.

  grass.png   16x16  meadow turf (replaces the old flat-green fill)
  grass_dry.png 16x16 sun-bleached variant
  dirt.png    16x16  bare packed earth
  path.png    16x16  worn dirt path / road
  water.png   16x16  still water with faint ripples

Run:  python3 tools/gen_terrain.py
"""

import random

from pixelforge import Canvas, P, asset, lerp, shade


def _smooth(t):
    return t * t * (3 - 2 * t)               # smoothstep -> no diagonal ramps


def _octave(w, h, cells, seed):
    """A seamless value field in [0,1] from a wrapping lattice (smoothstep)."""
    rnd = random.Random(seed)
    lat = [[rnd.random() for _ in range(cells)] for _ in range(cells)]
    sx = w / cells
    sy = h / cells
    field = [[0.0] * w for _ in range(h)]
    for yy in range(h):
        fy = yy / sy
        gy = int(fy) % cells
        ty = _smooth(fy - int(fy))
        gy1 = (gy + 1) % cells
        for xx in range(w):
            fx = xx / sx
            gx = int(fx) % cells
            tx = _smooth(fx - int(fx))
            gx1 = (gx + 1) % cells
            top = lat[gy][gx] + (lat[gy][gx1] - lat[gy][gx]) * tx
            bot = lat[gy1][gx] + (lat[gy1][gx1] - lat[gy1][gx]) * tx
            field[yy][xx] = top + (bot - top) * ty
    return field


def seamless(c, palette, seed, octaves=((3, 0.6), (6, 0.3), (12, 0.1)),
             contrast=0.7, x0=0, y0=0, x1=None, y1=None):
    """Fill a rect with SEAMLESS multi-octave noise (earthy, low-contrast).

    Octaves are summed so no single lattice repeat dominates; `contrast` pulls
    values toward the mid band so the texture reads as grain, not a motif.
    """
    if x1 is None:
        x1 = c.w - 1
    if y1 is None:
        y1 = c.h - 1
    w = x1 - x0 + 1
    h = y1 - y0 + 1
    fields = [(_octave(w, h, cells, seed + i * 17), wt)
              for i, (cells, wt) in enumerate(octaves)]
    wsum = sum(wt for _, wt in octaves)
    n = len(palette)
    for yy in range(h):
        for xx in range(w):
            v = sum(f[yy][xx] * wt for f, wt in fields) / wsum
            v = 0.5 + (v - 0.5) * contrast          # compress toward mid
            idx = min(n - 1, max(0, int(v * n)))
            c.paint(x0 + xx, y0 + yy, palette[idx])


def gen_grass(name="grass.png", base=None, seed=11, blades=True):
    c = Canvas(16, 16)
    pal = base or P.GRASS
    # Fine, even grain (small features) so it reads as turf, not a motif.
    band = [pal[1], pal[1], pal[2], pal[2], pal[3]]
    seamless(c, band, seed, octaves=((4, 0.35), (8, 0.4), (16, 0.25)),
             contrast=1.0)
    if blades:
        rnd = random.Random(seed + 5)
        # Upright blades - darker base, lit tip. Wrap x so it stays seamless.
        for _ in range(16):
            bx = rnd.randrange(16)
            by = rnd.randrange(3, 15)
            c.paint(bx, by, pal[3])
            c.paint(bx, by - 1, pal[1] if rnd.random() < 0.5 else pal[2])
            if rnd.random() < 0.35:
                c.paint(bx, by - 2, shade(pal[0], 1.06))
        # A few darker dapples + pale tips for organic variation.
        for _ in range(6):
            c.paint(rnd.randrange(16), rnd.randrange(16), pal[4])
        for _ in range(5):
            c.paint(rnd.randrange(16), rnd.randrange(16), shade(pal[0], 1.12))
    c.save(asset(name))
    print("generated", name)


def gen_dirt(name="dirt.png", seed=23):
    c = Canvas(16, 16)
    seamless(c, [P.SOIL[0], P.SOIL[1], P.SOIL[1], P.SOIL[2], P.SOIL[2], P.SOIL[3]],
             seed, octaves=((4, 0.35), (8, 0.4), (16, 0.25)), contrast=0.95)
    rnd = random.Random(seed + 2)
    warm_stone = (118, 106, 92, 255)
    for _ in range(9):                  # warm pebbles + dark clods
        x, y = rnd.randrange(16), rnd.randrange(16)
        c.paint(x, y, P.SOIL[4] if rnd.random() < 0.5 else warm_stone)
    for _ in range(5):
        c.paint(rnd.randrange(16), rnd.randrange(16), shade(P.SOIL[0], 1.12))
    c.save(asset(name))
    print("generated", name)


def gen_path(name="path.png", seed=31):
    c = Canvas(16, 16)
    seamless(c, [P.PATH[0], P.PATH[1], P.PATH[1], P.PATH[2], P.PATH[3]],
             seed, contrast=0.75)
    rnd = random.Random(seed + 3)
    warm_gravel = (150, 140, 124, 255)
    # Embedded gravel + faint wheel-worn streaks.
    for _ in range(9):
        x, y = rnd.randrange(16), rnd.randrange(16)
        c.paint(x, y, warm_gravel if rnd.random() < 0.5 else P.PATH[3])
    for _ in range(3):
        x, y = rnd.randrange(16), rnd.randrange(16)
        c.paint(x, y, shade(P.PATH[0], 1.1))
    c.save(asset(name))
    print("generated", name)


def gen_water(name="water.png", seed=47):
    c = Canvas(16, 16)
    # Calm, soft tonal swell - no discrete glints (they'd grid-repeat); a scroll
    # shader can animate this later.
    seamless(c, [P.WATER[0], P.WATER[1], P.WATER[2], P.WATER[2], P.WATER[3]],
             seed, octaves=((3, 0.55), (6, 0.45)), contrast=0.8)
    c.save(asset(name))
    print("generated", name)


def main():
    gen_grass()
    gen_grass("grass_dry.png", base=P.GRASS_DRY, seed=71)
    gen_dirt()
    gen_path()
    gen_water()


if __name__ == "__main__":
    main()
