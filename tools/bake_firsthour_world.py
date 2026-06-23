#!/usr/bin/env python3
"""Bake first-hour WORLD art at the remaster scale (pinned to 84x120 hero).

Buildings, nature, ground tiles, and groundcover decals baked as foot-anchored
individual PNGs into assets/remaster/world/.

Scale bible (from CLAUDE.md):
  tile       = 32x32  (seamless)
  hero       = 84x120
  door       ~ 110px tall (one hero tall — the governing constraint)
  cottage    ~ 180x210  (door ~110)
  townhouse  ~ 200x260
  big bldg   ~ 240-300 wide x 320-440 tall
  tree       ~ 96-130 wide x 220-300 tall
  small prop = 28-64 wide

Foot-anchor: offset = Vector2(-anchor_x, -anchor_y) where the anchor pixel
is the bottom-centre of the sprite's visual base.

Stdlib only, no third-party deps.
Run: python3 tools/bake_firsthour_world.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas, P, rgb, lerp, shade  # noqa: E402

OUTDIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "assets", "remaster", "world"))

INK = P.OUTLINE        # dark ink outline
SOFT = P.OUTLINE_SOFT  # softer outline for interiors / overlaps

# ── Palette aliases (warm Eastward names) ────────────────────────────────────
GRASS  = P.GRASS
DIRT   = P.SOIL
PATH   = P.PATH
STONE  = P.STONE
WOOD   = P.WOOD
THAT   = P.THATCH
PLAS   = P.PLASTER
LEAF   = P.FOLIAGE
BARK   = P.BARK
GLASS  = [rgb(252, 224, 150), rgb(236, 196, 108), rgb(196, 150, 78)]
FLOW   = [rgb(244, 238, 210), rgb(244, 206, 108), rgb(220, 108, 96), rgb(170, 134, 206)]
ROOF_R = P.ROOF
SLATE  = P.ROOF_SLATE
META   = P.METAL
CLOTH  = P.CLOTH
EMBER  = P.EMBER

# ── Helpers ──────────────────────────────────────────────────────────────────

def R(c, x0, y0, x1, y1, col): c.rect(x0, y0, x1, y1, col)
def L(c, x0, y0, x1, y1, col): c.line(x0, y0, x1, y1, col)
def E(c, cx, cy, rx, ry, col):  c.ellipse(cx, cy, rx, ry, col, fill=True)
def V(c, x, y0, y1, col):       c.vline(x, y0, y1, col)
def H(c, x0, x1, y, col):       c.hline(x0, x1, y, col)


def _timber_frame(c, x, y, w, h, tilt_r=True, tilt_l=True):
    """Draw a plaster + timber-frame wall panel (inner rectangle coords)."""
    # plaster fill
    c.mottle(x, y, x + w, y + h, PLAS, random.Random(x * 7 + y * 3), scale=6)
    R(c, x, y, x + 3, y + h, PLAS[0])        # left highlight
    R(c, x + w - 3, y, x + w, y + h, PLAS[3]) # right shadow
    # corner posts
    for px in (x, x + w - 4):
        R(c, px, y, px + 3, y + h, WOOD[2])
        R(c, px, y, px, y + h, WOOD[1])
    # top rail
    R(c, x, y, x + w, y + 3, WOOD[2])
    R(c, x, y, x + w, y, WOOD[1])
    # mid rail
    mid_y = y + h // 2
    R(c, x, mid_y, x + w, mid_y + 3, WOOD[2])
    # diagonal braces
    if tilt_r:
        L(c, x + 6, mid_y + 4, x + w // 2 - 4, y + 3, WOOD[3])
    if tilt_l:
        L(c, x + w // 2 + 4, y + 3, x + w - 6, mid_y + 4, WOOD[3])


def _door(c, x, y_top, door_h=110, door_w=36):
    """Arched, plank-detailed door. x is left edge, y_top is top of doorway."""
    # arch crown (rounded top)
    arch_r = door_w // 2
    arch_cx = x + door_w // 2
    arch_cy = y_top + arch_r
    for dy in range(arch_r + 1):
        for dx in range(-arch_r, arch_r + 1):
            if dx * dx + (dy - arch_r) * (dy - arch_r) <= arch_r * arch_r:
                c.paint(arch_cx + dx, arch_cy - dy, WOOD[3])
    # rectangular body below the arch
    R(c, x, y_top + arch_r, x + door_w - 1, y_top + door_h - 1, WOOD[3])
    # lit top of arch
    H(c, x + 2, x + door_w - 3, y_top + 1, WOOD[1])
    # vertical planks
    for px in range(x + 4, x + door_w - 2, 5):
        L(c, px, y_top + arch_r, px, y_top + door_h - 2, WOOD[4])
    # cross-bar
    H(c, x + 2, x + door_w - 3, y_top + door_h * 2 // 3, WOOD[1])
    # door handle
    c.paint(x + door_w - 7, y_top + door_h // 2 + 4, rgb(40, 30, 22))


def _window(c, wx, wy, ww=24, wh=22):
    """Glowing lit window with cross mullion."""
    R(c, wx, wy, wx + ww, wy + wh, GLASS[1])
    R(c, wx, wy, wx + ww, wy + 3, GLASS[0])  # top glow
    # frame
    R(c, wx - 2, wy - 2, wx + ww + 2, wy - 2, WOOD[2])
    R(c, wx - 2, wy + wh + 2, wx + ww + 2, wy + wh + 2, WOOD[2])
    V(c, wx - 2, wy - 2, wy + wh + 2, WOOD[2])
    V(c, wx + ww + 2, wy - 2, wy + wh + 2, WOOD[2])
    # mullion cross
    V(c, wx + ww // 2, wy, wy + wh, WOOD[3])
    H(c, wx, wx + ww, wy + wh // 2, WOOD[3])


def _thatch_roof(c, bx, apex_y, roof_w, roof_h, seed=7):
    """Steep thatch roof (triangle from apex). bx = left of roof base."""
    rnd = random.Random(seed)
    cx = bx + roof_w // 2
    for i in range(roof_h):
        half = (roof_w // 2 + 16) * (roof_h - i) // roof_h
        col = THAT[1] if i % 3 else THAT[2]
        R(c, cx - half, apex_y + i, cx + half, apex_y + i, col)
    R(c, cx - 7, apex_y, cx + 7, apex_y + 2, THAT[3])  # ridge
    # thatch speckle / texture
    for _ in range(roof_w * roof_h // 16):
        tx = rnd.randrange(bx - 14, bx + roof_w + 14)
        ty = rnd.randrange(apex_y, apex_y + roof_h)
        half = (roof_w // 2 + 16) * (roof_h - (ty - apex_y)) // roof_h
        if abs(tx - cx) < half:
            c.paint(tx, ty, THAT[0] if rnd.random() < 0.4 else THAT[3])
    # eave shadow
    R(c, cx - (roof_w // 2 + 16), apex_y + roof_h - 1,
      cx + (roof_w // 2 + 16), apex_y + roof_h + 1, THAT[3])


def _chimney(c, cx, top_y, h=28):
    """Stone chimney + translucent smoke puffs."""
    R(c, cx - 5, top_y, cx + 5, top_y + h, STONE[2])
    R(c, cx - 5, top_y, cx + 5, top_y + 2, STONE[3])   # cap overhang
    R(c, cx - 6, top_y, cx + 6, top_y + 3, STONE[3])
    # smoke
    for i, (sx, sy, r) in enumerate(
            [(cx, top_y - 8, 5), (cx - 2, top_y - 16, 6), (cx + 1, top_y - 24, 7)]):
        c.disc(sx, sy, r, rgb(214, 210, 202, 150 - i * 30))


# ─────────────────────────────────────────────────────────────────────────────
# BUILDINGS
# ─────────────────────────────────────────────────────────────────────────────

def draw_cabin(c):
    """Timber-frame cabin ~180×210. Door ~110 px tall at scale.
    foot-anchor = bottom-centre of stone footing."""
    W, H_CANVAS = 184, 214
    # x/y of the structural layout (bottom of stone footing = H_CANVAS - 4)
    bx, by = 2, H_CANVAS - 6   # left, foot-y
    bw = 180     # building width
    wall_h = 110  # wall height above footing
    foot_h = 14   # stone footing height

    # stone footing
    R(c, bx, by - foot_h, bx + bw, by, STONE[2])
    H(c, bx, bx + bw, by - foot_h, STONE[1])
    H(c, bx, bx + bw, by - 2, STONE[3])
    for sx in range(bx, bx + bw, 14): V(c, sx, by - foot_h + 1, by - 3, STONE[3])

    # timber-frame wall
    wall_y = by - foot_h - wall_h
    _timber_frame(c, bx, wall_y, bw, wall_h)

    # door (left-of-centre) — door_h ~110 means top aligns with wall top
    door_x = bx + 22
    door_y = by - foot_h - 110  # top of door
    _door(c, door_x, door_y, door_h=110, door_w=36)

    # two windows (right side)
    _window(c, bx + 80, wall_y + 20, 28, 24)
    _window(c, bx + 122, wall_y + 20, 28, 24)

    # thatch roof
    roof_h = 54
    _thatch_roof(c, bx, wall_y - roof_h, bw, roof_h, seed=42)

    # chimney (right side)
    _chimney(c, bx + bw - 28, wall_y - roof_h - 22)

    c.outline(INK)


def draw_townhouse(c):
    """Two-storey timber-frame townhouse ~200×260."""
    bx, by = 2, 258
    bw = 196
    wall_h1 = 100   # ground floor
    wall_h2 = 90    # upper floor
    foot_h = 14

    R(c, bx, by - foot_h, bx + bw, by, STONE[2])
    H(c, bx, bx + bw, by - foot_h, STONE[1])

    # ground floor
    _timber_frame(c, bx, by - foot_h - wall_h1, bw, wall_h1)
    door_x = bx + 80
    door_y = by - foot_h - 110
    _door(c, door_x, door_y, door_h=110, door_w=38)
    _window(c, bx + 14, by - foot_h - 60, 26, 22)
    _window(c, bx + bw - 52, by - foot_h - 60, 26, 22)

    # upper floor (slight overhang)
    upper_y = by - foot_h - wall_h1 - wall_h2
    _timber_frame(c, bx - 4, upper_y, bw + 8, wall_h2, tilt_r=True, tilt_l=False)
    _window(c, bx + 30, upper_y + 16, 28, 24)
    _window(c, bx + bw - 66, upper_y + 16, 28, 24)
    # flower box under upper windows
    R(c, bx + 28, upper_y + 42, bx + 60, upper_y + 46, WOOD[2])
    R(c, bx + bw - 68, upper_y + 42, bx + bw - 36, upper_y + 46, WOOD[2])
    for fx in range(bx + 30, bx + 62, 5):
        c.paint(fx, upper_y + 40, FLOW[0 if fx % 2 == 0 else 1])

    # slate roof
    roof_h = 68
    cx = bx + bw // 2
    for i in range(roof_h):
        half = (bw // 2 + 6) * (roof_h - i) // roof_h
        col = SLATE[1] if i % 4 < 2 else SLATE[2]
        R(c, cx - half, upper_y - roof_h + i, cx + half, upper_y - roof_h + i, col)
    R(c, cx - 4, upper_y - roof_h, cx + 4, upper_y - roof_h + 2, SLATE[3])

    _chimney(c, bx + bw - 30, upper_y - roof_h - 20)
    c.outline(INK)


def draw_tavern(c):
    """Large 2-story tavern with wide thatch roof ~280×340."""
    bx, by = 2, 338
    bw = 276
    wall_h1 = 120
    wall_h2 = 100
    foot_h = 16

    R(c, bx, by - foot_h, bx + bw, by, STONE[2])
    H(c, bx, bx + bw, by - foot_h, STONE[1])
    for sx in range(bx, bx + bw, 14): V(c, sx, by - foot_h + 1, by - 2, STONE[3])

    # ground floor
    _timber_frame(c, bx, by - foot_h - wall_h1, bw, wall_h1, tilt_r=True, tilt_l=True)
    # wide double door
    _door(c, bx + bw // 2 - 20, by - foot_h - 112, door_h=112, door_w=40)
    for wx in (bx + 20, bx + bw - 60):
        _window(c, wx, by - foot_h - 70, 34, 26)

    # upper floor
    upper_y = by - foot_h - wall_h1 - wall_h2
    _timber_frame(c, bx - 6, upper_y, bw + 12, wall_h2)
    for wx in (bx + 30, bx + bw // 2 - 22, bx + bw - 76):
        _window(c, wx, upper_y + 18, 30, 26)

    # hanging sign
    sign_x = bx + bw // 2 - 36
    sign_y = by - foot_h - 130
    R(c, sign_x, sign_y - 4, sign_x + 72, sign_y + 18, WOOD[1])
    R(c, sign_x, sign_y - 4, sign_x + 72, sign_y - 2, WOOD[0])
    V(c, sign_x + 8, sign_y - 14, sign_y - 4, WOOD[2])
    V(c, sign_x + 64, sign_y - 14, sign_y - 4, WOOD[2])

    # wide thatch roof
    roof_h = 80
    _thatch_roof(c, bx - 6, upper_y - roof_h, bw + 12, roof_h, seed=11)
    _chimney(c, bx + 30, upper_y - roof_h - 24)
    _chimney(c, bx + bw - 34, upper_y - roof_h - 24)

    c.outline(INK)


def draw_blacksmith(c):
    """Blacksmith ~260×320. Wide, heavy stone walls, open forge bay."""
    bx, by = 2, 318
    bw = 256
    wall_h = 140
    foot_h = 18

    R(c, bx, by - foot_h, bx + bw, by, STONE[1])
    for sx in range(bx, bx + bw, 12): V(c, sx, by - foot_h, by, STONE[3])

    # heavy stone wall (lower half), plaster upper
    R(c, bx, by - foot_h - wall_h, bx + bw, by - foot_h, STONE[2])
    R(c, bx, by - foot_h - wall_h, bx + bw, by - foot_h - wall_h // 2, PLAS[2])
    # timber details
    for px in (bx, bx + bw // 2 - 2, bx + bw - 4):
        R(c, px, by - foot_h - wall_h, px + 3, by - foot_h, WOOD[2])
    H(c, bx, bx + bw, by - foot_h - wall_h, WOOD[2])
    H(c, bx, bx + bw, by - foot_h - wall_h // 2, WOOD[2])

    # large open archway (forge bay, left)
    arch_w, arch_h = 70, 100
    ax = bx + 14
    ay = by - foot_h - arch_h
    R(c, ax, ay, ax + arch_w, by - foot_h, STONE[4])
    for dy in range(16):
        half = (arch_w // 2) * (16 - dy) // 16
        R(c, ax + arch_w // 2 - half, ay + dy, ax + arch_w // 2 + half, ay + dy, STONE[3])
    # glowing forge interior
    R(c, ax + 6, ay + 18, ax + arch_w - 6, by - foot_h - 2, rgb(50, 36, 26))
    R(c, ax + 14, by - foot_h - 20, ax + arch_w - 14, by - foot_h - 2, EMBER[2])
    c.disc(ax + arch_w // 2, by - foot_h - 16, 10, EMBER[1])
    c.disc(ax + arch_w // 2, by - foot_h - 18, 5, EMBER[0])

    # door (right side)
    _door(c, bx + bw - 60, by - foot_h - 112, door_h=112, door_w=38)
    # window
    _window(c, bx + bw - 110, by - foot_h - 80, 32, 28)

    # heavy slate roof with overhang
    roof_h = 70
    cx = bx + bw // 2
    for i in range(roof_h):
        half = (bw // 2 + 18) * (roof_h - i) // roof_h
        col = SLATE[1 if i % 4 < 2 else 2]
        R(c, cx - half, by - foot_h - wall_h - roof_h + i,
          cx + half, by - foot_h - wall_h - roof_h + i, col)
    _chimney(c, bx + 50, by - foot_h - wall_h - roof_h - 26, h=34)

    # anvil prop in forge bay
    anv_x = ax + arch_w // 2 - 12
    anv_y = by - foot_h - 28
    R(c, anv_x, anv_y, anv_x + 24, anv_y + 10, META[2])
    R(c, anv_x + 4, anv_y - 6, anv_x + 20, anv_y + 1, META[1])
    R(c, anv_x + 4, anv_y - 6, anv_x + 20, anv_y - 5, META[0])

    c.outline(INK)


def draw_chapel(c):
    """Chapel ~240×420 with bell tower and stained window."""
    bx, by = 2, 418
    bw = 236
    nave_h = 160
    tower_h = 120  # above nave
    foot_h = 16

    R(c, bx, by - foot_h, bx + bw, by, STONE[2])

    # nave walls — worked stone, arched windows
    R(c, bx, by - foot_h - nave_h, bx + bw, by - foot_h, STONE[2])
    R(c, bx, by - foot_h - nave_h, bx + 4, by - foot_h, STONE[1])
    R(c, bx + bw - 4, by - foot_h - nave_h, bx + bw, by - foot_h, STONE[3])
    # stone course lines
    for sy in range(by - foot_h - nave_h, by - foot_h, 16):
        H(c, bx, bx + bw, sy, STONE[3])
    for sx in range(bx, bx + bw, 24):
        V(c, sx, by - foot_h - nave_h, by - foot_h, STONE[3])

    # arched side windows (stained glass feel)
    for wx in (bx + 18, bx + bw - 50):
        ww, wh = 28, 50
        wy = by - foot_h - nave_h + 30
        R(c, wx, wy, wx + ww, wy + wh, rgb(120, 80, 140))  # purple pane
        # arch top
        for dy in range(14):
            half = (ww // 2) * (14 - dy) // 14
            R(c, wx + ww // 2 - half, wy - dy, wx + ww // 2 + half, wy - dy,
              rgb(140, 90, 160))
        R(c, wx - 2, wy - 14, wx + ww + 2, wy + wh + 2, STONE[3])
        V(c, wx + ww // 2, wy - 12, wy + wh, STONE[2])
        H(c, wx, wx + ww, wy + wh // 2, STONE[2])

    # door
    _door(c, bx + bw // 2 - 20, by - foot_h - 112, door_h=112, door_w=40)

    # bell tower (centre, above nave)
    tw = 72
    tx = bx + bw // 2 - tw // 2
    ty = by - foot_h - nave_h - tower_h
    R(c, tx, ty, tx + tw, by - foot_h - nave_h, STONE[2])
    R(c, tx, ty, tx + 4, by - foot_h - nave_h, STONE[1])
    R(c, tx + tw - 4, ty, tx + tw, by - foot_h - nave_h, STONE[3])
    for sy in range(ty, by - foot_h - nave_h, 14):
        H(c, tx, tx + tw, sy, STONE[3])
    # bell openings
    for bello_x in (tx + 6, tx + tw - 26):
        R(c, bello_x, ty + 30, bello_x + 18, ty + 60, rgb(30, 26, 32))
        for dy in range(10):
            half = 9 * (10 - dy) // 10
            R(c, bello_x + 9 - half, ty + 30 - dy, bello_x + 9 + half, ty + 30 - dy,
              STONE[2])
    # bell
    c.disc(tx + tw // 2, ty + 50, 7, META[1])
    c.disc(tx + tw // 2, ty + 50, 4, META[2])
    c.paint(tx + tw // 2, ty + 54, META[3])

    # steep stone spire
    sp_h = 60
    scx = tx + tw // 2
    for i in range(sp_h):
        half = max(1, tw // 2 * (sp_h - i) // sp_h)
        R(c, scx - half, ty - sp_h + i, scx + half, ty - sp_h + i, SLATE[1 if i % 3 < 2 else 2])
    c.paint(scx, ty - sp_h, STONE[0])

    c.outline(INK)


def draw_shop(c):
    """General shop ~200×240 with awning and display window."""
    bx, by = 2, 238
    bw = 196
    wall_h = 110
    foot_h = 14

    R(c, bx, by - foot_h, bx + bw, by, STONE[2])
    _timber_frame(c, bx, by - foot_h - wall_h, bw, wall_h)

    # large display window (left)
    _window(c, bx + 14, by - foot_h - 82, 56, 50)
    # door (right)
    _door(c, bx + bw - 56, by - foot_h - 112, door_h=112, door_w=34)
    # small window right
    _window(c, bx + bw - 106, by - foot_h - 68, 28, 22)

    # awning (striped rust/cream)
    aw_y = by - foot_h - wall_h + 24
    for i in range(bw + 12):
        col = rgb(164, 78, 56) if (i // 8) % 2 == 0 else PLAS[0]
        for dy in range(16):
            drop = int(abs(math.sin(math.pi * i / (bw + 12))) * 8)
            c.paint(bx - 6 + i, aw_y + dy + drop, col)
    H(c, bx - 8, bx + bw + 8, aw_y, WOOD[2])

    # hanging sign
    sx, sy = bx + bw // 2 - 28, by - foot_h - wall_h - 10
    R(c, sx, sy, sx + 56, sy + 18, WOOD[1])
    R(c, sx, sy, sx + 56, sy + 2, WOOD[0])
    V(c, sx + 10, sy - 14, sy, WOOD[2])
    V(c, sx + 46, sy - 14, sy, WOOD[2])

    # slate roof
    roof_h = 50
    cx = bx + bw // 2
    for i in range(roof_h):
        half = (bw // 2 + 8) * (roof_h - i) // roof_h
        col = SLATE[1 if i % 3 < 2 else 2]
        R(c, cx - half, by - foot_h - wall_h - roof_h + i,
          cx + half, by - foot_h - wall_h - roof_h + i, col)
    c.outline(INK)


def draw_well(c):
    """Stone well ~64×72 single prop."""
    cx, base_y = 32, 70
    rw, rh = 24, 12   # well radius x/y

    # shadow
    c.ellipse(cx, base_y + 2, 28, 8, P.SHADOW, fill=True)

    # stone base ring
    for dy in range(16):
        R(c, cx - rw - 2, base_y - dy, cx + rw + 2, base_y - dy,
          STONE[2 if dy % 4 < 2 else 3])
    c.ellipse(cx, base_y - 16, rw + 2, 8, STONE[2], fill=True)
    c.ellipse(cx, base_y - 16, rw, 7, rgb(26, 24, 32), fill=True)  # dark water

    # posts + cross-beam
    V(c, cx - rw - 2, base_y - 38, base_y - 16, WOOD[2])
    V(c, cx + rw + 2, base_y - 38, base_y - 16, WOOD[2])
    R(c, cx - rw - 4, base_y - 42, cx + rw + 4, base_y - 38, WOOD[2])
    R(c, cx - rw - 4, base_y - 44, cx + rw + 4, base_y - 42, WOOD[1])

    # roof (tiny, triangular)
    for i in range(18):
        half = max(1, (rw + 8) * (18 - i) // 18)
        R(c, cx - half, base_y - 58 + i, cx + half, base_y - 58 + i,
          THAT[1 if i % 2 else 2])

    # rope + bucket
    V(c, cx, base_y - 38, base_y - 20, WOOD[3])
    R(c, cx - 5, base_y - 22, cx + 5, base_y - 16, WOOD[2])
    R(c, cx - 5, base_y - 22, cx + 5, base_y - 20, WOOD[1])

    c.outline(INK)


def draw_signpost(c):
    """Signpost ~32×72."""
    cx, base_y = 16, 70
    # post
    R(c, cx - 2, 20, cx + 2, base_y, WOOD[2])
    R(c, cx - 2, 20, cx - 1, base_y, WOOD[1])
    # sign board
    R(c, cx - 14, 18, cx + 18, 38, WOOD[1])
    R(c, cx - 14, 18, cx + 18, 20, WOOD[0])
    H(c, cx - 12, cx + 16, 36, WOOD[3])
    # small arrow shape on sign
    for dy in range(6):
        R(c, cx - 2 - dy, 26 + dy, cx + 8 + dy, 26 + dy, WOOD[3])
    c.outline(INK)


def draw_contract_board(c):
    """Contract board (quest board) ~56×90. Cork board with paper notices."""
    bx, by = 4, 88
    bw = 48

    # legs
    V(c, bx + 8, by - 48, by, WOOD[2])
    V(c, bx + bw - 8, by - 48, by, WOOD[2])
    # board frame
    R(c, bx, by - 88, bx + bw, by - 48, WOOD[2])
    R(c, bx, by - 88, bx + bw, by - 86, WOOD[1])
    R(c, bx, by - 88, bx + 2, by - 48, WOOD[1])
    # cork surface
    R(c, bx + 3, by - 85, bx + bw - 3, by - 51, rgb(180, 144, 100))
    c.mottle(bx + 3, by - 85, bx + bw - 3, by - 51,
             [rgb(180, 144, 100), rgb(162, 128, 88), rgb(148, 116, 78)],
             random.Random(99), scale=4)
    # pinned notices (various paper scraps)
    rnd = random.Random(7)
    for _ in range(5):
        px = rnd.randrange(bx + 5, bx + bw - 14)
        py = rnd.randrange(by - 82, by - 56)
        pw = rnd.randrange(10, 18); ph = rnd.randrange(8, 14)
        tilt = rnd.choice([-1, 0, 1])
        R(c, px + tilt, py, px + pw + tilt, py + ph, PLAS[0])
        H(c, px + 2 + tilt, px + pw - 2 + tilt, py + 3, PLAS[2])
        H(c, px + 2 + tilt, px + pw - 4 + tilt, py + 6, PLAS[2])
        c.paint(px + pw // 2, py - 1, rgb(196, 74, 66))  # pin

    c.outline(INK)


def draw_market_stall(c):
    """Market stall with fabric awning ~140×110."""
    bx, by = 2, 108
    bw = 136

    # counter
    R(c, bx, by - 22, bx + bw, by, WOOD[2])
    R(c, bx, by - 22, bx + bw, by - 20, WOOD[1])
    R(c, bx, by - 4, bx + bw, by, WOOD[3])
    # legs
    for lx in (bx + 4, bx + bw - 6):
        R(c, lx, by - 22, lx + 4, by + 2, WOOD[3])

    # goods on counter (small coloured rectangles = produce/goods)
    rnd = random.Random(5)
    for gx in range(bx + 8, bx + bw - 8, 14):
        gcol = rnd.choice([rgb(220, 140, 60), rgb(100, 148, 70), rgb(196, 80, 60),
                           rgb(200, 170, 80)])
        R(c, gx, by - 32, gx + 10, by - 22, gcol)

    # posts
    for px in (bx + 4, bx + bw - 8):
        V(c, px + 1, by - 80, by - 22, WOOD[2])
        R(c, px, by - 80, px + 3, by - 78, WOOD[1])

    # awning (striped)
    for i in range(bw + 12):
        col = rgb(148, 80, 60) if (i // 10) % 2 == 0 else PLAS[0]
        for dy in range(22):
            drop = int(abs(math.sin(math.pi * i / (bw + 12))) * 10)
            c.paint(bx - 6 + i, by - 80 + dy + drop, col)
    H(c, bx - 8, bx + bw + 8, by - 80, WOOD[2])

    c.outline(INK)


def draw_tent(c):
    """Canvas tent ~120×130."""
    cx, base_y = 60, 128
    tw = 118   # tent width at base

    # ground pegs + ropes
    rnd = random.Random(3)
    for side in (-1, 1):
        px = cx + side * (tw // 2 - 4)
        for ry in range(4): c.paint(px + rnd.randrange(-2, 3), base_y - ry, WOOD[3])
        L(c, px, base_y - 4, cx + side * 18, base_y - 90, rgb(150, 130, 100))

    # tent body (canvas, triangular)
    rnd = random.Random(7)
    for i in range(100):
        half = (tw // 2) * (100 - i) // 100
        col = PLAS[1 if rnd.random() < 0.6 else 2]
        R(c, cx - half, base_y - i, cx + half, base_y - i, col)
    # canvas seam lines / folds
    for fold_x in (-tw // 4, 0, tw // 4):
        L(c, cx + fold_x, base_y, cx, base_y - 100, PLAS[3])
    # ridge / peak
    R(c, cx - 3, base_y - 102, cx + 3, base_y - 98, WOOD[2])

    # door flap (open, showing dark inside)
    flap_w = 30
    R(c, cx - flap_w // 2, base_y - 60, cx + flap_w // 2, base_y, rgb(40, 32, 28))
    R(c, cx - flap_w // 2, base_y - 60, cx - flap_w // 2 + 4, base_y, PLAS[2])
    R(c, cx + flap_w // 2 - 4, base_y - 60, cx + flap_w // 2, base_y, PLAS[2])

    c.outline(INK)


def draw_fence_segment(c):
    """One 40×32 fence segment, seamlessly tileable horizontally."""
    bw = 40
    base_y = 30

    # posts at left and right edges (so tiling works)
    for px in (0, bw - 4):
        R(c, px, 4, px + 3, base_y, WOOD[2])
        R(c, px, 4, px, base_y, WOOD[1])
        c.paint(px + 1, 4, WOOD[1])
    # horizontal rails
    R(c, 0, 14, bw - 1, 17, WOOD[2])
    R(c, 0, 14, bw - 1, 14, WOOD[1])
    R(c, 0, 22, bw - 1, 25, WOOD[2])
    R(c, 0, 22, bw - 1, 22, WOOD[1])
    c.outline(INK)


def draw_lamp_post(c):
    """Iron lamp post ~24×120."""
    cx, base_y = 12, 118
    # base plate
    R(c, cx - 6, base_y - 6, cx + 6, base_y, META[2])
    # pole
    V(c, cx, 30, base_y - 6, META[2])
    V(c, cx - 1, 30, base_y - 6, META[1])
    # scroll bracket
    L(c, cx, 36, cx + 8, 30, META[2])
    # lamp housing
    R(c, cx + 4, 14, cx + 16, 34, META[2])
    R(c, cx + 4, 14, cx + 16, 16, META[1])
    # glass / glow
    R(c, cx + 6, 16, cx + 14, 32, GLASS[1])
    R(c, cx + 6, 16, cx + 14, 20, GLASS[0])
    c.disc(cx + 10, 26, 4, rgb(252, 224, 150, 120))
    c.outline(INK)


# ─────────────────────────────────────────────────────────────────────────────
# NATURE
# ─────────────────────────────────────────────────────────────────────────────

def _tree_canopy(c, cx, cy, spread, clumps, rnd):
    """Draw a layered foliage canopy centred at (cx, cy)."""
    for (ex, ey, rx, ry) in clumps:
        E(c, ex, ey, rx, ry, LEAF[3])
    for (ex, ey, rx, ry) in clumps:
        E(c, ex - rx // 4, ey - ry // 4, rx * 3 // 4, ry * 3 // 4, LEAF[2])
    for (ex, ey, rx, ry) in clumps:
        E(c, ex - rx // 3, ey - ry // 3, rx // 2, ry // 2, LEAF[1])
    # speckle
    for _ in range(90):
        a = rnd.uniform(0, 6.28)
        rr = rnd.uniform(0, spread)
        lx = int(cx + rr * 0.9 * math.cos(a))
        ly = int(cy + rr * 0.7 * math.sin(a))
        c.paint(lx, ly, LEAF[0] if rnd.random() < 0.4 else LEAF[4])


def draw_tree_a(c):
    """Round-crown oak tree ~128×296. Dense, classic silhouette."""
    cx, base_y = 64, 294
    trunk_top = base_y - 230
    # root flare
    R(c, cx - 10, base_y - 6, cx + 9, base_y, BARK[2])
    E(c, cx, base_y, 14, 4, BARK[3])
    # trunk
    R(c, cx - 7, trunk_top, cx + 6, base_y - 6, BARK[2])
    R(c, cx - 7, trunk_top, cx - 5, base_y - 6, BARK[1])
    R(c, cx + 4, trunk_top, cx + 6, base_y - 6, BARK[3])
    rnd = random.Random(1)
    for ry in range(trunk_top, base_y - 6, 8):
        L(c, cx - 6, ry, cx + 5, ry + 3, BARK[3])
    # canopy
    cy = trunk_top - 30
    clumps = [
        (cx, cy, 38, 32),
        (cx - 26, cy + 18, 24, 22),
        (cx + 26, cy + 18, 24, 22),
        (cx - 14, cy - 14, 20, 18),
        (cx + 16, cy - 12, 20, 18),
        (cx, cy + 36, 30, 20),
    ]
    _tree_canopy(c, cx, cy, 38, clumps, rnd)
    c.outline(INK)


def draw_tree_b(c):
    """Tall narrow pine/fir ~100×282. Layered cone silhouette."""
    cx, base_y = 50, 280
    trunk_top = base_y - 240
    # trunk
    R(c, cx - 5, trunk_top, cx + 4, base_y, BARK[2])
    R(c, cx - 5, trunk_top, cx - 3, base_y, BARK[1])
    R(c, cx + 2, trunk_top, cx + 4, base_y, BARK[3])
    rnd = random.Random(2)
    # stacked tier ellipses (pine silhouette)
    tiers = [
        (cx, trunk_top + 10, 36, 12),
        (cx - 2, trunk_top + 32, 44, 14),
        (cx, trunk_top + 58, 48, 16),
        (cx + 2, trunk_top + 86, 44, 14),
        (cx, trunk_top + 114, 38, 12),
        (cx - 2, trunk_top + 140, 28, 10),
    ]
    for (ex, ey, rx, ry) in tiers:
        E(c, ex, ey, rx, ry, LEAF[3])
        E(c, ex - rx // 4, ey - ry // 3, rx * 2 // 3, ry // 2, LEAF[2])
        E(c, ex - rx // 3, ey - ry // 2, rx // 3, ry // 3, LEAF[1])
    for _ in range(70):
        a = rnd.uniform(0, 6.28)
        t = rnd.choice(tiers)
        lx = int(t[0] + rnd.uniform(0, t[2] * 0.9) * math.cos(a))
        ly = int(t[1] + rnd.uniform(0, t[3] * 0.9) * math.sin(a))
        c.paint(lx, ly, LEAF[0] if rnd.random() < 0.3 else LEAF[4])
    # tip
    c.paint(cx, trunk_top - 2, LEAF[1])
    c.outline(INK)


def draw_tree_c(c):
    """Wide spreading deciduous tree ~130×260. Asymmetric canopy."""
    cx, base_y = 65, 258
    trunk_top = base_y - 190
    # trunk + split
    R(c, cx - 8, trunk_top + 20, cx + 7, base_y, BARK[2])
    R(c, cx - 8, trunk_top + 20, cx - 6, base_y, BARK[1])
    R(c, cx + 5, trunk_top + 20, cx + 7, base_y, BARK[3])
    E(c, cx, base_y, 12, 4, BARK[3])
    # split branches
    L(c, cx - 2, trunk_top + 20, cx - 22, trunk_top, BARK[2])
    L(c, cx + 2, trunk_top + 20, cx + 24, trunk_top + 6, BARK[2])
    rnd = random.Random(3)
    # asymmetric canopy — left clump larger
    cy = trunk_top - 12
    clumps = [
        (cx - 22, cy + 4, 34, 28),
        (cx + 24, cy + 10, 28, 24),
        (cx - 6, cy - 10, 26, 22),
        (cx + 8, cy - 4, 22, 18),
        (cx - 30, cy + 26, 20, 16),
        (cx + 32, cy + 28, 18, 14),
    ]
    _tree_canopy(c, cx, cy, 36, clumps, rnd)
    c.outline(INK)


def draw_bush(c):
    """Rounded bush ~56×46."""
    cx, base_y = 28, 44
    E(c, cx, base_y - 18, 24, 18, LEAF[3])
    E(c, cx - 8, base_y - 22, 16, 14, LEAF[2])
    E(c, cx + 10, base_y - 20, 14, 12, LEAF[2])
    E(c, cx - 4, base_y - 28, 12, 10, LEAF[1])
    # berries
    rnd = random.Random(8)
    for _ in range(6):
        bx = rnd.randrange(cx - 18, cx + 18)
        by = rnd.randrange(base_y - 32, base_y - 10)
        if c.opaque(bx, by):
            c.paint(bx, by, rgb(160, 60, 60))
    c.outline(INK)


def draw_rock(c):
    """Mossy boulder ~52×40."""
    cx, base_y = 26, 38
    E(c, cx, base_y - 14, 22, 14, STONE[2])
    E(c, cx - 6, base_y - 18, 14, 10, STONE[1])
    E(c, cx + 8, base_y - 12, 12, 8, STONE[3])
    # moss patches
    c.disc(cx - 12, base_y - 22, 4, LEAF[3])
    c.disc(cx + 14, base_y - 18, 3, LEAF[3])
    c.outline(INK)


def draw_flower(c):
    """Small flower cluster ~28×32."""
    cx, base_y = 14, 30
    # stems
    for fx, fy in [(-4, 0), (0, -2), (5, 1)]:
        V(c, cx + fx, base_y - 14, base_y, LEAF[2])
        c.disc(cx + fx, base_y - 14 + fy, 3, FLOW[0])
        c.paint(cx + fx, base_y - 14 + fy, FLOW[1])
    c.outline(INK)


def draw_stump(c):
    """Tree stump ~40×32."""
    cx, base_y = 20, 30
    E(c, cx, base_y - 4, 18, 5, BARK[3])
    R(c, cx - 14, base_y - 22, cx + 14, base_y - 4, BARK[2])
    R(c, cx - 14, base_y - 22, cx - 12, base_y - 4, BARK[1])
    R(c, cx + 12, base_y - 22, cx + 14, base_y - 4, BARK[3])
    # rings on top
    E(c, cx, base_y - 22, 13, 5, BARK[1])
    E(c, cx, base_y - 22, 7, 3, BARK[2])
    E(c, cx, base_y - 22, 2, 1, BARK[3])
    c.outline(INK)


def draw_log(c):
    """Fallen log ~72×30."""
    cx, base_y = 36, 28
    # cylinder body
    R(c, cx - 32, base_y - 14, cx + 30, base_y, BARK[2])
    R(c, cx - 32, base_y - 14, cx + 30, base_y - 12, BARK[1])
    R(c, cx - 32, base_y - 2, cx + 30, base_y, BARK[3])
    # end caps (ellipses)
    E(c, cx - 32, base_y - 7, 3, 7, BARK[1])
    E(c, cx + 30, base_y - 7, 3, 7, BARK[3])
    E(c, cx + 30, base_y - 7, 2, 5, BARK[1])
    # bark grain
    rnd = random.Random(6)
    for _ in range(12):
        gx = rnd.randrange(cx - 28, cx + 28)
        gy = rnd.randrange(base_y - 12, base_y - 2)
        c.paint(gx, gy, BARK[3])
    c.outline(INK)


# ─────────────────────────────────────────────────────────────────────────────
# GROUND TILES  (32×32 seamless, no alpha)
# ─────────────────────────────────────────────────────────────────────────────

def draw_grass32(c):
    rnd = random.Random(11)
    N = 32
    for y in range(N):
        for x in range(N):
            h = (x * 374761393 + y * 668265263) & 0xFFFF
            t = ((h ^ (h >> 7)) % 7)
            c.paint(x, y, GRASS[1] if t < 3 else GRASS[2])
    for _ in range(26):
        bx = rnd.randrange(2, N - 2); by = rnd.randrange(3, N - 2)
        c.paint(bx, by, GRASS[3])
        c.paint(bx, by - 1, GRASS[0] if rnd.random() < 0.5 else GRASS[1])
    for _ in range(3):
        c.paint(rnd.randrange(3, N - 3), rnd.randrange(3, N - 3),
                FLOW[rnd.randrange(len(FLOW))])


def draw_dirt32(c):
    rnd = random.Random(22)
    c.mottle(0, 0, 31, 31, DIRT, rnd, scale=6)
    # ruts / texture
    for _ in range(18):
        rx = rnd.randrange(1, 30); ry = rnd.randrange(1, 30)
        c.paint(rx, ry, DIRT[0] if rnd.random() < 0.5 else DIRT[3])


def draw_path32(c):
    rnd = random.Random(33)
    for y in range(32):
        for x in range(32):
            t = ((x * 5 + y * 7) % 5)
            c.paint(x, y, PATH[1] if t < 2 else PATH[2])
    for _ in range(14):
        px = rnd.randrange(2, 30); py = rnd.randrange(2, 30)
        c.paint(px, py, PATH[0] if rnd.random() < 0.5 else PATH[3])


def draw_stone32(c):
    rnd = random.Random(44)
    c.mottle(0, 0, 31, 31, STONE, rnd, scale=8)
    # cobble cracks
    for _ in range(12):
        sx = rnd.randrange(2, 30); sy = rnd.randrange(2, 30)
        ex = sx + rnd.randrange(-6, 7); ey = sy + rnd.randrange(-3, 4)
        c.line(sx, sy, max(0, min(31, ex)), max(0, min(31, ey)), STONE[4])


def draw_plaza32(c):
    """Cobblestone plaza tile."""
    rnd = random.Random(55)
    # base mortar
    for y in range(32):
        for x in range(32):
            c.paint(x, y, STONE[3])
    # cobble blocks
    for gy in range(0, 32, 10):
        offset = 5 if (gy // 10) % 2 else 0
        for gx in range(-offset, 32, 10):
            bx = gx + rnd.randrange(-1, 2)
            by = gy + rnd.randrange(-1, 2)
            bw = 8 + rnd.randrange(-1, 2)
            bh = 8 + rnd.randrange(-1, 2)
            col = STONE[1 if rnd.random() < 0.5 else 2]
            c.rect(max(0, bx), max(0, by), min(31, bx + bw), min(31, by + bh), col)
            c.rect(max(0, bx), max(0, by), min(31, bx + bw), max(0, by), STONE[0])
            c.rect(max(0, bx), max(0, by), max(0, bx), min(31, by + bh), STONE[0])


# ─────────────────────────────────────────────────────────────────────────────
# GROUNDCOVER DECALS  (transparent background)
# ─────────────────────────────────────────────────────────────────────────────

def draw_gc_tuft(c):
    """Grass tuft decal ~20×18. Transparent bg."""
    cx, base_y = 10, 16
    rnd = random.Random(1)
    for i in range(7):
        bx = cx + rnd.randrange(-6, 7)
        tilt = rnd.randrange(-2, 3)
        h = rnd.randrange(6, 12)
        col = GRASS[0 if rnd.random() < 0.4 else 1]
        L(c, bx, base_y, bx + tilt, base_y - h, col)
        c.paint(bx + tilt, base_y - h, GRASS[0])


def draw_gc_wildflower(c):
    """Wildflower cluster decal ~24×22."""
    cx, base_y = 12, 20
    rnd = random.Random(2)
    for i in range(4):
        fx = cx + rnd.randrange(-8, 9)
        fy = base_y - rnd.randrange(8, 16)
        V(c, fx, fy + 4, base_y, LEAF[2])
        col = FLOW[rnd.randrange(len(FLOW))]
        c.disc(fx, fy, 2, col)
        c.paint(fx, fy, FLOW[0])


def draw_gc_pebbles(c):
    """Pebble scatter decal ~28×16. Transparent bg."""
    rnd = random.Random(3)
    for _ in range(8):
        px = rnd.randrange(2, 26); py = rnd.randrange(2, 14)
        sz = rnd.randrange(1, 4)
        col = STONE[rnd.randrange(1, 4)]
        c.disc(px, py, sz, col)


def draw_gc_leaves(c):
    """Fallen leaves decal ~30×20. Transparent bg."""
    rnd = random.Random(4)
    cols = [rgb(120, 88, 40), rgb(148, 108, 52), rgb(160, 80, 40), rgb(96, 80, 44)]
    for _ in range(10):
        lx = rnd.randrange(2, 28); ly = rnd.randrange(2, 18)
        c.disc(lx, ly, 2, cols[rnd.randrange(len(cols))])
        c.paint(lx + rnd.randrange(-2, 3), ly + rnd.randrange(-2, 3),
                cols[rnd.randrange(len(cols))])


def draw_gc_moss(c):
    """Moss blotch decal ~32×22. Transparent bg."""
    rnd = random.Random(5)
    cx, cy = 16, 11
    for _ in range(18):
        mx = cx + rnd.randrange(-12, 13); my = cy + rnd.randrange(-8, 9)
        c.disc(mx, my, rnd.randrange(1, 4), LEAF[2 if rnd.random() < 0.5 else 3])


# ─────────────────────────────────────────────────────────────────────────────
# MANIFEST
# ─────────────────────────────────────────────────────────────────────────────
# Each entry: (filename, w, h, anchor_x, anchor_y, draw_fn, notes)
# anchor_x/y: the pixel that lands on the node origin (bottom-centre of base)

SPRITES = [
    # ── Buildings ──────────────────────────────────────────────────────────
    ("cabin.png",          184, 214,  92, 208, draw_cabin,
     "cabin, thatch+timber, door=110px"),
    ("townhouse.png",      200, 264, 100, 258, draw_townhouse,
     "2-storey, slate roof"),
    ("tavern.png",         280, 342, 140, 336, draw_tavern,
     "large, double door, 2-storey"),
    ("blacksmith.png",     260, 322, 130, 316, draw_blacksmith,
     "heavy stone+forge bay, slate roof"),
    ("chapel.png",         240, 422, 120, 416, draw_chapel,
     "bell tower + spire, arched windows"),
    ("shop.png",           200, 244, 100, 238, draw_shop,
     "awning + display window"),
    ("well.png",            64,  76,  32,  74, draw_well,
     "stone well + thatch roof"),
    ("signpost.png",        32,  76,  16,  74, draw_signpost,
     "single signpost"),
    ("contract_board.png",  56,  94,  28,  92, draw_contract_board,
     "cork board with paper notices"),
    ("market_stall.png",   140, 114,  70, 112, draw_market_stall,
     "awning + counter with goods"),
    ("tent.png",           120, 134,  60, 132, draw_tent,
     "canvas tent with open door"),
    ("fence.png",           40,  34,   0,  32, draw_fence_segment,
     "one tileable fence segment; place at left edge"),
    ("lamp_post.png",       24, 122,  12, 120, draw_lamp_post,
     "iron lamp post"),
    # ── Nature ─────────────────────────────────────────────────────────────
    ("tree_a.png",         128, 298,  64, 294, draw_tree_a,
     "round-crown oak, 296px tall"),
    ("tree_b.png",         100, 284,  50, 280, draw_tree_b,
     "narrow pine/fir, tiered canopy"),
    ("tree_c.png",         130, 262,  65, 258, draw_tree_c,
     "wide spreading deciduous, asymmetric"),
    ("bush.png",            56,  48,  28,  46, draw_bush,
     "rounded bush with berries"),
    ("rock.png",            52,  42,  26,  40, draw_rock,
     "mossy boulder"),
    ("flower.png",          28,  34,  14,  32, draw_flower,
     "small wildflower cluster"),
    ("stump.png",           40,  34,  20,  32, draw_stump,
     "tree stump with rings"),
    ("log.png",             72,  32,  36,  30, draw_log,
     "fallen log"),
]

TILES = [
    # Seamless 32×32 — no anchor
    ("grass32.png",  32, 32, draw_grass32),
    ("dirt32.png",   32, 32, draw_dirt32),
    ("path32.png",   32, 32, draw_path32),
    ("stone32.png",  32, 32, draw_stone32),
    ("plaza32.png",  32, 32, draw_plaza32),
]

DECALS = [
    # Transparent-background groundcover decals — no anchor (placed as decals)
    ("gc_tuft.png",        20, 20, draw_gc_tuft),
    ("gc_wildflower.png",  24, 24, draw_gc_wildflower),
    ("gc_pebbles.png",     28, 18, draw_gc_pebbles),
    ("gc_leaves.png",      30, 22, draw_gc_leaves),
    ("gc_moss.png",        32, 24, draw_gc_moss),
]


def main():
    os.makedirs(OUTDIR, exist_ok=True)

    print("=" * 62)
    print("bake_firsthour_world.py  ->  assets/remaster/world/")
    print("=" * 62)

    print("\n--- Buildings & Props ---")
    for name, w, h, ax, ay, fn, note in SPRITES:
        c = Canvas(w, h)
        fn(c)
        path = os.path.join(OUTDIR, name)
        c.save(path)
        print("  %-24s %4dx%-4d  offset=Vector2(%-4d,%-4d)  single  %s"
              % (name, w, h, -ax, -ay, note))

    print("\n--- Ground Tiles (seamless 32x32) ---")
    for name, w, h, fn in TILES:
        c = Canvas(w, h)
        fn(c)
        path = os.path.join(OUTDIR, name)
        c.save(path)
        print("  %-24s %4dx%-4d  tile (no anchor)  seamless" % (name, w, h))

    print("\n--- Groundcover Decals (transparent bg) ---")
    for name, w, h, fn in DECALS:
        c = Canvas(w, h)
        fn(c)
        path = os.path.join(OUTDIR, name)
        c.save(path)
        print("  %-24s %4dx%-4d  decal (no anchor)" % (name, w, h))

    print("\nDone.  All PNGs in", OUTDIR)


if __name__ == "__main__":
    main()
