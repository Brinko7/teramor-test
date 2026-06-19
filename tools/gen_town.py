#!/usr/bin/env python3
"""Procedural pixel-art generator for Cleeve's Landing's urban props.

Renders facade-style placeholder sprites (drawn front-on, base at the bottom):
  townhouse.png    48x48  two-story timber-framed townhouse
  blacksmith.png   48x48  stone smithy with a glowing forge + chimney
  chapel.png       48x64  temple of Tera with a steeple and stained glass
  market_stall.png 40x36  awning market stall with a goods counter
  lamp_post.png    16x40  iron street lamp with a warm lantern

Uses the stdlib PNG path (zlib + struct), same style as gen_bed.py / gen_char.py.
"""

import os
import struct
import zlib

OUTLINE = (26, 20, 16, 255)


class Canvas:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.buf = bytearray(w * h * 4)

    def put(self, x, y, c):
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        if len(c) == 3:
            c = (c[0], c[1], c[2], 255)
        if c[3] == 0:
            return
        i = (y * self.w + x) * 4
        self.buf[i], self.buf[i + 1], self.buf[i + 2], self.buf[i + 3] = c
    def rect(self, x0, y0, x1, y1, c):
        if x1 < x0:
            x0, x1 = x1, x0
        if y1 < y0:
            y0, y1 = y1, y0
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def shade(self, x0, y0, x1, y1, light, mid, dark):
        """Filled box with a top/left highlight and bottom/right shadow."""
        self.rect(x0, y0, x1, y1, mid)
        self.rect(x0, y0, x1, y0, light)
        self.rect(x0, y0, x0, y1, light)
        self.rect(x0, y1, x1, y1, dark)
        self.rect(x1, y0, x1, y1, dark)

    def tri_roof(self, cx, y_top, half_top, y_bot, half_bot, light, mid, dark):
        """Trapezoidal roof widening from (y_top, half_top) to (y_bot, half_bot)."""
        span = max(1, y_bot - y_top)
        for y in range(y_top, y_bot + 1):
            t = (y - y_top) / span
            half = int(round(half_top + (half_bot - half_top) * t))
            self.rect(cx - half, y, cx + half, y, mid)
            self.put(cx - half, y, dark)
            self.put(cx + half, y, dark)
        self.rect(cx - half_top, y_top, cx + half_top, y_top, light)

    def outline(self, color=OUTLINE):
        src = bytes(self.buf)

        def op(x, y):
            if x < 0 or y < 0 or x >= self.w or y >= self.h:
                return False
            return src[(y * self.w + x) * 4 + 3] != 0

        for y in range(self.h):
            for x in range(self.w):
                if op(x, y):
                    continue
                if op(x - 1, y) or op(x + 1, y) or op(x, y - 1) or op(x, y + 1):
                    self.put(x, y, color)

    def save(self, name):
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            raw += self.buf[y * self.w * 4:(y + 1) * self.w * 4]
        comp = zlib.compress(bytes(raw), 9)

        def chunk(tag, data):
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", comp)
        png += chunk(b"IEND", b"")
        path = os.path.join(os.path.dirname(__file__), "..", "assets",
                            "placeholder", name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(png)
        print("generated", name, "(%dx%d)" % (self.w, self.h))


# --- palettes ----------------------------------------------------------------
SLATE = ((150, 162, 184), (112, 124, 148), (78, 88, 110))
PLASTER = ((216, 200, 164), (190, 172, 134), (158, 142, 108))
BEAM = (78, 54, 34)
WOOD = ((158, 112, 66), (122, 82, 46), (84, 52, 28))
GLASS = ((150, 184, 200), (108, 146, 168), (78, 110, 132))
STONE = ((158, 158, 166), (124, 124, 134), (92, 92, 102))
DARKWOOD = ((110, 78, 50), (84, 56, 34), (58, 38, 22))
EMBER = ((255, 214, 120), (252, 160, 40), (210, 86, 20))
PALE = ((222, 218, 208), (194, 188, 174), (160, 154, 138))
TEAL = ((96, 132, 176), (66, 98, 144), (44, 70, 110))
GOLD = (244, 206, 96)


def gen_townhouse():
    c = Canvas(48, 48)
    # Gable roof.
    c.tri_roof(24, 2, 4, 16, 22, *SLATE)
    c.rect(3, 15, 44, 16, SLATE[2])
    # Plaster upper + lower wall.
    c.shade(5, 16, 42, 46, *PLASTER)
    # Timber framing.
    c.rect(5, 16, 5, 46, BEAM)
    c.rect(42, 16, 42, 46, BEAM)
    c.rect(5, 16, 42, 16, BEAM)
    c.rect(5, 30, 42, 31, BEAM)     # mid floor band
    c.rect(5, 45, 42, 46, BEAM)
    c.rect(23, 16, 24, 30, BEAM)    # central post upper
    # Upper-story windows.
    for wx in (11, 28):
        c.shade(wx, 20, wx + 7, 27, *GLASS)
        c.rect(wx + 3, 20, wx + 4, 27, BEAM)
        c.rect(wx, 23, wx + 7, 24, BEAM)
    # Door.
    c.shade(20, 35, 27, 46, *WOOD)
    c.put(26, 41, GOLD)
    # Lower windows.
    for wx in (9, 31):
        c.shade(wx, 35, wx + 6, 42, *GLASS)
        c.rect(wx + 3, 35, wx + 3, 42, BEAM)
    c.outline()
    c.save("townhouse.png")


def gen_blacksmith():
    c = Canvas(48, 48)
    # Chimney (right) with ember glow + smoke wisp.
    c.shade(33, 2, 44, 22, *STONE)
    c.rect(34, 3, 43, 5, EMBER[2])
    c.rect(36, 2, 41, 3, EMBER[1])
    c.put(38, 0, (180, 180, 188, 180))
    c.put(40, 1, (160, 160, 168, 160))
    # Roof.
    c.tri_roof(20, 4, 4, 15, 20, *DARKWOOD)
    c.rect(1, 14, 39, 15, DARKWOOD[2])
    # Stone walls.
    c.shade(4, 15, 40, 46, *STONE)
    for sy in range(20, 46, 6):       # block seams
        c.rect(5, sy, 39, sy, STONE[2])
    for sx in range(12, 40, 9):
        c.rect(sx, 15, sx, 46, STONE[2])
    # Glowing forge opening.
    c.rect(9, 28, 22, 41, (40, 24, 18))
    c.shade(10, 30, 21, 40, EMBER[0], EMBER[1], EMBER[2])
    c.rect(11, 38, 20, 40, (60, 36, 24))
    # Anvil silhouette in the doorway light.
    c.rect(13, 36, 18, 38, (40, 40, 46))
    c.rect(15, 34, 16, 36, (40, 40, 46))
    # Door.
    c.shade(28, 32, 38, 46, *DARKWOOD)
    c.put(30, 39, GOLD)
    c.outline()
    c.save("blacksmith.png")


def gen_chapel():
    c = Canvas(48, 64)
    # Steeple tower.
    c.shade(18, 6, 29, 26, *PALE)
    # Spire roof on the tower.
    c.tri_roof(23, 0, 1, 6, 7, *TEAL)
    # Sun-of-Tera emblem on the tower.
    for (ex, ey) in [(23, 12), (24, 12), (23, 13), (24, 13)]:
        c.put(ex, ey, GOLD)
    for ang in [(-2, 0), (2, 0), (0, -2), (0, 2), (2, 2), (-2, -2), (2, -2), (-2, 2)]:
        c.put(23 + ang[0], 12 + ang[1], GOLD)
    # Main roof.
    c.tri_roof(24, 24, 8, 34, 23, *TEAL)
    c.rect(2, 33, 45, 34, TEAL[2])
    # Nave walls.
    c.shade(4, 34, 43, 62, *PALE)
    # Big arched stained-glass window.
    c.rect(18, 42, 29, 54, GLASS[2])
    c.rect(19, 40, 28, 42, GLASS[2])     # arched top
    c.rect(20, 43, 23, 53, (170, 70, 70))
    c.rect(24, 43, 27, 53, (70, 90, 170))
    c.rect(20, 47, 27, 48, GOLD)
    c.rect(23, 40, 24, 54, PALE[2])      # mullion
    # Flanking arched windows.
    for wx in (8, 33):
        c.shade(wx, 44, wx + 6, 53, *GLASS)
        c.rect(wx, 43, wx + 6, 44, GLASS[2])
        c.rect(wx + 3, 44, wx + 3, 53, PALE[2])
    # Arched double door.
    c.shade(19, 53, 28, 62, *DARKWOOD)
    c.rect(20, 52, 27, 53, DARKWOOD[2])
    c.rect(23, 54, 24, 62, BEAM)
    c.outline()
    c.save("chapel.png")


def gen_market_stall():
    c = Canvas(40, 36)
    # Posts.
    c.rect(4, 10, 6, 33, WOOD[2])
    c.rect(33, 10, 35, 33, WOOD[2])
    # Shadowed interior backboard.
    c.rect(6, 12, 33, 26, (54, 44, 36))
    # Counter.
    c.shade(4, 26, 35, 32, *WOOD)
    c.rect(4, 26, 35, 26, WOOD[0])
    # Goods on the counter (fruit/veg).
    produce = [(9, (196, 64, 56)), (13, (232, 150, 48)),
               (17, (96, 168, 72)), (21, (196, 64, 56)),
               (25, (220, 196, 90)), (29, (140, 96, 180))]
    for gx, col in produce:
        c.rect(gx, 22, gx + 2, 25, col)
        c.put(gx, 22, tuple(min(255, v + 40) for v in col))
    # Striped awning (red / cream), front edge scalloped.
    for x in range(2, 38):
        col = (196, 72, 64) if ((x // 4) % 2 == 0) else (236, 224, 196)
        c.rect(x, 2, x, 10, col)
    for x in range(2, 38, 4):           # scalloped lower lip
        c.rect(x, 11, x + 1, 12, (196, 72, 64))
    c.outline()
    c.save("market_stall.png")


def gen_lamp_post():
    c = Canvas(16, 40)
    # Base + post.
    c.rect(5, 36, 10, 38, (70, 70, 78))
    c.rect(7, 12, 8, 37, (58, 58, 66))
    c.put(7, 12, (90, 90, 98))
    # Lantern head frame.
    c.rect(4, 3, 11, 13, (44, 44, 50))
    # Warm glowing glass.
    c.shade(5, 5, 10, 12, (255, 236, 176), (252, 208, 110), (228, 168, 70))
    # Cap + finial.
    c.rect(5, 1, 10, 2, (58, 58, 66))
    c.put(7, 0, (70, 70, 78))
    c.put(8, 0, (70, 70, 78))
    c.outline()
    c.save("lamp_post.png")


def main():
    gen_townhouse()
    gen_blacksmith()
    gen_chapel()
    gen_market_stall()
    gen_lamp_post()


if __name__ == "__main__":
    main()
