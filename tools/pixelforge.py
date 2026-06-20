#!/usr/bin/env python3
"""pixelforge - Teramor's dependency-free procedural pixel-art engine.

The shared toolkit every `gen_*.py` builds on. No third-party deps: PNGs are
encoded with the stdlib (zlib + struct). Everything operates on a `Canvas`, an
RGBA8 buffer with per-instance width/height, so a generator can paint a 16px
tile or a 128px building with the same primitives.

The "art bible" (also in CLAUDE.md):
  * TILE = 16 px. The world is laid out on a 16px grid.
  * Sprites are FOOT-ANCHORED: the art's visual base sits at the node origin
    (.tscn uses `centered = false` + `offset = (-w/2, -base)`), so y-sort and
    placement are predictable.
  * LIGHT comes from the upper-left; surfaces darken toward the lower-right.
  * Palette is GROUNDED & naturalistic - earthy, desaturated, a little dusty.
    Saturated/candy colors are deliberately avoided.
"""

import math
import os
import random
import struct
import zlib

TILE = 16


# --- color helpers ----------------------------------------------------------

def rgb(r, g, b, a=255):
    return (int(r), int(g), int(b), int(a))


def clampc(v):
    return 0 if v < 0 else (255 if v > 255 else int(v))


def shade(c, f):
    """Multiply toward black (f<1) or white (f>1) keeping alpha."""
    if f <= 1.0:
        return (clampc(c[0] * f), clampc(c[1] * f), clampc(c[2] * f),
                c[3] if len(c) > 3 else 255)
    t = f - 1.0
    return (clampc(c[0] + (255 - c[0]) * t), clampc(c[1] + (255 - c[1]) * t),
            clampc(c[2] + (255 - c[2]) * t), c[3] if len(c) > 3 else 255)


def lerp(a, b, t):
    return (clampc(a[0] + (b[0] - a[0]) * t), clampc(a[1] + (b[1] - a[1]) * t),
            clampc(a[2] + (b[2] - a[2]) * t),
            clampc((a[3] if len(a) > 3 else 255)
                   + ((b[3] if len(b) > 3 else 255)
                      - (a[3] if len(a) > 3 else 255)) * t))


def ramp(base, steps=5, lo=0.55, hi=1.28):
    """Build a light->dark ramp (index 0 = lightest) around a base color."""
    out = []
    for i in range(steps):
        t = i / (steps - 1)             # 0..1
        f = hi + (lo - hi) * t
        out.append(shade(base, f))
    return out


# --- Grounded palette -------------------------------------------------------
# Ramps are ordered light -> dark. Hand-tuned earthy tones, low saturation.

class P:
    GRASS = [rgb(126, 142, 86), rgb(104, 122, 70), rgb(84, 102, 56),
             rgb(66, 84, 46), rgb(50, 66, 38)]
    GRASS_DRY = [rgb(150, 146, 92), rgb(128, 122, 76), rgb(104, 100, 62),
                 rgb(82, 80, 50), rgb(64, 62, 40)]
    SOIL = [rgb(120, 92, 62), rgb(98, 72, 48), rgb(78, 56, 38),
            rgb(60, 42, 28), rgb(44, 30, 20)]
    PATH = [rgb(146, 130, 104), rgb(122, 107, 84), rgb(100, 87, 68),
            rgb(80, 69, 54), rgb(62, 53, 42)]
    STONE = [rgb(150, 150, 156), rgb(124, 124, 132), rgb(98, 99, 108),
             rgb(74, 76, 86), rgb(54, 56, 66)]
    WOOD = [rgb(150, 110, 70), rgb(124, 88, 54), rgb(98, 68, 42),
            rgb(74, 50, 30), rgb(52, 35, 22)]
    WOOD_GREY = [rgb(140, 130, 118), rgb(112, 103, 92), rgb(88, 80, 71),
                 rgb(66, 60, 53), rgb(48, 43, 38)]
    ROOF = [rgb(150, 78, 60), rgb(122, 62, 48), rgb(96, 48, 38),
            rgb(72, 36, 28), rgb(52, 26, 20)]
    ROOF_SLATE = [rgb(96, 104, 116), rgb(76, 84, 96), rgb(60, 67, 78),
                  rgb(46, 52, 62), rgb(34, 39, 48)]
    THATCH = [rgb(176, 150, 92), rgb(150, 124, 72), rgb(124, 100, 56),
              rgb(98, 78, 42), rgb(74, 58, 32)]
    PLASTER = [rgb(206, 192, 162), rgb(180, 166, 137), rgb(154, 140, 114),
               rgb(126, 113, 90), rgb(98, 87, 68)]
    WATER = [rgb(92, 124, 132), rgb(72, 104, 116), rgb(56, 86, 100),
             rgb(42, 68, 82), rgb(30, 50, 64)]
    FOLIAGE = [rgb(96, 124, 70), rgb(76, 104, 56), rgb(58, 84, 44),
               rgb(44, 66, 34), rgb(32, 50, 26)]
    BARK = [rgb(108, 84, 60), rgb(86, 64, 44), rgb(66, 48, 32),
            rgb(48, 34, 22), rgb(34, 24, 16)]
    METAL = [rgb(176, 180, 188), rgb(142, 147, 156), rgb(110, 115, 124),
             rgb(82, 86, 96), rgb(58, 62, 70)]
    LEATHER = [rgb(150, 110, 68), rgb(122, 86, 50), rgb(96, 66, 38),
               rgb(72, 48, 28), rgb(52, 34, 20)]
    CLOTH = [rgb(120, 92, 84), rgb(98, 74, 68), rgb(78, 58, 54),
             rgb(60, 44, 41), rgb(44, 32, 30)]
    OUTLINE = rgb(34, 28, 30)
    OUTLINE_SOFT = rgb(48, 40, 42)
    SHADOW = rgb(20, 18, 24, 90)      # translucent contact shadow
    NIGHT = rgb(40, 46, 78)
    EMBER = [rgb(255, 224, 150), rgb(248, 170, 70), rgb(214, 96, 40),
             rgb(150, 52, 32)]


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


