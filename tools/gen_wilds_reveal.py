#!/usr/bin/env python3
"""Bakes the art for the **Cursed Wilds reveal cutscene** — the one-time cinematic
the first time you cross the threshold: a colossal Great Tree (Tera) towering in the
far distance, above a jagged forest, under an ominous blighted sky.

A cutscene is a composed full-screen shot, so it isn't bound by the gameplay camera's
no-sky clamp — we paint the whole vista here. Three layers (parallaxed in-engine):
  * wilds_sky.png      — 480x270 ominous gradient (indigo -> sickly horizon)
  * great_tree_far.png — the towering distant silhouette, faint blight at its heart
  * wilds_treeline.png — a wide jagged band of lesser trees it dwarfs

Built on pixelforge (stdlib only). Run: python3 tools/gen_wilds_reveal.py
"""

import os
import sys
import random
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas, rgb, lerp

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "placeholder")

# --- The Great Tree silhouette (distant, looming) --------------------------

GW, GH = 220, 300
CAN_M = rgb(40, 54, 48)
CAN_D = rgb(30, 42, 38)
CAN_K = rgb(22, 32, 30)
TRK_M = rgb(40, 36, 36)
TRK_D = rgb(28, 26, 28)
GLOW = rgb(150, 196, 150)
EDGE = rgb(16, 22, 22)


def _lf(a, b, t):
    return a + (b - a) * t


def great_tree():
    rng = random.Random(7)
    c = Canvas(GW, GH)
    cx = GW // 2
    base_y = GH - 2
    # root flares + tapering bole up to the crown split
    for s in (-1, 1):
        for i in range(26):
            t = i / 26.0
            x0 = cx + s * int(14 + t * 30)
            y = base_y - i
            c.rect(min(x0, cx + s * 14), y, max(x0, cx + s * 14), y, TRK_D)
    top = 150
    for y in range(base_y, top, -1):
        t = (base_y - y) / float(base_y - top)
        half = int(20 * (1.0 - t) + 7 * t)
        c.rect(cx - half, y, cx + half, y, TRK_M)
        c.rect(cx + half - 1, y, cx + half, y, TRK_D)
    for s, x1, y1 in [(-1, 56, 96), (1, 60, 92), (0, 100, 70)]:
        for i in range(22):
            t = i / 22.0
            x = int(_lf(cx + s * 6, x1, t)); y = int(_lf(150, y1, t))
            w = int(7 * (1.0 - t) + 2 * t)
            c.rect(x - w, y - w, x + w, y + w, TRK_D)
    # crown — billowing lobes, dark
    lobes = [
        (cx, 96, 64), (cx - 50, 120, 40), (cx + 52, 118, 42),
        (cx - 30, 64, 40), (cx + 34, 60, 42), (cx, 44, 38),
        (cx - 72, 150, 28), (cx + 74, 146, 30), (cx - 18, 150, 34),
        (cx + 22, 152, 34), (cx, 150, 34), (cx + 8, 26, 26), (cx - 24, 30, 24),
    ]
    for x, y, r in sorted(lobes, key=lambda L: -L[1]):
        c.disc(x, y, r, CAN_K)
        c.disc(x, y - 1, r - 1, CAN_D)
        c.disc(x, y - 1, max(2, r - 3), CAN_M)
    c.outline(EDGE)
    c.save(os.path.join(OUT, "great_tree_far.png"))
    print("  baked great_tree_far.png (%dx%d)" % (GW, GH))
    return c


# --- The blighted sky -------------------------------------------------------

def sky():
    w, h = 480, 270
    c = Canvas(w, h)
    top = rgb(34, 36, 60)        # deep indigo
    mid = rgb(64, 58, 82)        # bruised violet
    horizon = rgb(150, 150, 108) # sickly pale haze
    for y in range(h):
        t = y / float(h - 1)
        if t < 0.62:
            col = lerp(top, mid, t / 0.62)
        else:
            col = lerp(mid, horizon, (t - 0.62) / 0.38)
        c.rect(0, y, w - 1, y, col)
    c.save(os.path.join(OUT, "wilds_sky.png"))
    print("  baked wilds_sky.png (%dx%d)" % (w, h))
    return c


# --- The lesser forest it dwarfs (wide, for parallax) ----------------------

def treeline():
    w, h = 720, 110
    c = Canvas(w, h)
    rng = random.Random(3)
    far = rgb(40, 46, 52)
    near = rgb(20, 26, 26)
    # two depth bands of jagged spires
    for band, (col, base, hmin, hmax, step) in enumerate(
            [(far, h - 44, 24, 50, 9), (near, h - 2, 40, 86, 11)]):
        x = -6
        while x < w + 6:
            th = rng.randint(hmin, hmax)
            tw = rng.randint(step - 2, step + 4)
            tip = base - th
            for yy in range(tip, base + 1):
                t = (yy - tip) / float(max(1, base - tip))
                half = int(tw * t)
                c.rect(x - half, yy, x + half, yy, col)
            x += rng.randint(step - 3, step + 2)
    # solid dark base so the foreground reads as a continuous forest edge (no sky
    # or haze peeking through gaps at the bottom)
    c.rect(0, h - 16, w - 1, h - 1, near)
    c.save(os.path.join(OUT, "wilds_treeline.png"))
    print("  baked wilds_treeline.png (%dx%d)" % (w, h))
    return c


def haze():
    """A soft pale horizon veil that pushes the distant tree back behind the nearer
    forest — atmospheric perspective. Transparent except a band low on the screen."""
    w, h = 480, 270
    c = Canvas(w, h)
    pale = rgb(150, 150, 116)
    for y in range(h):
        # 0 high up -> peak around the horizon (y~180) -> ease off toward the bottom
        if y < 120:
            a = 0
        elif y < 178:
            a = int(76 * (y - 120) / 58.0)
        else:
            a = int(76 * max(0.0, 1.0 - (y - 178) / 34.0))
        if a > 0:
            c.rect(0, y, w - 1, y, rgb(pale[0], pale[1], pale[2], a))
    c.save(os.path.join(OUT, "wilds_haze.png"))
    print("  baked wilds_haze.png (%dx%d)" % (w, h))
    return c


def preview(tree, sky_c, hz, tline):
    """Composite the cutscene's opening frame to /tmp so the shot can be eyeballed.
    Layer order = sky -> distant tree -> haze veil -> foreground treeline."""
    c = Canvas(480, 270)
    c.blit(sky_c, 0, 0, mode="over")
    big = tree.scaled(1)
    # base low (behind the forest) so only the towering crown clears the treeline
    c.blit(big, 240 - GW // 2, 286 - GH, mode="over")
    c.blit(hz, 0, 0, mode="over")
    c.blit(tline, -120, 270 - 110, mode="over")
    c.scaled(2).save("/tmp/wilds_reveal_preview.png")
    print("  preview -> /tmp/wilds_reveal_preview.png")


def main():
    t = great_tree()
    s = sky()
    hz = haze()
    tl = treeline()
    preview(t, s, hz, tl)


if __name__ == "__main__":
    main()
