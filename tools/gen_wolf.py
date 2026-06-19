#!/usr/bin/env python3
"""Procedural pixel-art generator for the Teramor wolf enemy.

Renders a 4x4 directional walk sheet (24x24 frames, 96x96 sheet) of a grey
timber wolf as a quadruped, matching the engine's sprite convention used by
enemy.gd: rows 0=down, 1=up, 2=left, 3=right; columns are the walk cycle
(enemy.gd cycles [0,1,0,2], col 0 = stand). The side profiles carry the clear
wolf silhouette (long body, snout, ears, bushy tail, four legs); the front and
rear views show ears, muzzle/spine and animated legs.

No third-party deps: PNGs are encoded with the stdlib (zlib + struct), the same
approach as gen_char.py.
"""

import os
import struct
import zlib

FW, FH = 24, 24
COLS, ROWS = 4, 4
W, H = FW * COLS, FH * ROWS  # 96 x 96

DOWN, UP, LEFT, RIGHT = 0, 1, 2, 3
PHASES = [0, 1, 2, 3]

OUTLINE = (28, 26, 32, 255)

# --- Palette (grey timber wolf) --------------------------------------------
FUR_L = (158, 160, 170)
FUR_M = (120, 122, 134)
FUR_D = (86, 88, 100)
BELLY = (196, 198, 204)
LEG_D = (96, 98, 110)
PAW = (60, 62, 72)
NOSE = (32, 30, 36)
EYE = (240, 196, 74)   # amber
EARIN = (132, 100, 100)


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


# --- Gait --------------------------------------------------------------------
# (front_dx, front_lift, hind_dx, hind_lift) for the near pair; far pair is the
# opposite phase so diagonal legs swing together (a trot).

def near_gait(phase):
    return {0: (0, 0, 0, 0), 1: (1, 1, -1, 0),
            2: (-1, 0, 1, 1), 3: (0, 0, 0, 0)}[phase]


def far_gait(phase):
    return {0: (0, 0, 0, 0), 1: (-1, 0, 1, 1),
            2: (1, 1, -1, 0), 3: (0, 0, 0, 0)}[phase]


def pair_lift(phase):
    # left/right leg lift for front and rear views
    return {0: (0, 0), 1: (1, 0), 2: (0, 1), 3: (0, 0)}[phase]


def leg(buf, x, y_top, y_bottom, col):
    rect(buf, x, y_top, x + 1, y_bottom, col)
    rect(buf, x, y_bottom, x + 1, y_bottom, PAW)


# --- Side profile (RIGHT; mirrored for LEFT) --------------------------------

def draw_side(buf, ox, oy, phase):
    nf_dx, nf_lift, nh_dx, nh_lift = near_gait(phase)
    ff_dx, ff_lift, fh_dx, fh_lift = far_gait(phase)

    # Bushy tail, rear/left, sweeping up.
    rect(buf, ox + 1, oy + 8, ox + 4, oy + 13, FUR_M)
    rect(buf, ox + 1, oy + 6, ox + 3, oy + 8, FUR_M)
    rect(buf, ox + 3, oy + 11, ox + 4, oy + 13, FUR_D)
    put(buf, ox + 1, oy + 6, FUR_L)

    # Far legs (behind body, darker).
    leg(buf, ox + 7 + fh_dx, oy + 15, oy + 21 - fh_lift, LEG_D)
    leg(buf, ox + 13 + ff_dx, oy + 15, oy + 21 - ff_lift, LEG_D)

    # Torso.
    shade_rect(buf, ox + 4, oy + 10, ox + 16, oy + 16, FUR_L, FUR_M, FUR_D)
    rect(buf, ox + 5, oy + 10, ox + 15, oy + 10, FUR_D)   # back line
    rect(buf, ox + 6, oy + 16, ox + 15, oy + 16, BELLY)   # belly
    # Rear haunch.
    shade_rect(buf, ox + 3, oy + 11, ox + 7, oy + 16, FUR_L, FUR_M, FUR_D)

    # Neck + head (right).
    rect(buf, ox + 15, oy + 9, ox + 18, oy + 14, FUR_M)
    shade_rect(buf, ox + 17, oy + 8, ox + 21, oy + 13, FUR_L, FUR_M, FUR_D)
    # Muzzle / snout.
    rect(buf, ox + 20, oy + 11, ox + 23, oy + 13, FUR_L)
    put(buf, ox + 23, oy + 12, NOSE)
    rect(buf, ox + 20, oy + 13, ox + 22, oy + 13, FUR_D)
    # Ear (pointed, on top of head).
    put(buf, ox + 18, oy + 5, FUR_M)
    rect(buf, ox + 17, oy + 6, ox + 18, oy + 8, FUR_M)
    put(buf, ox + 18, oy + 7, EARIN)
    # Eye.
    put(buf, ox + 19, oy + 10, EYE)

    # Near legs (front, normal colour).
    leg(buf, ox + 9 + nh_dx, oy + 16, oy + 22 - nh_lift, FUR_M)
    leg(buf, ox + 15 + nf_dx, oy + 16, oy + 22 - nf_lift, FUR_M)


