#!/usr/bin/env python3
"""Procedural pixel-art generator for foraged forage items.

  items/wild_mushroom.png   16x16  a red-capped woodland mushroom (small heal)

Self-contained stdlib PNG path (zlib + struct), the same style as gen_farm.py.
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


CAP_L = (208, 92, 82)
CAP_M = (174, 60, 56)
CAP_D = (128, 40, 46)
SPOT = (238, 230, 214)
STEM_L = (226, 212, 186)
STEM_M = (198, 182, 152)
STEM_D = (152, 136, 110)


def gen_mushroom():
    c = Canvas(16, 16)
    # Domed red cap.
    cap = {3: (6, 9), 4: (4, 11), 5: (3, 12), 6: (3, 12), 7: (4, 11)}
    for y, (x0, x1) in cap.items():
        c.row(y, x0, x1, CAP_M)
    c.row(3, 6, 9, CAP_L)
    c.row(4, 4, 7, CAP_L)
    c.row(7, 4, 11, CAP_D)
    # Pale underside / gills.
    c.row(8, 5, 10, STEM_M)
    # White cap spots.
    c.put(5, 5, SPOT)
    c.put(9, 4, SPOT)
    c.put(10, 6, SPOT)
    c.put(7, 6, SPOT)
    # Stem with a slightly bulbous base.
    stem = {9: (6, 9), 10: (6, 9), 11: (5, 10), 12: (5, 10)}
    for y, (x0, x1) in stem.items():
        c.row(y, x0, x1, STEM_M)
    c.rect(6, 9, 6, 12, STEM_L)   # left highlight
    c.rect(9, 9, 9, 12, STEM_D)   # right shadow
    c.row(12, 5, 10, STEM_D)
    c.outline()
    c.save("items/wild_mushroom.png")


def main():
    gen_mushroom()


if __name__ == "__main__":
    main()
