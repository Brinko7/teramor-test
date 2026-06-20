#!/usr/bin/env python3
"""Procedural pixel-art generator for the wildlife drop items.

  items/raw_meat.png   16x16  a raw drumstick/cut (a small cooked-down heal)
  items/hide.png       16x16  a stretched animal pelt (craft material)

Self-contained stdlib PNG path (zlib + struct), the same style as gen_farm.py —
each gen_*.py carries its own little Canvas so it runs anywhere with python3.
"""

import os
import struct
import zlib

OUTLINE = (40, 26, 22, 255)


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


# --- palettes ---------------------------------------------------------------
MEAT_L = (196, 92, 88)
MEAT_M = (164, 64, 64)
MEAT_D = (120, 42, 48)
FAT = (228, 206, 188)
BONE = (236, 228, 210)
BONE_D = (196, 184, 160)

HIDE_L = (190, 156, 116)
HIDE_M = (158, 124, 88)
HIDE_D = (118, 90, 62)
HIDE_SPOT = (96, 70, 48)
HIDE_FUR = (208, 182, 150)


def gen_meat():
    c = Canvas(16, 16)
    # Drumstick bone poking out the upper-left: a knob + a short shaft.
    c.rect(3, 3, 4, 4, BONE)
    c.put(2, 3, BONE_D)
    c.put(4, 5, BONE_D)
    c.rect(4, 5, 6, 7, BONE)
    c.rect(5, 7, 7, 8, BONE_D)
    # The meat: a rounded red blob anchored lower-right.
    blob = {
        5: (8, 11), 6: (7, 12), 7: (6, 13), 8: (6, 13),
        9: (6, 13), 10: (6, 13), 11: (7, 12), 12: (8, 11),
    }
    for y, (x0, x1) in blob.items():
        c.row(y, x0, x1, MEAT_M)
    # Highlight along the top-left, shadow along the bottom-right.
    c.row(5, 8, 11, MEAT_L)
    c.row(6, 7, 9, MEAT_L)
    c.put(6, 7, MEAT_L)
    c.row(11, 8, 12, MEAT_D)
    c.row(12, 9, 11, MEAT_D)
    c.put(13, 9, MEAT_D)
    c.put(13, 10, MEAT_D)
    # A line of fat/marbling hugging the cut.
    c.put(7, 6, FAT)
    c.put(8, 7, FAT)
    c.row(10, 7, 8, FAT)
    c.outline()
    c.save("items/raw_meat.png")


def gen_hide():
    c = Canvas(16, 16)
    # A stretched pelt: narrow neck/tail, splayed legs mid-body.
    shape = {
        2: (7, 8), 3: (6, 9), 4: (3, 12), 5: (3, 13), 6: (4, 11),
        7: (5, 10), 8: (5, 10), 9: (4, 11), 10: (3, 13), 11: (4, 12),
        12: (6, 9), 13: (7, 8),
    }
    for y, (x0, x1) in shape.items():
        c.row(y, x0, x1, HIDE_M)
    # Highlight up top, shadow along the bottom — a draped look.
    c.row(4, 3, 12, HIDE_L)
    c.row(3, 6, 9, HIDE_L)
    c.row(11, 4, 12, HIDE_D)
    c.row(10, 3, 13, HIDE_D)
    c.row(13, 7, 8, HIDE_D)
    # Soft fur patch through the middle.
    c.rect(6, 6, 9, 9, HIDE_FUR)
    # A couple of darker markings.
    c.put(7, 5, HIDE_SPOT)
    c.put(10, 6, HIDE_SPOT)
    c.put(6, 10, HIDE_SPOT)
    c.put(9, 11, HIDE_SPOT)
    c.outline()
    c.save("items/hide.png")


def main():
    gen_meat()
    gen_hide()


if __name__ == "__main__":
    main()
