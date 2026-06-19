#!/usr/bin/env python3
"""Procedural pixel-art generator for the Teramor bed prop.

Renders a single 32x44 top-down bed: a wooden frame with a slatted headboard,
a cream pillow and a turned-down red blanket. Single frame (not a walk sheet) —
it is a static interactable prop. Uses the stdlib PNG path (zlib + struct), same
as gen_char.py / gen_wolf.py.
"""

import os
import struct
import zlib

W, H = 32, 44

OUTLINE = (28, 22, 18, 255)

WOOD_L = (158, 112, 66)
WOOD_M = (122, 82, 46)
WOOD_D = (84, 52, 28)

PIL_L = (246, 240, 222)
PIL_M = (214, 206, 184)
PIL_D = (188, 178, 154)

BLK_L = (182, 72, 74)
BLK_M = (150, 46, 50)
BLK_D = (108, 30, 36)


def new_buf():
    return bytearray(W * H * 4)


def put(buf, x, y, c):
    if x < 0 or y < 0 or x >= W or y >= H:
        return
    if len(c) == 3:
        c = (c[0], c[1], c[2], 255)
    if c[3] == 0:
        return
    i = (y * W + x) * 4
    buf[i], buf[i + 1], buf[i + 2], buf[i + 3] = c[0], c[1], c[2], c[3]


def rect(buf, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(buf, x, y, c)


def shade_rect(buf, x0, y0, x1, y1, light, mid, dark):
    rect(buf, x0, y0, x1, y1, mid)
    rect(buf, x0, y0, x1, y0, light)   # top
    rect(buf, x0, y0, x0, y1, light)   # left
    rect(buf, x0, y1, x1, y1, dark)    # bottom
    rect(buf, x1, y0, x1, y1, dark)    # right


def outline(buf, color=OUTLINE):
    src = bytes(buf)

    def op(x, y):
        if x < 0 or y < 0 or x >= W or y >= H:
            return False
        return src[(y * W + x) * 4 + 3] != 0

    for y in range(H):
        for x in range(W):
            if op(x, y):
                continue
            if op(x - 1, y) or op(x + 1, y) or op(x, y - 1) or op(x, y + 1):
                put(buf, x, y, color)


def write_png(path, buf):
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        raw += buf[y * W * 4:(y + 1) * W * 4]
    comp = zlib.compress(bytes(raw), 9)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", comp)
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def main():
    buf = new_buf()

    # Wooden frame (whole footprint).
    shade_rect(buf, 2, 2, 29, 41, WOOD_L, WOOD_M, WOOD_D)

    # Slatted headboard band at the top.
    rect(buf, 2, 2, 29, 6, WOOD_D)
    for x in range(5, 28, 4):
        rect(buf, x, 3, x, 5, WOOD_M)

    # Footboard band at the bottom.
    rect(buf, 2, 39, 29, 41, WOOD_D)

    # Corner posts.
    for px, py in [(2, 2), (28, 2), (2, 40), (28, 40)]:
        rect(buf, px, py, px + 1, py + 1, WOOD_D)

    # Mattress sheet inset.
    shade_rect(buf, 5, 7, 26, 38, PIL_L, PIL_M, PIL_D)

    # Pillow near the headboard.
    shade_rect(buf, 7, 8, 24, 15, PIL_L, PIL_M, PIL_D)
    rect(buf, 15, 9, 15, 14, PIL_D)   # centre crease between two pillows

    # Blanket / duvet covering the lower body.
    shade_rect(buf, 5, 18, 26, 37, BLK_L, BLK_M, BLK_D)
    # Folded-down sheet lip over the blanket top.
    rect(buf, 5, 16, 26, 18, PIL_L)
    rect(buf, 5, 18, 26, 18, PIL_D)
    # Seam / quilt lines.
    rect(buf, 5, 27, 26, 27, BLK_D)
    rect(buf, 15, 19, 15, 37, BLK_D)

    outline(buf)
    base = os.path.join(os.path.dirname(__file__), "..", "assets",
                        "placeholder", "bed.png")
    write_png(base, buf)
    print("generated bed prop (32x44)")


if __name__ == "__main__":
    main()
