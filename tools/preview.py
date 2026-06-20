#!/usr/bin/env python3
"""Visual QA helper - montage generated sprites at a readable zoom.

Two views:
  tile_preview(name, reps, zoom)  -> tiles a ground tile reps*reps to check that
                                     it's SEAMLESS, then scales up.
  row_preview(names, zoom, ...)   -> lays sprites in a row on a neutral ground,
                                     base-aligned, to compare silhouettes/scale.

Writes into assets/placeholder/_preview_*.png so they can be eyeballed.
Usage:  python3 tools/preview.py [terrain|props|<name> ...]
"""

import sys

from pixelforge import Canvas, P, asset, load_png, lerp


def _checker(w, h, a=(60, 64, 58, 255), b=(52, 56, 50, 255)):
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            c.paint(x, y, a if ((x // 4 + y // 4) & 1) == 0 else b)
    return c


def tile_preview(name, reps=6, zoom=4, out=None):
    t = load_png(asset(name))
    big = Canvas(t.w * reps, t.h * reps)
    for j in range(reps):
        for i in range(reps):
            big.blit(t, i * t.w, j * t.h)
    big = big.scaled(zoom)
    out = out or "_preview_" + name
    big.save(asset(out))
    print("tiled", name, "->", out, "(%dx%d)" % (big.w, big.h))


def row_preview(names, zoom=4, pad=6, ground=None, out="_preview_row.png"):
    sprites = [(n, load_png(asset(n))) for n in names]
    gap = pad
    w = sum(s.w for _, s in sprites) + gap * (len(sprites) + 1)
    h = max(s.h for _, s in sprites) + gap * 2
    base = h - gap
    c = Canvas(w, h)
    # Neutral grounded backdrop with a faint ground line.
    c.v_gradient(0, 0, w - 1, h - 1, (74, 82, 66, 255), (52, 58, 46, 255))
    c.hline(0, w - 1, base, lerp((52, 58, 46, 255), P.OUTLINE, 0.3))
    x = gap
    for _, s in sprites:
        c.blit(s, x, base - s.h, mode="over")
        x += s.w + gap
    c = c.scaled(zoom)
    c.save(asset(out))
    print("row ->", out, "(%dx%d)" % (c.w, c.h), "::", ", ".join(n for n, _ in sprites))


def player_frame(sheet="player.png", fw=24, fh=40, col=0, row=0):
    """Pull one facing frame out of the 4x4 character sheet."""
    s = load_png(asset(sheet))
    return s.region(col * fw, row * fh, fw, fh)


def scale_check(names, zoom=4, pad=8, on_grass=True, out="_preview_scale.png"):
    """Base-align a player frame next to props/buildings to sanity-check scale."""
    sprites = [("player(frame)", player_frame())]
    for n in names:
        sprites.append((n, load_png(asset(n))))
    gap = pad
    w = sum(s.w for _, s in sprites) + gap * (len(sprites) + 1)
    h = max(s.h for _, s in sprites) + gap * 3
    base = h - gap * 2
    c = Canvas(w, h)
    if on_grass:
        g = load_png(asset("grass.png"))
        for j in range((h // g.h) + 1):
            for i in range((w // g.w) + 1):
                c.blit(g, i * g.w, j * g.h)
        c.rect_over(0, 0, w - 1, h - 1, (30, 30, 40, 70))   # dim for contrast
    else:
        c.v_gradient(0, 0, w - 1, h - 1, (74, 82, 66, 255), (52, 58, 46, 255))
    # ground line at the base + 16px tick marks up the left edge.
    c.hline(0, w - 1, base, (24, 22, 26, 180))
    for t in range(0, h, 16):
        c.vline(2, base - t, base - t, (220, 210, 160, 200))
    x = gap
    for _, s in sprites:
        c.blit(s, x, base - s.h, mode="over")
        x += s.w + gap
    c = c.scaled(zoom)
    c.save(asset(out))
    print("scale ->", out, "(%dx%d)" % (c.w, c.h), "::",
          ", ".join("%s %dx%d" % (n, s.w, s.h) for n, s in sprites))


def main(argv):
    mode = argv[0] if argv else "terrain"
    if mode == "terrain":
        for n in ("grass.png", "grass_dry.png", "dirt.png", "path.png", "water.png"):
            tile_preview(n)
    elif mode == "scale":
        scale_check(argv[1:] or ["cabin.png", "tree.png"])
    elif mode == "props":
        row_preview(argv[1:] or ["tree.png", "cabin.png", "player.png"])
    else:
        # Treat args as sprite names for a row.
        row_preview(argv)


if __name__ == "__main__":
    main(sys.argv[1:])
