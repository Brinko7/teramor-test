#!/usr/bin/env python3
"""Procedural pixel-art generator for the Teramor deer (passive wildlife).

Renders a 4x4 directional walk sheet (24x24 frames, 96x96 sheet) of a tan forest
deer as a quadruped, matching the engine's sprite convention used by enemy.gd /
wildlife.gd: rows 0=down, 1=up, 2=left, 3=right; columns are the walk cycle
(cycles [0,1,0,2], col 0 = stand). The deer reads leggier and taller than the
wolf, with a raised neck, a small head, and a forked antler on the side/front
views so the silhouette is unmistakably "deer, not wolf."

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

OUTLINE = (40, 30, 24, 255)

# --- Palette (tan/brown deer) ----------------------------------------------
FUR_L = (186, 146, 100)
FUR_M = (150, 112, 72)
FUR_D = (112, 80, 50)
BELLY = (214, 190, 158)
RUMP = (226, 212, 188)   # pale rump/tail patch
LEG_D = (96, 68, 44)
HOOF = (48, 38, 34)
NOSE = (34, 28, 30)
EYE = (40, 28, 22)
ANTLER = (206, 192, 162)
EARIN = (150, 110, 104)


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


# --- Gait -------------------------------------------------------------------
# (front_dx, front_lift, hind_dx, hind_lift) for the near pair; far pair is the
# opposite phase so diagonal legs swing together (a trot).

def near_gait(phase):
    return {0: (0, 0, 0, 0), 1: (1, 1, -1, 0),
            2: (-1, 0, 1, 1), 3: (0, 0, 0, 0)}[phase]


def far_gait(phase):
    return {0: (0, 0, 0, 0), 1: (-1, 0, 1, 1),
            2: (1, 1, -1, 0), 3: (0, 0, 0, 0)}[phase]


def pair_lift(phase):
    return {0: (0, 0), 1: (1, 0), 2: (0, 1), 3: (0, 0)}[phase]


def leg(buf, x, y_top, y_bottom, col):
    rect(buf, x, y_top, x, y_bottom, col)
    put(buf, x, y_bottom, HOOF)


# --- Side profile (RIGHT; mirrored for LEFT) --------------------------------

def draw_side(buf, ox, oy, phase):
    nf_dx, nf_lift, nh_dx, nh_lift = near_gait(phase)
    ff_dx, ff_lift, fh_dx, fh_lift = far_gait(phase)

    # Short upright tail with pale underside, rear/left.
    rect(buf, ox + 3, oy + 8, ox + 4, oy + 12, FUR_M)
    rect(buf, ox + 3, oy + 8, ox + 3, oy + 11, RUMP)

    # Far legs (behind, darker) — long and slender.
    leg(buf, ox + 7 + fh_dx, oy + 14, oy + 22 - fh_lift, LEG_D)
    leg(buf, ox + 14 + ff_dx, oy + 14, oy + 22 - ff_lift, LEG_D)

    # Torso (raised up the frame — deer stand tall).
    shade_rect(buf, ox + 4, oy + 8, ox + 16, oy + 14, FUR_L, FUR_M, FUR_D)
    rect(buf, ox + 5, oy + 8, ox + 15, oy + 8, FUR_D)    # back line
    rect(buf, ox + 6, oy + 14, ox + 15, oy + 14, BELLY)  # belly
    rect(buf, ox + 4, oy + 9, ox + 5, oy + 13, RUMP)     # pale rump

    # Long neck rising to the head (front/right).
    rect(buf, ox + 15, oy + 4, ox + 17, oy + 11, FUR_M)
    rect(buf, ox + 17, oy + 4, ox + 17, oy + 9, FUR_L)
    # Head.
    shade_rect(buf, ox + 16, oy + 2, ox + 20, oy + 6, FUR_L, FUR_M, FUR_D)
    # Muzzle.
    rect(buf, ox + 19, oy + 4, ox + 22, oy + 6, FUR_L)
    put(buf, ox + 22, oy + 5, NOSE)
    rect(buf, ox + 19, oy + 6, ox + 21, oy + 6, FUR_D)
    # Ear.
    rect(buf, ox + 15, oy + 2, ox + 16, oy + 3, FUR_M)
    put(buf, ox + 15, oy + 3, EARIN)
    # Antler — a short forked tine above the brow (kept 1px off the frame top).
    rect(buf, ox + 18, oy + 1, ox + 18, oy + 3, ANTLER)
    put(buf, ox + 19, oy + 1, ANTLER)
    put(buf, ox + 17, oy + 1, ANTLER)
    # Eye.
    put(buf, ox + 18, oy + 4, EYE)

    # Near legs (front, normal colour).
    leg(buf, ox + 9 + nh_dx, oy + 14, oy + 22 - nh_lift, FUR_M)
    leg(buf, ox + 16 + nf_dx, oy + 14, oy + 22 - nf_lift, FUR_M)


# --- Front view (DOWN) ------------------------------------------------------

def draw_front(buf, ox, oy, phase):
    ll, rl = pair_lift(phase)
    # Antlers spreading up and out (kept 1px off the frame top).
    rect(buf, ox + 8, oy + 1, ox + 8, oy + 3, ANTLER)
    put(buf, ox + 7, oy + 1, ANTLER)
    rect(buf, ox + 15, oy + 1, ox + 15, oy + 3, ANTLER)
    put(buf, ox + 16, oy + 1, ANTLER)
    # Ears.
    rect(buf, ox + 6, oy + 3, ox + 7, oy + 5, FUR_M)
    put(buf, ox + 7, oy + 4, EARIN)
    rect(buf, ox + 16, oy + 3, ox + 17, oy + 5, FUR_M)
    put(buf, ox + 16, oy + 4, EARIN)
    # Head.
    shade_rect(buf, ox + 8, oy + 3, ox + 15, oy + 10, FUR_L, FUR_M, FUR_D)
    # Muzzle.
    rect(buf, ox + 10, oy + 8, ox + 13, oy + 12, FUR_L)
    rect(buf, ox + 11, oy + 11, ox + 12, oy + 12, NOSE)
    # Eyes.
    put(buf, ox + 9, oy + 6, EYE)
    put(buf, ox + 14, oy + 6, EYE)
    # Chest / body.
    shade_rect(buf, ox + 8, oy + 12, ox + 15, oy + 18, FUR_L, FUR_M, FUR_D)
    rect(buf, ox + 10, oy + 13, ox + 13, oy + 17, BELLY)
    # Front legs (long).
    leg(buf, ox + 9, oy + 18, oy + 22 - ll, LEG_D)
    leg(buf, ox + 14, oy + 18, oy + 22 - rl, LEG_D)


# --- Rear view (UP) ---------------------------------------------------------

def draw_back(buf, ox, oy, phase):
    ll, rl = pair_lift(phase)
    # Antler tips just cresting the head (kept 1px off the frame top).
    put(buf, ox + 8, oy + 1, ANTLER)
    put(buf, ox + 15, oy + 1, ANTLER)
    # Ears (back).
    rect(buf, ox + 6, oy + 2, ox + 7, oy + 4, FUR_M)
    rect(buf, ox + 16, oy + 2, ox + 17, oy + 4, FUR_M)
    # Back of head.
    shade_rect(buf, ox + 8, oy + 3, ox + 15, oy + 9, FUR_L, FUR_M, FUR_D)
    # Back / body.
    shade_rect(buf, ox + 8, oy + 9, ox + 15, oy + 18, FUR_L, FUR_M, FUR_D)
    rect(buf, ox + 11, oy + 4, ox + 12, oy + 16, FUR_D)   # spine
    # Pale rump patch + short tail toward viewer.
    rect(buf, ox + 9, oy + 13, ox + 14, oy + 18, RUMP)
    rect(buf, ox + 11, oy + 16, ox + 12, oy + 20, RUMP)
    put(buf, ox + 11, oy + 15, FUR_M)
    # Hind legs (long).
    leg(buf, ox + 9, oy + 18, oy + 22 - ll, LEG_D)
    leg(buf, ox + 14, oy + 18, oy + 22 - rl, LEG_D)


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
                        "placeholder", "wildlife", "deer.png")
    write_png(base, buf)
    print("generated deer sheet (24x24 frames, 96x96)")


if __name__ == "__main__":
    main()