# --- Front view (DOWN) ------------------------------------------------------

def draw_front(buf, ox, oy, phase):
    ll, rl = pair_lift(phase)
    # Ears.
    rect(buf, ox + 7, oy + 2, ox + 8, oy + 4, FUR_M)
    put(buf, ox + 8, oy + 3, EARIN)
    rect(buf, ox + 15, oy + 2, ox + 16, oy + 4, FUR_M)
    put(buf, ox + 15, oy + 3, EARIN)
    # Head.
    shade_rect(buf, ox + 7, oy + 4, ox + 16, oy + 11, FUR_L, FUR_M, FUR_D)
    # Muzzle.
    rect(buf, ox + 10, oy + 9, ox + 13, oy + 13, FUR_L)
    rect(buf, ox + 11, oy + 12, ox + 12, oy + 12, NOSE)
    put(buf, ox + 11, oy + 13, FUR_D)
    # Eyes + brows.
    put(buf, ox + 9, oy + 7, FUR_D)
    put(buf, ox + 14, oy + 7, FUR_D)
    put(buf, ox + 9, oy + 8, EYE)
    put(buf, ox + 14, oy + 8, EYE)
    # Chest / body.
    shade_rect(buf, ox + 7, oy + 12, ox + 16, oy + 18, FUR_L, FUR_M, FUR_D)
    rect(buf, ox + 10, oy + 13, ox + 13, oy + 17, BELLY)
    rect(buf, ox + 6, oy + 13, ox + 7, oy + 17, FUR_D)    # haunch hint
    rect(buf, ox + 16, oy + 13, ox + 17, oy + 17, FUR_D)
    # Front legs.
    leg(buf, ox + 7, oy + 17, oy + 22 - ll, LEG_D)
    leg(buf, ox + 15, oy + 17, oy + 22 - rl, LEG_D)


# --- Rear view (UP) ---------------------------------------------------------

def draw_back(buf, ox, oy, phase):
    ll, rl = pair_lift(phase)
    # Ears (back).
    rect(buf, ox + 7, oy + 2, ox + 8, oy + 4, FUR_M)
    rect(buf, ox + 15, oy + 2, ox + 16, oy + 4, FUR_M)
    # Back of head.
    shade_rect(buf, ox + 7, oy + 4, ox + 16, oy + 10, FUR_L, FUR_M, FUR_D)
    # Back / body.
    shade_rect(buf, ox + 7, oy + 10, ox + 16, oy + 18, FUR_L, FUR_M, FUR_D)
    rect(buf, ox + 11, oy + 5, ox + 12, oy + 17, FUR_D)   # spine
    rect(buf, ox + 6, oy + 12, ox + 8, oy + 17, FUR_M)    # haunches
    rect(buf, ox + 15, oy + 12, ox + 17, oy + 17, FUR_M)
    # Bushy tail toward viewer.
    rect(buf, ox + 10, oy + 16, ox + 13, oy + 22, FUR_M)
    rect(buf, ox + 11, oy + 18, ox + 12, oy + 22, FUR_D)
    put(buf, ox + 11, oy + 23, FUR_M)
    # Hind legs.
    leg(buf, ox + 7, oy + 17, oy + 22 - ll, LEG_D)
    leg(buf, ox + 15, oy + 17, oy + 22 - rl, LEG_D)


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
                        "placeholder", "enemies", "enemy_wolf.png")
    write_png(base, buf)
    print("generated wolf sheet (24x24 frames, 96x96)")


if __name__ == "__main__":
    main()