# --- Canvas -----------------------------------------------------------------

class Canvas:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.buf = bytearray(w * h * 4)

    def inb(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def paint(self, x, y, c):
        """Replace pixel (skips fully transparent source)."""
        if not self.inb(x, y):
            return
        if len(c) == 3:
            c = (c[0], c[1], c[2], 255)
        if c[3] == 0:
            return
        i = (y * self.w + x) * 4
        self.buf[i] = c[0]; self.buf[i + 1] = c[1]
        self.buf[i + 2] = c[2]; self.buf[i + 3] = c[3]

    def over(self, x, y, c):
        """Alpha-composite c over the existing pixel."""
        if not self.inb(x, y):
            return
        if len(c) == 3:
            return self.paint(x, y, c)
        a = c[3]
        if a == 0:
            return
        if a == 255:
            return self.paint(x, y, c)
        i = (y * self.w + x) * 4
        da = self.buf[i + 3]
        ia = 255 - a
        oa = a + da * ia // 255
        if oa == 0:
            return
        self.buf[i] = (c[0] * a + self.buf[i] * da * ia // 255) // oa
        self.buf[i + 1] = (c[1] * a + self.buf[i + 1] * da * ia // 255) // oa
        self.buf[i + 2] = (c[2] * a + self.buf[i + 2] * da * ia // 255) // oa
        self.buf[i + 3] = oa

    def erase(self, x, y):
        if not self.inb(x, y):
            return
        i = (y * self.w + x) * 4
        self.buf[i] = self.buf[i + 1] = self.buf[i + 2] = self.buf[i + 3] = 0

    def at(self, x, y):
        if not self.inb(x, y):
            return (0, 0, 0, 0)
        i = (y * self.w + x) * 4
        return (self.buf[i], self.buf[i + 1], self.buf[i + 2], self.buf[i + 3])

    def opaque(self, x, y):
        return self.inb(x, y) and self.buf[(y * self.w + x) * 4 + 3] != 0

    # -- shapes --
    def rect(self, x0, y0, x1, y1, c):
        if x1 < x0:
            x0, x1 = x1, x0
        if y1 < y0:
            y0, y1 = y1, y0
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.paint(x, y, c)

    def rect_over(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.over(x, y, c)

    def frame(self, x0, y0, x1, y1, c):
        self.rect(x0, y0, x1, y0, c)
        self.rect(x0, y1, x1, y1, c)
        self.rect(x0, y0, x0, y1, c)
        self.rect(x1, y0, x1, y1, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def line(self, x0, y0, x1, y1, c):
        dx = abs(x1 - x0); dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.paint(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy; x0 += sx
            if e2 <= dx:
                err += dx; y0 += sy

    def ellipse(self, cx, cy, rx, ry, c, fill=True):
        rx = max(rx, 0.5); ry = max(ry, 0.5)
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                nx = (x + 0.5 - cx) / rx
                ny = (y + 0.5 - cy) / ry
                d = nx * nx + ny * ny
                if fill and d <= 1.0:
                    self.paint(x, y, c)
                elif not fill and 0.72 <= d <= 1.0:
                    self.paint(x, y, c)

    def disc(self, cx, cy, r, c):
        self.ellipse(cx, cy, r, r, c, True)

    def shade_rect(self, x0, y0, x1, y1, light, mid, dark):
        """Filled rect with a cheap upper-left-lit bevel -> reads as volume."""
        self.rect(x0, y0, x1, y1, mid)
        self.rect(x0, y0, x1, y0, light)
        self.rect(x0, y0, x0, y1, light)
        self.rect(x0, y1, x1, y1, dark)
        self.rect(x1, y0, x1, y1, dark)

    def v_gradient(self, x0, y0, x1, y1, top, bottom):
        h = max(y1 - y0, 1)
        for y in range(y0, y1 + 1):
            self.rect(x0, y, x1, y, lerp(top, bottom, (y - y0) / h))

    def h_gradient(self, x0, y0, x1, y1, left, right):
        w = max(x1 - x0, 1)
        for x in range(x0, x1 + 1):
            self.rect(x, y0, x, y1, lerp(left, right, (x - x0) / w))

    def dither(self, x0, y0, x1, y1, a, b, density=0.5):
        """Ordered (Bayer) dither between a and b across a rect."""
        thr = max(0, min(16, int(density * 16)))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.paint(x, y, b if BAYER4[y & 3][x & 3] < thr else a)

    def speckle(self, x0, y0, x1, y1, colors, rnd, chance=0.18):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if rnd.random() < chance:
                    self.paint(x, y, colors[rnd.randrange(len(colors))])

    def mottle(self, x0, y0, x1, y1, palette, rnd, scale=3):
        """Fill a rect with smooth value-noise picked from a light->dark ramp."""
        n = len(palette)
        gw = (x1 - x0) // scale + 2
        gh = (y1 - y0) // scale + 2
        grid = [[rnd.random() for _ in range(gw)] for _ in range(gh)]
        for y in range(y0, y1 + 1):
            fy = (y - y0) / scale
            gy = int(fy); ty = fy - gy
            for x in range(x0, x1 + 1):
                fx = (x - x0) / scale
                gx = int(fx); tx = fx - gx
                v00 = grid[gy][gx]; v10 = grid[gy][gx + 1]
                v01 = grid[gy + 1][gx]; v11 = grid[gy + 1][gx + 1]
                top = v00 + (v10 - v00) * tx
                bot = v01 + (v11 - v01) * tx
                v = top + (bot - top) * ty
                self.paint(x, y, palette[min(n - 1, int(v * n))])

    # -- post --
    def outline(self, color=P.OUTLINE, diagonal=False):
        snap = bytes(self.buf)

        def op(x, y):
            return (0 <= x < self.w and 0 <= y < self.h
                    and snap[(y * self.w + x) * 4 + 3] != 0)
        for y in range(self.h):
            for x in range(self.w):
                if op(x, y):
                    continue
                hit = op(x - 1, y) or op(x + 1, y) or op(x, y - 1) or op(x, y + 1)
                if not hit and diagonal:
                    hit = (op(x - 1, y - 1) or op(x + 1, y - 1)
                           or op(x - 1, y + 1) or op(x + 1, y + 1))
                if hit:
                    self.paint(x, y, color)

    def drop_shadow(self, color=P.SHADOW):
        """Soft elliptical contact shadow at the base of the opaque cluster."""
        minx, maxx, maxy = self.w, -1, -1
        for y in range(self.h):
            for x in range(self.w):
                if self.opaque(x, y):
                    minx = min(minx, x); maxx = max(maxx, x); maxy = max(maxy, y)
        if maxy < 0:
            return
        cx = (minx + maxx) / 2
        rx = max((maxx - minx) / 2, 2)
        below = Canvas(self.w, self.h)
        below.ellipse(cx, maxy - 1, rx, max(rx * 0.34, 1.5), color, True)
        for y in range(self.h):
            for x in range(self.w):
                if below.opaque(x, y) and not self.opaque(x, y):
                    self.over(x, y, below.at(x, y))

    def replace(self, a, b):
        for y in range(self.h):
            for x in range(self.w):
                p = self.at(x, y)
                if p[:3] == a[:3] and p[3] != 0:
                    self.paint(x, y, (b[0], b[1], b[2], p[3]))

    def tint(self, color):
        for i in range(0, len(self.buf), 4):
            if self.buf[i + 3]:
                self.buf[i] = self.buf[i] * color[0] // 255
                self.buf[i + 1] = self.buf[i + 1] * color[1] // 255
                self.buf[i + 2] = self.buf[i + 2] * color[2] // 255

    def blit(self, other, dx, dy, mode="paint"):
        f = self.over if mode == "over" else self.paint
        for y in range(other.h):
            for x in range(other.w):
                c = other.at(x, y)
                if c[3]:
                    f(dx + x, dy + y, c)

    def region(self, x0, y0, w, h):
        out = Canvas(w, h)
        for y in range(h):
            for x in range(w):
                out.paint(x, y, self.at(x0 + x, y0 + y))
        return out

    def scaled(self, n):
        out = Canvas(self.w * n, self.h * n)
        for y in range(self.h):
            for x in range(self.w):
                c = self.at(x, y)
                if c[3]:
                    out.rect(x * n, y * n, x * n + n - 1, y * n + n - 1, c)
        return out

    def save(self, path):
        raw = bytearray()
        stride = self.w * 4
        for y in range(self.h):
            raw.append(0)
            raw += self.buf[y * stride:(y + 1) * stride]
        comp = zlib.compress(bytes(raw), 9)

        def chunk(tag, data):
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))
        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", comp)
        png += chunk(b"IEND", b"")
        d = os.path.dirname(path)
        if d:
            os.makedirs(d, exist_ok=True)
        with open(path, "wb") as f:
            f.write(png)


def _paeth(a, b, c):
    p = a + b - c
    pa = abs(p - a); pb = abs(p - b); pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def load_png(path):
    """Decode an 8-bit PNG (grayscale/RGB/RGBA/palette, no interlace) -> Canvas.

    Enough of the spec to read our own output and most CC0 packs, so generators
    can composite from existing PNGs (montages, retints, atlases)."""
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG: " + path
    pos = 8
    w = h = bitd = ctype = 0
    idat = bytearray()
    plte = None
    trns = None
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if tag == b"IHDR":
            w, h, bitd, ctype = struct.unpack(">IIBB", body[:10])
        elif tag == b"PLTE":
            plte = body
        elif tag == b"tRNS":
            trns = body
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break
    assert bitd == 8, "only 8-bit PNGs supported (%s)" % path
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(bytes(idat))
    stride = w * channels
    out = Canvas(w, h)
    prev = bytearray(stride)
    rp = 0
    for y in range(h):
        ft = raw[rp]; rp += 1
        line = bytearray(raw[rp:rp + stride]); rp += stride
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if ft == 1:
                line[i] = (line[i] + a) & 255
            elif ft == 2:
                line[i] = (line[i] + b) & 255
            elif ft == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif ft == 4:
                line[i] = (line[i] + _paeth(a, b, c)) & 255
        prev = line
        for x in range(w):
            px = line[x * channels:x * channels + channels]
            if ctype == 6:
                col = (px[0], px[1], px[2], px[3])
            elif ctype == 2:
                col = (px[0], px[1], px[2], 255)
            elif ctype == 0:
                col = (px[0], px[0], px[0], 255)
            elif ctype == 4:
                col = (px[0], px[0], px[0], px[1])
            else:  # palette
                idx = px[0]
                col = (plte[idx * 3], plte[idx * 3 + 1], plte[idx * 3 + 2],
                       trns[idx] if trns and idx < len(trns) else 255)
            out.paint(x, y, col)
    return out


ASSETS = os.path.normpath(os.path.join(os.path.dirname(__file__), "..",
                                       "assets", "placeholder"))


def asset(*parts):
    return os.path.join(ASSETS, *parts)


if __name__ == "__main__":
    # Smoke test: a shaded tile + an outlined disc.
    c = Canvas(16, 16)
    rnd = random.Random(7)
    c.mottle(0, 0, 15, 15, P.GRASS, rnd, scale=4)
    c.disc(8, 9, 5, P.FOLIAGE[1])
    c.outline()
    c.drop_shadow()
    c.save(asset("_pixelforge_smoke.png"))
    print("pixelforge OK ->", asset("_pixelforge_smoke.png"))
