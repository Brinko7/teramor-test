#!/usr/bin/env python3
"""Procedural pixel-art generator for the Teramor rabbit (passive wildlife).

Renders a 4x4 directional sheet (24x24 frames, 96x96 sheet) of a small grey-brown
rabbit, matching the engine's sprite convention used by enemy.gd / wildlife.gd:
rows 0=down, 1=up, 2=left, 3=right; columns are the cycle (cycles [0,1,0,2], col
0 = stand). The rabbit is deliberately tiny — a compact body low in the frame,
big hind haunch, and two tall ears — so it reads clearly as the smallest critter
in the wilds. The "walk" frames hop: the body bobs and the hind foot kicks.

No third-party deps: PNGs are encoded with the stdlib (zlib + struct), the same
approach as gen_wolf.py.
"""

import os
import struct
import zlib

FW, FH = 24, 24
COLS, ROWS = 4, 4
W, H = FW * COLS, FH * ROWS  # 96 x 96

DOWN, UP, LEFT, RIGHT = 0, 1, 2, 3
PHASES = [0, 1, 2, 3]

OUTLINE = (40, 34, 30, 255)

# --- Palette (grey-brown rabbit) -------------------------------------------
FUR_L = (172, 160, 142)
FUR_M = (138, 126, 108)
FUR_D = (104, 92, 78)
BELLY = (208, 200, 188)
TAIL = (234, 230, 222)
FOOT = (120, 106, 90)
NOSE = (158, 104, 108)
EYE = (32, 26, 24)
EARIN = (172, 122, 124)


# --- PNG plumbing -----------------------------------------------------------

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


def get(buf, x, y):
    if x < 0 or y < 0 or x >= W or y >= H:
        return (0, 0, 0, 0)
    i = (y * W + x) * 4
    return (buf[i], buf[i + 1], buf[i + 2], buf[i + 3])


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


# --- Hop cycle --------------------------------------------------------------
# The stand frame (0) sits; the moving frames (1,2) bob the body up and kick the
# hind foot back, frame 3 returns to neutral.

def body_bob(phase):
    # Capped at -1 so the tall ears never touch the frame top (outline margin).
    return {0: 0, 1: -1, 2: -1, 3: 0}[phase]


def foot_kick(phase):
    return {0: 0, 1: 1, 2: 2, 3: 0}[phase]


# --- Side profile (RIGHT; mirrored for LEFT) --------------------------------

def draw_side(buf, ox, oy, phase):
    b = body_bob(phase)
    k = foot_kick(phase)
    # Cotton tail, rear/left.
    rect(buf, ox + 4, oy + 14 + b, ox + 5, oy + 16 + b, TAIL)
    # Big hind haunch.
    shade_rect(buf, ox + 5, oy + 12 + b, ox + 11, oy + 19 + b, FUR_L, FUR_M, FUR_D)
    # Body.
    shade_rect(buf, ox + 9, oy + 12 + b, ox + 16, oy + 18 + b, FUR_L, FUR_M, FUR_D)
    rect(buf, ox + 10, oy + 18 + b, ox + 15, oy + 18 + b, BELLY)
    # Head (front/right).
    shade_rect(buf, ox + 14, oy + 10 + b, ox + 19, oy + 16 + b, FUR_L, FUR_M, FUR_D)
    # Muzzle + nose.
    rect(buf, ox + 18, oy + 13 + b, ox + 20, oy + 15 + b, FUR_L)
    put(buf, ox + 20, oy + 14 + b, NOSE)
    # Eye.
    put(buf, ox + 17, oy + 12 + b, EYE)
    # Two tall ears.
    rect(buf, ox + 14, oy + 3 + b, ox + 15, oy + 10 + b, FUR_M)
    put(buf, ox + 14, oy + 5 + b, EARIN)
    rect(buf, ox + 16, oy + 3 + b, ox + 17, oy + 10 + b, FUR_M)
    put(buf, ox + 16, oy + 5 + b, EARIN)
    # Hind foot (long, kicks back) + small front paw.
    rect(buf, ox + 6 - k, oy + 19 + b, ox + 9, oy + 20 + b, FOOT)
    rect(buf, ox + 14, oy + 18 + b, ox + 15, oy + 20, FOOT)


