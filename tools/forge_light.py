#!/usr/bin/env python3
"""EXPERIMENT: form-and-light sprite rendering for Teramor.

Proves a new approach for the character engine: instead of stacking flat
rectangles and hand-shading them, build the figure from volumetric primitives
(ellipsoids / capsules) that carry real surface NORMALS, then light them with a
directional key + fill + ambient + depth-based occlusion + a warm rim, and
QUANTIZE the result hard into the grounded hue-shifted ramps so it stays crisp
pixel art (not a mushy 3D render). A clean selout finishes it.

Run:  python3 tools/forge_light.py   -> /tmp/hero_v2.png (+ scaled preview)
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas, P, rgb, hue_shift, lerp  # noqa: E402


def _norm(x, y, z):
    m = math.sqrt(x * x + y * y + z * z) or 1.0
    return x / m, y / m, z / m


# Lights (view space: +x right, +y down, +z toward viewer).
KEY = _norm(-0.55, -0.72, 0.55)     # warm sun, upper-left, slightly fronted
FILL = _norm(0.6, 0.1, 0.6)         # cool bounce from the lower-right
KEY_COL = (1.0, 0.96, 0.86)
FILL_COL = (0.74, 0.82, 0.95)
AMBIENT = 0.30
BANDS = 6                            # quantization steps -> crisp pixel ramps


# Material base tones (mid value); shading rotates these warm->cool by light.
MAT = {
    "skin":    rgb(216, 170, 128),
    "skin_d":  rgb(178, 130, 96),
    "tunic":   rgb(98, 112, 76),
    "leather": rgb(120, 84, 50),
    "trouser": rgb(82, 72, 54),
    "boot":    rgb(58, 48, 36),
    "hair":    rgb(104, 68, 40),
    "metal":   rgb(170, 174, 182),
}
SHINY = {"metal": 0.9, "leather": 0.18}


class Sculpt:
    """A normal/depth buffer you stamp volumetric forms into, then light."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        n = w * h
        self.depth = [-1e9] * n
        self.nx = [0.0] * n
        self.ny = [0.0] * n
        self.nz = [0.0] * n
        self.mat = [None] * n
        self.fill = [False] * n

    def _set(self, x, y, z, nx, ny, nz, mat):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        i = y * self.w + x
        if z > self.depth[i]:
            self.depth[i] = z
            self.nx[i], self.ny[i], self.nz[i] = nx, ny, nz
            self.mat[i] = mat
            self.fill[i] = True

    def ellipsoid(self, cx, cy, cz, rx, ry, rz, mat, squash_top=1.0):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                ux = (x + 0.5 - cx) / rx
                uy = (y + 0.5 - cy) / ry
                d = ux * ux + uy * uy
                if d > 1.0:
                    continue
                uz = math.sqrt(1.0 - d)
                z = cz + uz * rz
                nx, ny, nz = _norm(ux / rx, uy / ry, uz / rz)
                self._set(x, y, z, nx, ny, nz, mat)

    def capsule(self, x0, y0, z0, x1, y1, z1, r, mat, steps=None):
        steps = steps or int(max(abs(x1 - x0), abs(y1 - y0)) * 1.5) + 2
        for s in range(steps + 1):
            t = s / steps
            cx = x0 + (x1 - x0) * t
            cy = y0 + (y1 - y0) * t
            cz = z0 + (z1 - z0) * t
            self.ellipsoid(cx, cy, cz, r, r, r, mat)

    # -- lighting --
    def _ao(self, x, y):
        """Cheap cavity occlusion: how recessed is this pixel vs its neighbours."""
        i = y * self.w + x
        d0 = self.depth[i]
        tot, n = 0.0, 0
        for dy in (-2, -1, 1, 2):
            for dx in (-2, -1, 1, 2):
                xx, yy = x + dx, y + dy
                if 0 <= xx < self.w and 0 <= yy < self.h and self.fill[yy * self.w + xx]:
                    tot += self.depth[yy * self.w + xx]
                    n += 1
        if n == 0:
            return 1.0
        diff = d0 - tot / n                      # negative => sits in a pocket
        return max(0.55, min(1.0, 1.0 + diff * 0.05))

    def render(self):
        c = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                i = y * self.w + x
                if not self.fill[i]:
                    continue
                nx, ny, nz = self.nx[i], self.ny[i], self.nz[i]
                ndl = max(0.0, nx * KEY[0] + ny * KEY[1] + nz * KEY[2])
                ndf = max(0.0, nx * FILL[0] + ny * FILL[1] + nz * FILL[2])
                lum = AMBIENT + 0.66 * ndl + 0.18 * ndf
                lum *= self._ao(x, y)
                # rim: silhouette pixels (normal grazing the viewer) on the key side
                if nz < 0.42 and (nx * KEY[0] + ny * KEY[1]) > 0.05:
                    lum += 0.28
                lum = max(0.0, min(1.12, lum))
                # quantize to crisp bands
                q = round(lum * (BANDS - 1)) / (BANDS - 1)
                base = MAT[self.mat[i]]
                k = 1.0 - 2.0 * max(0.0, min(1.0, q))     # +1 dark .. -1 light
                col = hue_shift(base, k)
                # specular pop on shiny materials
                shiny = SHINY.get(self.mat[i], 0.0)
                if shiny and ndl > 0.86:
                    col = lerp(col, (255, 250, 240), shiny * (ndl - 0.86) / 0.14)
                c.paint(x, y, col)
        return c


