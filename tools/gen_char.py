#!/usr/bin/env python3
"""Procedural pixel-art character generator for Teramor.

Renders 4x4 directional walk sheets (24x40 frames, 96x160 sheet) in a
Stardew-leaning style: soft directional shading (light/mid/dark per material),
a readable face with eyes/brows/nose/mouth, pointed half-elf ears, framed hair
with a highlight, and a 4 frame walk cycle. The larger frame (vs the old 16x32)
buys the pixels needed for that detail.

Output is two kinds of asset:
  * Layered, tintable parts for the player paper-doll (skin + hair styles drawn
    in greyscale so `modulate` recolors them; outfit in fixed colors).
  * Baked, flattened sheets for NPCs and humanoid enemies (skin+outfit+hair
    composited with concrete colors) so non-customizable humans share the style.

No third-party deps: PNGs are encoded with the stdlib (zlib + struct).
"""

import os
import struct
import zlib

FW, FH = 24, 40
COLS, ROWS = 4, 4
W, H = FW * COLS, FH * ROWS  # 96 x 160

# Facing rows used by player.gd: 0=down,1=up,2=left,3=right.
DOWN, UP, LEFT, RIGHT = 0, 1, 2, 3
# Walk columns rendered. player.gd cycles [0,1,0,2]; col 3 is an extra rest.
PHASES = [0, 1, 2, 3]

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (38, 32, 30, 255)
EYE = (66, 54, 50)


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
    buf[i] = c[0]
    buf[i + 1] = c[1]
    buf[i + 2] = c[2]
    buf[i + 3] = c[3]


