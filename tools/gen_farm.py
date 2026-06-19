#!/usr/bin/env python3
"""Procedural pixel-art generator for Teramor's farming pillar.

Soil tiles + crop growth stages (drop onto a FarmPlot), and bag icons for the
tools, seeds and produce. Stdlib PNG path (zlib + struct), same style as
gen_town.py / gen_char.py.

  soil_untilled.png / soil_tilled.png / soil_watered.png   16x16 ground states
  crop_turnip_0..3.png   16x16  turnip growth stages (sprout -> bulb)
  crop_wheat_0..3.png    16x16  wheat growth stages  (sprout -> golden heads)
  items/hoe.png, items/watering_can.png                    16x16 tool icons
  items/turnip_seeds.png, items/wheat_seeds.png            16x16 seed icons
  items/turnip.png, items/wheat.png                        16x16 produce icons
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
DIRT = ((150, 110, 72), (120, 86, 54), (92, 64, 40))
TILLED = ((132, 92, 58), (104, 70, 42), (78, 50, 30))
WET = ((96, 70, 50), (72, 50, 36), (50, 34, 24))
LEAF = ((128, 188, 84), (88, 152, 58), (56, 110, 40))
BULB = ((238, 234, 240), (212, 202, 222), (158, 126, 178))
BULBTOP = (158, 96, 178)
WGREEN = ((158, 196, 96), (116, 164, 68), (80, 122, 48))
WGOLD = ((244, 216, 122), (216, 178, 74), (172, 132, 50))
METAL = ((188, 194, 204), (146, 152, 164), (104, 110, 122))
HANDLE = ((158, 112, 66), (122, 82, 46), (84, 52, 28))
WATER = ((120, 176, 214), (78, 138, 190), (50, 102, 154))
DROP = (120, 188, 224)
BAG = ((214, 198, 160), (182, 166, 128), (140, 124, 92))
TWINE = (120, 92, 56)
WOOD = ((150, 104, 60), (118, 80, 44), (88, 58, 32))
IRON = ((132, 136, 146), (88, 92, 102), (54, 58, 66))
LOCK = (216, 178, 74)


# --- soil --------------------------------------------------------------------
def gen_soil_untilled():
    c = Canvas(16, 16)
    c.rect(0, 0, 15, 15, DIRT[1])
    for (x, y) in [(2, 3), (5, 8), (9, 2), (12, 6), (4, 12), (10, 11), (13, 13), (7, 5)]:
        c.put(x, y, DIRT[2])
    for (x, y) in [(3, 6), (8, 9), (11, 4), (6, 13), (1, 10)]:
        c.put(x, y, DIRT[0])
    # a few stray grass blades so it reads as plantable ground
    c.rect(2, 1, 2, 2, LEAF[1])
    c.put(13, 1, LEAF[1])
    c.put(8, 14, LEAF[2])
    c.save("soil_untilled.png")


def _furrows(c, pal):
    c.rect(0, 0, 15, 15, pal[1])
    for ry in (2, 6, 10, 14):
        c.rect(0, ry, 15, ry, pal[2])
    for ry in (1, 5, 9, 13):
        c.rect(0, ry, 15, ry, pal[0])


def gen_soil_tilled():
    c = Canvas(16, 16)
    _furrows(c, TILLED)
    c.save("soil_tilled.png")


def gen_soil_watered():
    c = Canvas(16, 16)
    _furrows(c, WET)
    for (x, y) in [(3, 1), (9, 5), (12, 9), (5, 13), (14, 1)]:
        c.put(x, y, (118, 150, 172))
    c.save("soil_watered.png")


# --- crops -------------------------------------------------------------------
def gen_turnip_stages():
    # stage 0 - sprout
    c = Canvas(16, 16)
    c.rect(7, 12, 8, 14, LEAF[2])
    c.put(6, 12, LEAF[1]); c.put(9, 12, LEAF[1])
    c.put(5, 11, LEAF[0]); c.put(10, 11, LEAF[0])
    c.outline(); c.save("crop_turnip_0.png")

    # stage 1 - small leafy
    c = Canvas(16, 16)
    c.rect(7, 9, 8, 15, LEAF[2])
    c.shade(4, 9, 11, 13, *LEAF)
    c.outline(); c.save("crop_turnip_1.png")

    # stage 2 - bigger leafy
    c = Canvas(16, 16)
    c.rect(7, 8, 8, 15, LEAF[2])
    c.shade(3, 7, 12, 12, *LEAF)
    c.rect(5, 5, 10, 7, LEAF[0])
    c.outline(); c.save("crop_turnip_2.png")

    # stage 3 - mature bulb + greens
    c = Canvas(16, 16)
    c.shade(5, 10, 10, 15, *BULB)
    c.rect(6, 9, 9, 10, BULBTOP)
    c.rect(6, 4, 9, 8, LEAF[1])
    c.put(5, 5, LEAF[0]); c.put(10, 5, LEAF[0])
    c.put(7, 3, LEAF[0]); c.put(8, 3, LEAF[0])
    c.outline(); c.save("crop_turnip_3.png")


def gen_wheat_stages():
    # stage 0 - sprout
    c = Canvas(16, 16)
    c.rect(7, 12, 7, 15, WGREEN[1])
    c.rect(9, 13, 9, 15, WGREEN[1])
    c.put(6, 12, WGREEN[0]); c.put(10, 13, WGREEN[0])
    c.outline(); c.save("crop_wheat_0.png")

    # stage 1 - thin green stalks
    c = Canvas(16, 16)
    for sx in (5, 8, 11):
        c.rect(sx, 8, sx, 15, WGREEN[1])
        c.put(sx, 8, WGREEN[0])
    c.outline(); c.save("crop_wheat_1.png")

    # stage 2 - taller leafy stalks
    c = Canvas(16, 16)
    for sx in (5, 8, 11):
        c.rect(sx, 5, sx, 15, WGREEN[1])
        c.put(sx - 1, 9, WGREEN[2]); c.put(sx + 1, 11, WGREEN[2])
    c.outline(); c.save("crop_wheat_2.png")

    # stage 3 - golden heads
    c = Canvas(16, 16)
    for sx in (5, 8, 11):
        c.rect(sx, 6, sx, 15, WGOLD[2])
        c.shade(sx - 1, 1, sx + 1, 6, *WGOLD)
        c.put(sx, 0, WGOLD[0])
    c.outline(); c.save("crop_wheat_3.png")


# --- icons -------------------------------------------------------------------
def gen_hoe():
    c = Canvas(16, 16)
    for i in range(9):                       # diagonal handle
        c.put(3 + i, 13 - i, HANDLE[1])
        c.put(3 + i, 12 - i, HANDLE[0])
        c.put(4 + i, 13 - i, HANDLE[2])
    c.rect(11, 2, 14, 3, METAL[1])           # blade head
    c.rect(11, 2, 11, 5, METAL[0])
    c.rect(14, 2, 14, 4, METAL[2])
    c.outline(); c.save("items/hoe.png")


def gen_watering_can():
    c = Canvas(16, 16)
    c.shade(5, 6, 12, 13, *METAL)            # body
    c.rect(2, 7, 5, 8, METAL[1])             # spout
    c.put(1, 6, METAL[0]); c.put(1, 7, METAL[2])
    c.rect(8, 3, 11, 4, METAL[2])            # top handle
    c.put(8, 5, METAL[1]); c.put(11, 5, METAL[1])
    c.put(1, 9, DROP); c.put(0, 11, DROP); c.put(2, 12, DROP)  # drips
    c.outline(); c.save("items/watering_can.png")


def _seed_bag(motif, name):
    c = Canvas(16, 16)
    c.shade(4, 4, 11, 14, *BAG)              # cloth sack
    c.rect(4, 4, 11, 4, BAG[2])             # cinched top shadow
    c.rect(5, 3, 10, 3, BAG[0])
    c.rect(7, 2, 8, 3, BAG[1])
    c.rect(4, 7, 11, 7, TWINE)              # twine tie
    for (x, y, col) in motif:               # little produce picture
        c.put(x, y, col)
    c.outline(); c.save(name)


def gen_turnip_seeds():
    motif = [(7, 10, BULB[2]), (8, 10, BULB[1]), (7, 11, BULBTOP), (8, 11, BULBTOP),
             (7, 9, LEAF[1]), (8, 9, LEAF[1])]
    _seed_bag(motif, "items/turnip_seeds.png")


def gen_wheat_seeds():
    motif = [(6, 11, WGOLD[1]), (8, 10, WGOLD[0]), (10, 11, WGOLD[1]),
             (6, 12, WGOLD[2]), (8, 11, WGOLD[1]), (10, 12, WGOLD[2])]
    _seed_bag(motif, "items/wheat_seeds.png")


def gen_turnip():
    c = Canvas(16, 16)
    c.shade(4, 7, 11, 14, *BULB)            # round bulb
    c.put(4, 7, (0, 0, 0, 0)); c.put(11, 7, (0, 0, 0, 0))   # round corners
    c.put(4, 14, (0, 0, 0, 0)); c.put(11, 14, (0, 0, 0, 0))
    c.rect(5, 6, 10, 7, BULBTOP)            # purple shoulders
    c.rect(6, 2, 9, 5, LEAF[1])            # greens
    c.put(5, 3, LEAF[0]); c.put(10, 3, LEAF[0])
    c.put(7, 1, LEAF[0]); c.put(8, 1, LEAF[0])
    c.outline(); c.save("items/turnip.png")


def gen_wheat():
    c = Canvas(16, 16)
    for sx in (5, 8, 11):                    # bundled sheaf
        c.rect(sx, 6, sx, 14, WGOLD[2])
        c.shade(sx - 1, 2, sx + 1, 7, *WGOLD)
        c.put(sx, 1, WGOLD[0])
    c.rect(4, 11, 12, 12, TWINE)            # twine band
    c.outline(); c.save("items/wheat.png")


# --- storage -----------------------------------------------------------------
def gen_chest():
    c = Canvas(16, 16)
    # arched wooden lid (rows 3..7)
    c.shade(2, 4, 13, 7, *WOOD)
    c.rect(4, 3, 11, 3, WOOD[0])
    c.put(3, 4, WOOD[0]); c.put(12, 4, WOOD[0])
    # wooden body (rows 8..14)
    c.shade(2, 8, 13, 14, *WOOD)
    for sx in (6, 9):                       # plank seams
        c.rect(sx, 9, sx, 13, WOOD[2])
    # iron bands down each side
    for bx in (3, 12):
        c.rect(bx, 4, bx, 14, IRON[1])
        c.put(bx, 4, IRON[0]); c.put(bx, 14, IRON[2])
    # iron seam where lid meets body
    c.rect(2, 7, 13, 7, IRON[2])
    c.rect(2, 8, 13, 8, IRON[1])
    # central lock plate with gold keyhole
    c.rect(7, 6, 8, 10, IRON[1])
    c.put(7, 6, IRON[0]); c.put(8, 6, IRON[0])
    c.rect(7, 8, 8, 9, LOCK)
    c.put(7, 9, (60, 46, 20))
    c.outline(); c.save("chest.png")


def main():
    gen_chest()
    gen_soil_untilled()
    gen_soil_tilled()
    gen_soil_watered()
    gen_turnip_stages()
    gen_wheat_stages()
    gen_hoe()
    gen_watering_can()
    gen_turnip_seeds()
    gen_wheat_seeds()
    gen_turnip()
    gen_wheat()


if __name__ == "__main__":
    main()