def _selout(c):
    ink = P.OUTLINE
    snap = [c.at(x, y) for y in range(c.h) for x in range(c.w)]

    def op(x, y):
        return 0 <= x < c.w and 0 <= y < c.h and snap[y * c.w + x][3] != 0
    for y in range(c.h):
        for x in range(c.w):
            if op(x, y):
                continue
            if op(x - 1, y) or op(x + 1, y) or op(x, y - 1) or op(x, y + 1):
                c.paint(x, y, ink)


def build_hero():
    W, H = 46, 64
    s = Sculpt(W, H)
    cx = 23
    # Relief, not balloons: keep rz shallow vs rx/ry so forms read as raised
    # sprite-relief rather than spheres.
    # legs: thigh -> shin, tapering, with boots
    s.capsule(cx - 4, 44, 0, cx - 5, 52, 0, 3.2, "trouser")
    s.capsule(cx - 5, 52, 0, cx - 5, 58, 0, 2.5, "trouser")
    s.capsule(cx + 4, 44, 0, cx + 5, 52, 0, 3.2, "trouser")
    s.capsule(cx + 5, 52, 0, cx + 5, 58, 0, 2.5, "trouser")
    s.ellipsoid(cx - 5, 59, 1, 3.4, 2.6, 3.0, "boot")
    s.ellipsoid(cx + 5, 59, 1, 3.4, 2.6, 3.0, "boot")
    # pelvis
    s.ellipsoid(cx, 43, 0.5, 7.2, 4.0, 4.6, "trouser")
    # arms: upper arm -> forearm, tapering, hands; held a little off the body
    s.capsule(cx - 9, 25, 1.5, cx - 10, 33, 1.5, 2.7, "tunic")
    s.capsule(cx - 10, 33, 1.5, cx - 10, 41, 1.5, 2.3, "leather")
    s.capsule(cx + 9, 25, 1.5, cx + 10, 33, 1.5, 2.7, "tunic")
    s.capsule(cx + 10, 33, 1.5, cx + 10, 41, 1.5, 2.3, "leather")
    s.ellipsoid(cx - 10, 42, 2.0, 2.4, 2.4, 2.6, "skin")
    s.ellipsoid(cx + 10, 42, 2.0, 2.4, 2.4, 2.6, "skin")
    # torso: broad chest tapering to a waist (two stacked forms), shallow relief
    s.ellipsoid(cx, 28, 0, 9.0, 6.5, 5.0, "tunic")        # chest
    s.ellipsoid(cx, 36, 0, 6.8, 5.2, 4.4, "tunic")        # waist
    s.ellipsoid(cx, 28, 2.2, 7.4, 6.0, 4.6, "leather")    # jerkin proud of chest
    s.ellipsoid(cx, 35, 2.0, 6.0, 4.6, 4.0, "leather")
    s.ellipsoid(cx - 8, 24, 1, 3.6, 3.4, 3.6, "tunic")    # shoulders
    s.ellipsoid(cx + 8, 24, 1, 3.6, 3.4, 3.6, "tunic")
    # belt + metal buckle (spec highlight)
    s.ellipsoid(cx, 40, 1.0, 7.0, 1.8, 3.6, "leather")
    s.ellipsoid(cx, 40, 3.4, 1.8, 1.4, 1.4, "metal")
    # neck + head, shallow relief so the face stays a readable plane
    s.ellipsoid(cx, 21, 1, 2.8, 2.6, 2.6, "skin")
    s.ellipsoid(cx, 13, 1, 6.4, 7.4, 5.6, "skin")
    # hair: a cap proud of the skull
    s.ellipsoid(cx, 9.5, 1.5, 6.8, 5.2, 5.4, "hair")
    s.ellipsoid(cx - 5.5, 13, 1.0, 1.8, 4.6, 3.0, "hair")   # left temple fall
    s.ellipsoid(cx + 5.5, 13, 1.0, 1.8, 4.6, 3.0, "hair")   # right temple fall
    return s, cx


