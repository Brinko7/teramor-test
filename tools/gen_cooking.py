#!/usr/bin/env python3
"""Procedural pixel-art generator for cooked dishes (the cooking system).

  items/hearty_stew.png      16x16  a bowl of brothy stew (regen)
  items/grilled_skewer.png   16x16  meat chunks on a skewer (melee)
  items/wheat_bread.png      16x16  a golden loaf (defense)
  items/forager_salad.png    16x16  a bowl of leafy greens (speed)

Self-contained stdlib PNG path (zlib + struct), the same style as gen_forage.py
so the kitchen art sits on the grounded palette with the rest of the items.
"""

import os
import struct
import zlib

OUTLINE = (40, 28, 24, 255)


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

    def row(self, y, x0, x1, c):
        self.rect(x0, y, x1, y, c)

    def disc(self, cx, cy, r, c):
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.put(x, y, c)

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


# --- Shared materials (grounded palette) ------------------------------------
BOWL_L = (150, 116, 86)
BOWL_M = (118, 88, 64)
BOWL_D = (88, 64, 46)
BROTH_L = (180, 120, 70)
BROTH_M = (150, 94, 52)
MEAT_L = (170, 86, 70)
MEAT_M = (138, 60, 52)
MEAT_D = (104, 42, 42)
STICK_L = (176, 146, 100)
STICK_D = (132, 104, 70)
BREAD_L = (214, 168, 96)
BREAD_M = (182, 132, 70)
BREAD_D = (140, 96, 52)
CRUMB = (120, 80, 44)
LEAF_L = (122, 168, 86)
LEAF_M = (84, 134, 62)
LEAF_D = (58, 100, 48)
TOMATO = (186, 70, 58)


def _bowl(c, y_top=9):
    """A shallow wooden bowl filling the bottom of the tile."""
    # Rim ellipse.
    c.row(y_top, 4, 11, BOWL_L)
    # Body tapering in.
    body = {y_top + 1: (3, 12), y_top + 2: (3, 12), y_top + 3: (4, 11),
            y_top + 4: (5, 10), y_top + 5: (6, 9)}
    for y, (x0, x1) in body.items():
        c.row(y, x0, x1, BOWL_M)
    c.row(y_top + 5, 6, 9, BOWL_D)
    c.row(y_top + 4, 5, 10, BOWL_D)


def gen_stew():
    c = Canvas(16, 16)
    _bowl(c, 9)
    # Brothy fill with chunks.
    c.row(10, 4, 11, BROTH_M)
    c.row(9, 5, 10, BROTH_L)
    c.put(6, 9, MEAT_M)
    c.put(9, 9, MEAT_L)
    c.put(7, 10, LEAF_M)
    c.put(10, 10, BROTH_L)
    # A wisp of steam.
    c.put(6, 6, (224, 216, 200))
    c.put(9, 5, (224, 216, 200))
    c.put(7, 7, (200, 192, 178))
    c.outline()
    c.save("items/hearty_stew.png")


def gen_skewer():
    c = Canvas(16, 16)
    # Diagonal stick.
    for i in range(13):
        c.put(2 + i, 13 - i, STICK_D)
        c.put(2 + i, 12 - i, STICK_L)
    # Three meat chunks threaded on.
    for cx, cy in [(5, 9), (8, 6), (11, 3)]:
        c.disc(cx, cy, 2, MEAT_M)
        c.put(cx - 1, cy - 1, MEAT_L)
        c.put(cx + 1, cy + 1, MEAT_D)
    c.outline()
    c.save("items/grilled_skewer.png")


def gen_bread():
    c = Canvas(16, 16)
    # Rounded loaf.
    loaf = {6: (5, 10), 7: (4, 11), 8: (3, 12), 9: (3, 12), 10: (4, 11), 11: (5, 10)}
    for y, (x0, x1) in loaf.items():
        c.row(y, x0, x1, BREAD_M)
    c.row(6, 5, 10, BREAD_L)
    c.row(7, 4, 9, BREAD_L)
    c.row(11, 5, 10, BREAD_D)
    c.row(10, 4, 11, BREAD_D)
    # Slashed crust marks.
    c.put(6, 8, CRUMB)
    c.put(8, 7, CRUMB)
    c.put(10, 8, CRUMB)
    c.outline()
    c.save("items/wheat_bread.png")


def gen_salad():
    c = Canvas(16, 16)
    _bowl(c, 9)
    # Mound of greens.
    c.row(9, 4, 11, LEAF_M)
    c.row(8, 5, 10, LEAF_M)
    c.put(5, 8, LEAF_L)
    c.put(7, 7, LEAF_L)
    c.put(9, 8, LEAF_L)
    c.put(6, 9, LEAF_D)
    c.put(10, 9, LEAF_D)
    # A couple of tomato bits.
    c.put(8, 9, TOMATO)
    c.put(5, 10, TOMATO)
    c.outline()
    c.save("items/forager_salad.png")


def main():
    gen_stew()
    gen_skewer()
    gen_bread()
    gen_salad()


if __name__ == "__main__":
    main()