def rect(buf, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(buf, x, y, c)


def get(buf, x, y):
    if x < 0 or y < 0 or x >= W or y >= H:
        return TRANSPARENT
    i = (y * W + x) * 4
    return (buf[i], buf[i + 1], buf[i + 2], buf[i + 3])


def clear(buf, x, y):
    if x < 0 or y < 0 or x >= W or y >= H:
        return
    i = (y * W + x) * 4
    buf[i] = buf[i + 1] = buf[i + 2] = buf[i + 3] = 0


def shade_rect(buf, x0, y0, x1, y1, light, mid, dark):
    """Filled rect with a cheap directional bevel: lit on the top/left edges,
    shadowed on the bottom/right. Reads as a rounded volume rather than a flat
    block, which is most of what kept the old sprites looking blocky."""
    rect(buf, x0, y0, x1, y1, mid)
    rect(buf, x0, y0, x1, y0, light)   # top row
    rect(buf, x0, y0, x0, y1, light)   # left column
    rect(buf, x0, y1, x1, y1, dark)    # bottom row
    rect(buf, x1, y0, x1, y1, dark)    # right column


def outline(buf, color=OUTLINE):
    """Add a 1px dark border around every opaque cluster in the layer."""
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


def composite(dst, src):
    for i in range(0, len(src), 4):
        if src[i + 3] != 0:
            dst[i] = src[i]
            dst[i + 1] = src[i + 1]
            dst[i + 2] = src[i + 2]
            dst[i + 3] = src[i + 3]


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


# --- Palettes ---------------------------------------------------------------
# Tintable parts are greyscale (light/mid/dark) so modulate recolors them.
SL, SM, SD = (236, 236, 236), (200, 200, 200), (160, 160, 160)
HL, HM, HD = (230, 230, 230), (186, 186, 186), (142, 142, 142)

RANGER = {
    "tl": (104, 142, 84), "tm": (78, 112, 62), "td": (56, 84, 46),
    "pl": (110, 82, 54), "pm": (86, 62, 40), "pd": (64, 46, 30),
    "boot": (58, 42, 30), "belt": (150, 110, 60),
}
VILLAGER = {
    "tl": (128, 104, 158), "tm": (100, 78, 128), "td": (74, 56, 98),
    "pl": (96, 90, 84), "pm": (74, 68, 64), "pd": (56, 52, 48),
    "boot": (52, 46, 42), "belt": (70, 62, 56),
}
BANDIT = {
    "tl": (120, 64, 58), "tm": (92, 48, 44), "td": (66, 34, 32),
    "pl": (66, 60, 62), "pm": (48, 44, 46), "pd": (34, 32, 34),
    "boot": (34, 30, 30), "belt": (44, 38, 38),
}
ARCHER = {
    "tl": (88, 116, 92), "tm": (64, 90, 70), "td": (46, 66, 50),
    "pl": (74, 70, 60), "pm": (54, 52, 44), "pd": (38, 36, 30),
    "boot": (44, 38, 32), "belt": (96, 78, 50),
}
BRUTE = {
    "tl": (128, 78, 64), "tm": (98, 58, 48), "td": (70, 40, 34),
    "pl": (70, 62, 58), "pm": (52, 46, 44), "pd": (36, 32, 30),
    "boot": (40, 34, 32), "belt": (60, 50, 44),
}

SKIN_TONES = {
    "pale": (244, 214, 184), "tan": (226, 178, 134),
    "brown": (166, 114, 78), "deep": (110, 74, 50),
}
HAIR_COLORS = {
    "black": (44, 38, 36), "brown": (96, 62, 36), "blonde": (216, 178, 98),
    "auburn": (126, 58, 36), "ash": (176, 178, 184), "white": (224, 224, 228),
}


# --- Walk-cycle motion ------------------------------------------------------

def arm_swing(phase):
    return {0: (0, 0), 1: (1, -1), 2: (-1, 1), 3: (0, 0)}[phase]


def leg_offsets(phase):
    # Negative dy lifts a foot. One foot lifts per step.
    return {0: (0, 0), 1: (-1, 0), 2: (0, -1), 3: (0, 0)}[phase]


# --- Head / face / ears -----------------------------------------------------
# Frame coords (local): head x7..16 y4..15, neck y15..17, torso y18..27,
# belt y27..28, legs y30..38, feet ~y38. Centered on x=11.5.

def draw_head(skin, hair, ox, oy, facing, hair_style):
    if facing == UP:
        shade_rect(skin, ox + 7, oy + 4, ox + 16, oy + 15, SM, SM, SD)
    else:
        shade_rect(skin, ox + 7, oy + 4, ox + 16, oy + 15, SL, SM, SD)
    # Round the four corners so the head reads oval, not square.
    for cx, cy in ((7, 4), (16, 4), (7, 15), (16, 15)):
        clear(skin, ox + cx, oy + cy)
    # Neck.
    rect(skin, ox + 10, oy + 15, ox + 13, oy + 17, SM)
    rect(skin, ox + 10, oy + 15, ox + 13, oy + 15, SD)  # jaw shadow

    _draw_ears(skin, ox, oy, facing)
    if facing == DOWN:
        _draw_face_front(skin, ox, oy)
    elif facing in (LEFT, RIGHT):
        _draw_face_side(skin, ox, oy)
    _draw_hair(hair, ox, oy, facing, hair_style)


def _draw_ears(skin, ox, oy, facing):
    if facing == UP:
        put(skin, ox + 6, oy + 10, SM)
        put(skin, ox + 17, oy + 10, SD)
        return
    if facing == DOWN:
        # Pointed half-elf ears that flick up-and-out.
        rect(skin, ox + 6, oy + 9, ox + 6, oy + 11, SM)
        put(skin, ox + 6, oy + 8, SM)
        put(skin, ox + 6, oy + 10, SD)
        rect(skin, ox + 17, oy + 9, ox + 17, oy + 11, SM)
        put(skin, ox + 17, oy + 8, SM)
        put(skin, ox + 17, oy + 10, SD)
    else:
        # Profile: only the near (right) ear; mirror handles LEFT.
        rect(skin, ox + 16, oy + 9, ox + 16, oy + 11, SM)
        put(skin, ox + 16, oy + 8, SM)


def _draw_face_front(skin, ox, oy):
    # Brows sit just above wide-set eyes; pupil dark with a light inner catch.
    put(skin, ox + 9, oy + 9, SD)
    put(skin, ox + 14, oy + 9, SD)
    put(skin, ox + 9, oy + 10, EYE)
    put(skin, ox + 10, oy + 10, SL)
    put(skin, ox + 13, oy + 10, SL)
    put(skin, ox + 14, oy + 10, EYE)
    # Nose (single shadow pixel) and a small mouth.
    put(skin, ox + 12, oy + 12, SD)
    rect(skin, ox + 11, oy + 14, ox + 12, oy + 14, SD)
    # Light cheek shadow, kept off the jaw so the face doesn't look dirty.
    put(skin, ox + 15, oy + 11, SD)
    put(skin, ox + 15, oy + 12, SD)


def _draw_face_side(skin, ox, oy):
    put(skin, ox + 13, oy + 9, SD)          # brow
    put(skin, ox + 14, oy + 10, EYE)        # eye
    put(skin, ox + 17, oy + 12, SM)         # nose bump
    put(skin, ox + 16, oy + 12, SL)
    put(skin, ox + 15, oy + 14, SD)         # mouth


def _draw_hair(hair, ox, oy, facing, style):
    if facing == UP:
        shade_rect(hair, ox + 6, oy + 4, ox + 17, oy + 14, HM, HM, HD)
        rect(hair, ox + 6, oy + 4, ox + 17, oy + 5, HL)
        if style == "long":
            shade_rect(hair, ox + 8, oy + 15, ox + 15, oy + 26, HM, HM, HD)
        elif style == "spiky":
            for x in range(6, 18, 2):
                put(hair, ox + x, oy + 3, HL)
        return

    # Front / side cap framing the face.
    shade_rect(hair, ox + 6, oy + 4, ox + 17, oy + 8, HL, HM, HD)
    rect(hair, ox + 6, oy + 4, ox + 17, oy + 4, HL)        # top highlight
    rect(hair, ox + 8, oy + 5, ox + 11, oy + 5, HL)        # part highlight
    if style == "short":
        rect(hair, ox + 6, oy + 5, ox + 6, oy + 7, HM)     # short sideburns
        rect(hair, ox + 17, oy + 5, ox + 17, oy + 7, HD)
        rect(hair, ox + 7, oy + 8, ox + 16, oy + 8, HM)    # fringe
    elif style == "long":
        rect(hair, ox + 6, oy + 5, ox + 6, oy + 22, HM)    # long locks
        rect(hair, ox + 17, oy + 5, ox + 17, oy + 22, HD)
        rect(hair, ox + 7, oy + 8, ox + 16, oy + 8, HM)
    elif style == "spiky":
        for x in range(7, 17, 2):
            put(hair, ox + x, oy + 3, HL)                  # spikes
        rect(hair, ox + 6, oy + 5, ox + 6, oy + 7, HM)
        rect(hair, ox + 17, oy + 5, ox + 17, oy + 7, HD)
        rect(hair, ox + 7, oy + 8, ox + 16, oy + 8, HM)


# --- Body -------------------------------------------------------------------

def draw_body(skin, outfit, ox, oy, facing, phase, pal):
    sl, sr = arm_swing(phase)
    ldy, rdy = leg_offsets(phase)
    tl, tm, td = pal["tl"], pal["tm"], pal["td"]

    # Torso.
    shade_rect(outfit, ox + 7, oy + 18, ox + 16, oy + 27, tl, tm, td)
    rect(outfit, ox + 6, oy + 18, ox + 6, oy + 19, tm)    # shoulders
    rect(outfit, ox + 17, oy + 18, ox + 17, oy + 19, td)
    if facing == DOWN:
        rect(outfit, ox + 8, oy + 18, ox + 15, oy + 18, td)   # collar
        rect(outfit, ox + 11, oy + 19, ox + 12, oy + 26, td)  # placket

    # Belt + buckle.
    rect(outfit, ox + 7, oy + 27, ox + 16, oy + 28, pal["belt"])
    rect(outfit, ox + 11, oy + 27, ox + 12, oy + 28, (58, 44, 26))

    # Arms: sleeve, skin forearm, hand.
    rect(outfit, ox + 5, oy + 19 + sl, ox + 6, oy + 22 + sl, tm)
    rect(skin, ox + 5, oy + 23 + sl, ox + 6, oy + 25 + sl, SM)
    put(skin, ox + 5, oy + 26 + sl, SL)
    rect(outfit, ox + 17, oy + 19 + sr, ox + 18, oy + 22 + sr, td)
    rect(skin, ox + 17, oy + 23 + sr, ox + 18, oy + 25 + sr, SD)
    put(skin, ox + 18, oy + 26 + sr, SM)

    # Hips + legs + boots.
    pl, pm, pd = pal["pl"], pal["pm"], pal["pd"]
    rect(outfit, ox + 8, oy + 28, ox + 15, oy + 29, pm)
    rect(outfit, ox + 8, oy + 30, ox + 11, oy + 35 + ldy, pl)
    rect(outfit, ox + 12, oy + 30, ox + 15, oy + 35 + rdy, pm)
    rect(outfit, ox + 11, oy + 30, ox + 12, oy + 34, pd)   # leg-gap shadow
    rect(outfit, ox + 8, oy + 36 + ldy, ox + 11, oy + 38 + ldy, pal["boot"])
    rect(outfit, ox + 12, oy + 36 + rdy, ox + 15, oy + 38 + rdy, pal["boot"])
    put(outfit, ox + 8, oy + 36 + ldy, (96, 74, 54))       # toe glints
    put(outfit, ox + 12, oy + 36 + rdy, (96, 74, 54))


# --- Assembly ---------------------------------------------------------------

def render_human(pal, hair_style):
    skin, outfit, hair = new_buf(), new_buf(), new_buf()
    for facing in (DOWN, UP, LEFT, RIGHT):
        for phase in PHASES:
            ox, oy = phase * FW, facing * FH
            draw_body(skin, outfit, ox, oy, facing, phase, pal)
            draw_head(skin, hair, ox, oy, facing, hair_style)
    for buf in (skin, outfit, hair):
        _mirror_row(buf, RIGHT, LEFT)
    return skin, outfit, hair


def _mirror_row(buf, src_facing, dst_facing):
    sy, dy = src_facing * FH, dst_facing * FH
    for col in range(COLS):
        for y in range(FH):
            for x in range(FW):
                c = get(buf, col * FW + x, sy + y)
                if c[3] != 0:
                    put(buf, col * FW + (FW - 1 - x), dy + y, c)


def tint(buf, color):
    out = bytearray(len(buf))
    for i in range(0, len(buf), 4):
        a = buf[i + 3]
        if a == 0:
            continue
        out[i] = buf[i] * color[0] // 255
        out[i + 1] = buf[i + 1] * color[1] // 255
        out[i + 2] = buf[i + 2] * color[2] // 255
        out[i + 3] = a
    return out


def render_vest():
    """Leather chest armor (BODY slot) aligned to the torso, synced per frame."""
    ll, lm, ld = (158, 116, 70), (124, 86, 50), (92, 62, 34)
    buf = new_buf()
    for facing in (DOWN, UP, LEFT, RIGHT):
        for phase in PHASES:
            ox, oy = phase * FW, facing * FH
            shade_rect(buf, ox + 7, oy + 18, ox + 16, oy + 26, ll, lm, ld)
            rect(buf, ox + 6, oy + 18, ox + 6, oy + 19, lm)   # shoulder pads
            rect(buf, ox + 17, oy + 18, ox + 17, oy + 19, ld)
            if facing == DOWN:
                rect(buf, ox + 11, oy + 19, ox + 12, oy + 26, ld)  # strap
    _mirror_row(buf, RIGHT, LEFT)
    outline(buf)
    write_png(os.path.join(BASE, "items", "vest_overlay.png"), buf)


BASE = os.path.join(os.path.dirname(__file__), "..", "assets", "placeholder")


def save_layered_player():
    """Tintable body + 3 hair styles + fixed ranger outfit for the paper-doll."""
    cdir = os.path.join(BASE, "char")
    skin, outfit, _ = render_human(RANGER, "short")
    outline(skin)
    outline(outfit)
    write_png(os.path.join(cdir, "body.png"), skin)
    write_png(os.path.join(cdir, "outfit_ranger.png"), outfit)
    for style in ("short", "long", "spiky"):
        _, _, hair = render_human(RANGER, style)
        outline(hair)
        write_png(os.path.join(cdir, "hair_%s.png" % style), hair)


def save_baked(path, pal, skin_tone, hair_color, hair_style):
    skin, outfit, hair = render_human(pal, hair_style)
    base = new_buf()
    composite(base, tint(skin, skin_tone))
    composite(base, outfit)
    composite(base, tint(hair, hair_color))
    outline(base)
    write_png(path, base)


def main():
    save_layered_player()
    save_baked(os.path.join(BASE, "player.png"), RANGER,
               SKIN_TONES["tan"], HAIR_COLORS["brown"], "short")
    save_baked(os.path.join(BASE, "npc_villager.png"), VILLAGER,
               SKIN_TONES["pale"], HAIR_COLORS["auburn"], "long")
    save_baked(os.path.join(BASE, "enemy_bandit.png"), BANDIT,
               SKIN_TONES["tan"], HAIR_COLORS["black"], "short")
    save_baked(os.path.join(BASE, "enemies", "enemy_archer.png"), ARCHER,
               SKIN_TONES["brown"], HAIR_COLORS["black"], "short")
    save_baked(os.path.join(BASE, "enemies", "enemy_brute.png"), BRUTE,
               SKIN_TONES["tan"], HAIR_COLORS["black"], "spiky")
    render_vest()
    print("generated character sheets (24x40)")


if __name__ == "__main__":
    main()