# --- crisp hand-detailing on top of the lit base (the "wow" layer) ----------

def _sk(base, k):
    return hue_shift(base, k)


def detail(c, cx):
    skin = MAT["skin"]
    hair = MAT["hair"]
    ink = (40, 30, 30, 255)
    # --- face (head centre ~ (cx,13)) ---
    eye_y = 14
    # brow ridge: a soft shadow framing the eyes
    c.paint(cx - 4, eye_y - 2, _sk(skin, 0.55))
    c.paint(cx - 3, eye_y - 2, _sk(skin, 0.45))
    c.paint(cx + 3, eye_y - 2, _sk(skin, 0.55))
    c.paint(cx + 4, eye_y - 2, _sk(skin, 0.65))
    # eye sockets (occlusion), whites, iris, catchlight
    for ex in (cx - 3, cx + 3):
        c.paint(ex, eye_y, (228, 224, 214, 255))      # sclera
        c.paint(ex + 1, eye_y, _sk(skin, 0.4))
        c.paint(ex, eye_y + 1, _sk(skin, 0.7))         # lower lid shadow
    c.paint(cx - 3, eye_y, ink)                        # iris (left, lit side gets catch)
    c.paint(cx + 3, eye_y, ink)
    c.paint(cx - 4, eye_y, (250, 244, 230, 255))       # catchlight on the key side
    # nose: a short shadow down the right of the bridge
    c.paint(cx, eye_y, _sk(skin, 0.25))
    c.paint(cx + 1, eye_y + 1, _sk(skin, 0.55))
    c.paint(cx, eye_y + 2, _sk(skin, 0.7))
    c.paint(cx + 1, eye_y + 2, _sk(skin, 0.85))
    # mouth
    c.paint(cx - 1, eye_y + 4, _sk(skin, 0.7))
    c.paint(cx, eye_y + 4, _sk(skin, 0.8))
    c.paint(cx + 1, eye_y + 4, _sk(skin, 0.7))
    c.paint(cx, eye_y + 5, _sk(skin, 0.5))             # lit lower lip
    # --- hair strands: flowing highlights + a part ---
    for hx in range(cx - 6, cx + 7):
        # crown highlight band catching the key light (upper-left brightest)
        t = (hx - (cx - 6)) / 12.0
        c.paint(hx, 7, _sk(hair, -0.6 + t * 0.8))
    c.paint(cx - 4, 6, _sk(hair, -0.85))               # bright forelock
    c.paint(cx - 3, 7, _sk(hair, -0.7))
    c.paint(cx + 1, 6, _sk(hair, -0.2))                # off-centre part shadow
    for sy in range(9, 17):                            # side strand shadows
        c.paint(cx - 6, sy, _sk(hair, 0.6))
        c.paint(cx + 6, sy, _sk(hair, 0.75))
    # a few flow strands over the crown
    for hx, hy, k in ((cx - 2, 8, -0.5), (cx + 2, 8, 0.1), (cx - 4, 10, -0.3)):
        c.paint(hx, hy, _sk(hair, k))
    # --- gear seams: jerkin centre lace + collar + chest strap ---
    lea = MAT["leather"]
    for jy in range(25, 39):
        c.paint(cx, jy, _sk(lea, 0.7))                 # centre seam
    for jy in range(26, 38, 3):
        c.paint(cx, jy, _sk(lea, -0.4))               # lacing knots catch light
    c.paint(cx - 5, 24, _sk(MAT["tunic"], -0.3))       # lit collar
    c.paint(cx + 5, 24, _sk(MAT["tunic"], 0.4))
    for sx in range(cx - 5, cx + 6):                   # diagonal chest strap
        c.paint(sx, 31 + (sx - (cx - 5)) // 3, _sk(lea, 0.6))


def main():
    s, cx = build_hero()
    c = s.render()
    detail(c, cx)
    _selout(c)
    c.save("/tmp/hero_v2.png")
    c.scaled(8).save("/tmp/hero_v2_8x.png")
    print("wrote /tmp/hero_v2.png  (%dx%d)" % (c.w, c.h))


if __name__ == "__main__":
    main()