# --- Front view (DOWN) ------------------------------------------------------

def draw_front(buf, ox, oy, phase):
    b = body_bob(phase)
    # Two tall ears.
    rect(buf, ox + 9, oy + 2 + b, ox + 10, oy + 9 + b, FUR_M)
    put(buf, ox + 9, oy + 4 + b, EARIN)
    rect(buf, ox + 13, oy + 2 + b, ox + 14, oy + 9 + b, FUR_M)
    put(buf, ox + 13, oy + 4 + b, EARIN)
    # Head.
    shade_rect(buf, ox + 8, oy + 8 + b, ox + 15, oy + 14 + b, FUR_L, FUR_M, FUR_D)
    # Nose + eyes.
    put(buf, ox + 11, oy + 12 + b, NOSE)
    put(buf, ox + 12, oy + 12 + b, NOSE)
    put(buf, ox + 9, oy + 10 + b, EYE)
    put(buf, ox + 14, oy + 10 + b, EYE)
    # Body.
    shade_rect(buf, ox + 8, oy + 14 + b, ox + 15, oy + 20 + b, FUR_L, FUR_M, FUR_D)
    rect(buf, ox + 10, oy + 15 + b, ox + 13, oy + 19 + b, BELLY)
    # Front paws.
    rect(buf, ox + 9, oy + 20 + b, ox + 10, oy + 21, FOOT)
    rect(buf, ox + 13, oy + 20 + b, ox + 14, oy + 21, FOOT)


# --- Rear view (UP) ---------------------------------------------------------

def draw_back(buf, ox, oy, phase):
    b = body_bob(phase)
    # Ears (back).
    rect(buf, ox + 9, oy + 2 + b, ox + 10, oy + 9 + b, FUR_M)
    rect(buf, ox + 13, oy + 2 + b, ox + 14, oy + 9 + b, FUR_M)
    # Back of head.
    shade_rect(buf, ox + 8, oy + 8 + b, ox + 15, oy + 13 + b, FUR_L, FUR_M, FUR_D)
    # Body + haunches.
    shade_rect(buf, ox + 7, oy + 13 + b, ox + 16, oy + 20 + b, FUR_L, FUR_M, FUR_D)
    rect(buf, ox + 11, oy + 9 + b, ox + 12, oy + 18 + b, FUR_D)   # spine
    # Cotton tail toward viewer.
    rect(buf, ox + 10, oy + 18 + b, ox + 13, oy + 21 + b, TAIL)
    # Hind feet.
    rect(buf, ox + 8, oy + 20 + b, ox + 9, oy + 21, FOOT)
    rect(buf, ox + 14, oy + 20 + b, ox + 15, oy + 21, FOOT)


# --- Assembly ---------------------------------------------------------------

def mirror_row(buf, src_facing, dst_facing):
    sy, dy = src_facing * FH, dst_facing * FH
    for col in range(COLS):
        for y in range(FH):
            for x in range(FW):
                c = get(buf, col * FW + x, sy + y)
                if c[3] != 0:
                    put(buf, col * FW + (FW - 1 - x), dy + y, c)


def main():
    buf = new_buf()
    for phase in PHASES:
        draw_front(buf, phase * FW, DOWN * FH, phase)
        draw_back(buf, phase * FW, UP * FH, phase)
        draw_side(buf, phase * FW, RIGHT * FH, phase)
    mirror_row(buf, RIGHT, LEFT)
    outline(buf)
    base = os.path.join(os.path.dirname(__file__), "..", "assets",
                        "placeholder", "wildlife", "rabbit.png")
    write_png(base, buf)
    print("generated rabbit sheet (24x24 frames, 96x96)")


if __name__ == "__main__":
    main()
