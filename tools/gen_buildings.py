#!/usr/bin/env python3
"""Buildings for Teramor - true scale, grounded palette, foot-anchored.

The scale rule (CLAUDE.md art bible): a one-story door is ~one character tall
(~40px), so buildings tower over the player. Drawn facade-style (seen slightly
from above), base at the bottom of the canvas. Soft top-left key light, cool
ambient shade, warm window glow for life.

  cabin.png        64x76   the player's log home (enterable)
  townhouse.png    72x88   timber-framed house, half-story gable
  shop.png         72x84   general store, striped awning + display window
  tavern.png       88x96   broad two-story inn with a hanging sign
  blacksmith.png   80x80   stone smithy, open forge bay, chimney smoke
  chapel.png       72x112  temple of Tera: bell tower, spire, stained glass
  market_stall.png 48x44   awning stall with a goods counter
  lamp_post.png    16x48   iron street lamp, warm lantern
  signpost.png     22x34   carved wooden signpost

Run:  python3 tools/gen_buildings.py
"""

import random

from pixelforge import Canvas, P, asset, lerp, shade


# --- shared building parts --------------------------------------------------

def stone_base(c, x0, y0, x1, y1):
    c.rect(x0, y0, x1, y1, P.STONE[2])
    rnd = random.Random(2)
    for sy in range(y0, y1 + 1, 3):              # courses
        c.hline(x0, x1, sy, P.STONE[3])
    for _ in range((x1 - x0) // 2):              # block seams + speckle
        bx = rnd.randint(x0, x1); by = rnd.randint(y0, y1)
        c.paint(bx, by, P.STONE[1] if rnd.random() < 0.5 else P.STONE[3])
    c.hline(x0, x1, y0, P.STONE[1])


def log_wall(c, x0, y0, x1, y1, course=5):
    """Stacked horizontal logs - lit top, shadow underside, log-ends at corners."""
    y = y0
    while y <= y1:
        yb = min(y1, y + course - 1)
        c.rect(x0, y, x1, yb, P.WOOD[2])
        c.hline(x0, x1, y, P.WOOD[1])            # lit top of each log
        c.hline(x0, x1, yb, P.WOOD[3])           # shadow gap
        y += course
    # Corner posts with log-end discs.
    for cx in (x0 + 1, x1 - 1):
        c.vline(cx - 1, y0, y1, P.WOOD[3])
        c.vline(cx, y0, y1, P.WOOD[2])
    y = y0
    while y <= y1:
        for cx in (x0 + 1, x1 - 1):
            c.disc(cx, y + course // 2, 1, P.WOOD[1])
        y += course


def plank_door(c, x0, y0, x1, y1):
    c.rect(x0, y0, x1, y1, P.WOOD[3])
    for px in range(x0, x1 + 1, 3):              # vertical planks
        c.vline(px, y0, y1, P.WOOD[4])
    c.frame(x0, y0, x1, y1, P.WOOD[4])
    c.rect(x0, y0, x1, y0 + 1, P.WOOD[2])        # lintel
    c.paint(x1 - 1, (y0 + y1) // 2, P.METAL[1])  # handle
    for hy in (y0 + 2, y1 - 2):                  # iron hinges
        c.hline(x0, x0 + 2, hy, P.METAL[3])


def glow_window(c, x0, y0, x1, y1, lit=True):
    pane = lerp(P.EMBER[0], P.EMBER[1], 0.4) if lit else P.WATER[2]
    c.rect(x0, y0, x1, y1, pane)
    if lit:
        c.rect(x0, y1 - 1, x1, y1, shade(pane, 0.8))
        c.rect(x0, y0, x1, y0, shade(pane, 1.1))
    cx = (x0 + x1) // 2; cy = (y0 + y1) // 2
    c.vline(cx, y0, y1, P.WOOD[3])               # muntins
    c.hline(x0, x1, cy, P.WOOD[3])
    c.frame(x0 - 1, y0 - 1, x1 + 1, y1 + 1, P.WOOD[4])  # frame


def thatch_roof(c, cx, y_top, half_top, y_bot, half_bot, pal=None):
    """A layered thatch hip roof widening downward, lit upper-left, ragged eave."""
    pal = pal or P.THATCH
    span = max(1, y_bot - y_top)
    rnd = random.Random(8)
    for y in range(y_top, y_bot + 1):
        t = (y - y_top) / span
        half = int(round(half_top + (half_bot - half_top) * t))
        band = (y - y_top) % 4
        col = pal[1] if band < 2 else pal[2]
        if t > 0.82:
            col = pal[3]                          # darker eave shadow
        c.rect(cx - half, y, cx + half, y, col)
        c.paint(cx - half, y, pal[3]); c.paint(cx + half, y, pal[3])
    # Vertical thatch combing.
    for x in range(cx - half_bot, cx + half_bot + 1, 3):
        c.vline(x, y_top + 2, y_bot - 1, shade(pal[2], 0.92))
    # Lit ridge + ragged bottom fringe.
    c.rect(cx - half_top, y_top, cx + half_top, y_top, pal[0])
    for x in range(cx - half_bot, cx + half_bot + 1):
        if rnd.random() < 0.4:
            c.paint(x, y_bot + 1, pal[3])


def shingle_roof(c, cx, y_top, half_top, y_bot, half_bot, pal):
    """Gabled shingle roof widening downward: lit ridge, course shadows, eave."""
    span = max(1, y_bot - y_top)
    for y in range(y_top, y_bot + 1):
        t = (y - y_top) / span
        half = int(round(half_top + (half_bot - half_top) * t))
        col = pal[1] if ((y - y_top) % 2 == 0) else pal[2]
        c.rect(cx - half, y, cx + half, y, col)
        c.paint(cx - half, y, pal[3]); c.paint(cx + half, y, pal[3])
    # Staggered shingle butt-seams every other course.
    for y in range(y_top, y_bot, 2):
        t = (y - y_top) / span
        half = int(round(half_top + (half_bot - half_top) * t))
        off = 2 if ((y - y_top) // 2) % 2 else 0
        x = cx - half + off
        while x <= cx + half:
            c.paint(x, y, pal[3]); c.paint(x, min(y + 1, y_bot), pal[3])
            x += 4
    c.rect(cx - half_top, y_top - 1, cx + half_top, y_top - 1, pal[0])  # lit ridge
    c.rect(cx - half_top, y_top, cx + half_top, y_top, pal[0])
    c.rect(cx - half_bot, y_bot, cx + half_bot, y_bot, pal[3])          # eave shadow


def chimney(c, x0, top=0, h=12):
    c.rect(x0, top, x0 + 5, top + h, P.STONE[2])
    c.hline(x0, x0 + 5, top, P.STONE[1])
    c.rect(x0, top + 1, x0 + 5, top + 2, P.STONE[3])
    for sy in range(top + 4, top + h, 3):
        c.hline(x0, x0 + 5, sy, P.STONE[3])


def beam_h(c, x0, x1, y):
    c.rect(x0, y, x1, y + 1, P.WOOD[3])
    c.hline(x0, x1, y, P.WOOD[2])


def beam_v(c, x, y0, y1):
    c.rect(x, y0, x + 1, y1, P.WOOD[3])
    c.vline(x, y0, y1, P.WOOD[2])


def plaster_wall(c, x0, y0, x1, y1, seed=5):
    c.shade_rect(x0, y0, x1, y1, P.PLASTER[0], P.PLASTER[1], P.PLASTER[2])
    rnd = random.Random(seed)
    for _ in range((x1 - x0) * (y1 - y0) // 24):  # weathering low on the wall
        bx = rnd.randint(x0 + 1, x1 - 1)
        by = rnd.randint((y0 + y1) // 2, y1)
        c.paint(bx, by, P.PLASTER[3])


def hanging_sign(c, x0, y_arm, w, h, emblem=None):
    """A bracket arm with a swinging board hung beneath it."""
    c.hline(x0, x0 + w + 2, y_arm, P.WOOD[4])    # bracket arm
    c.paint(x0, y_arm - 1, P.METAL[3]); c.paint(x0, y_arm + 1, P.METAL[3])
    c.vline(x0 + 1, y_arm, y_arm + 2, P.METAL[3])  # chains
    c.vline(x0 + w, y_arm, y_arm + 2, P.METAL[3])
    c.rect(x0, y_arm + 2, x0 + w, y_arm + 2 + h, P.WOOD[2])  # board
    c.hline(x0, x0 + w, y_arm + 2, P.WOOD[1])
    c.frame(x0, y_arm + 2, x0 + w, y_arm + 2 + h, P.WOOD[4])
    if emblem:
        emblem(c, (2 * x0 + w) // 2, (2 * (y_arm + 2) + h) // 2)


# --- buildings --------------------------------------------------------------

def gen_cabin(name="cabin.png"):
    c = Canvas(64, 76)
    chimney(c, 44)
    thatch_roof(c, 32, 6, 12, 34, 31)
    log_wall(c, 8, 33, 55, 68)
    stone_base(c, 8, 68, 55, 72)
    plank_door(c, 26, 40, 37, 68)
    c.rect(24, 68, 39, 70, P.STONE[1])           # stone step
    glow_window(c, 43, 44, 50, 51)
    c.rect(41, 43, 42, 52, P.WOOD[3]); c.rect(51, 43, 52, 52, P.WOOD[3])  # shutters
    glow_window(c, 14, 44, 21, 51)
    c.rect(12, 43, 13, 52, P.WOOD[3]); c.rect(22, 43, 23, 52, P.WOOD[3])
    c.rim_light(0.3)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(64x76)")


def gen_townhouse(name="townhouse.png"):
    c = Canvas(72, 88)
    chimney(c, 54)
    shingle_roof(c, 36, 4, 8, 32, 35, P.ROOF_SLATE)
    plaster_wall(c, 6, 32, 65, 84)
    stone_base(c, 6, 84, 65, 87)
    # Timber framing.
    beam_v(c, 6, 32, 84); beam_v(c, 64, 32, 84)
    beam_h(c, 6, 65, 32); beam_h(c, 6, 65, 55); beam_h(c, 6, 65, 83)
    beam_v(c, 35, 32, 55)                         # upper central post
    # Gable half-story windows.
    glow_window(c, 16, 38, 23, 46)
    glow_window(c, 48, 38, 55, 46)
    # Ground floor: door + flanking windows.
    plank_door(c, 30, 56, 41, 83)
    c.rect(28, 83, 43, 85, P.STONE[1])            # step
    glow_window(c, 12, 60, 21, 69, lit=False)
    glow_window(c, 50, 60, 59, 69)
    c.rim_light(0.3)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(72x88)")


def gen_shop(name="shop.png"):
    c = Canvas(72, 84)
    chimney(c, 12)
    shingle_roof(c, 36, 4, 9, 28, 35, P.ROOF)
    plaster_wall(c, 6, 28, 65, 80)
    stone_base(c, 6, 80, 65, 83)
    beam_v(c, 6, 28, 80); beam_v(c, 64, 28, 80)
    beam_h(c, 6, 65, 28); beam_h(c, 6, 65, 79)
    # Signboard above the awning.
    c.rect(20, 31, 51, 39, P.WOOD[2]); c.frame(20, 31, 51, 39, P.WOOD[4])
    c.hline(20, 51, 31, P.WOOD[1])
    for sx in range(24, 48, 3):                   # faint painted lettering
        c.paint(sx, 35, P.WOOD[4])
    # Striped awning over the shopfront.
    awn = 50
    for x in range(8, 64):
        col = P.ROOF[1] if ((x // 5) % 2 == 0) else P.PLASTER[0]
        c.vline(x, awn, awn + 6, col)
    c.hline(8, 63, awn, P.PLASTER[0])
    for x in range(8, 64, 5):                     # scalloped lip
        c.rect(x, awn + 6, x + 2, awn + 7, P.ROOF[2])
    # Big display window (left) + door (right).
    glow_window(c, 11, 60, 30, 74)
    c.vline(20, 60, 74, P.WOOD[3])                # extra mullion
    plank_door(c, 42, 58, 53, 80)
    c.rim_light(0.3)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(72x84)")


def gen_tavern(name="tavern.png"):
    c = Canvas(88, 96)
    chimney(c, 16); chimney(c, 66)
    thatch_roof(c, 44, 6, 14, 40, 43)
    plaster_wall(c, 10, 40, 78, 92)
    stone_base(c, 10, 92, 78, 95)
    # Two-story timber framing.
    beam_v(c, 10, 40, 92); beam_v(c, 77, 40, 92)
    beam_v(c, 32, 40, 92); beam_v(c, 56, 40, 92)
    beam_h(c, 10, 78, 40); beam_h(c, 10, 78, 66); beam_h(c, 10, 78, 91)
    c.line(12, 90, 30, 68, P.WOOD[3]); c.line(58, 68, 76, 90, P.WOOD[3])  # braces
    # Upper windows (3).
    glow_window(c, 16, 48, 25, 58)
    glow_window(c, 40, 48, 49, 58)
    glow_window(c, 63, 48, 72, 58)
    # Ground: central double door + flanking windows.
    plank_door(c, 38, 72, 50, 92)
    c.vline(44, 72, 92, P.WOOD[4])                # double-door split
    glow_window(c, 16, 76, 26, 88)
    glow_window(c, 62, 76, 72, 88)

    def mug(cc, mx, my):
        cc.rect(mx - 2, my - 2, mx + 1, my + 2, P.METAL[1])
        cc.rect(mx - 2, my - 2, mx + 1, my - 1, P.PLASTER[0])   # foam head
        cc.vline(mx + 2, my - 1, my + 1, P.METAL[2])            # handle
    hanging_sign(c, 1, 48, 10, 12, emblem=mug)
    c.rim_light(0.3)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(88x96)")


def gen_blacksmith(name="blacksmith.png"):
    c = Canvas(80, 80)
    # Big stone chimney (right) with an ember crown + smoke.
    c.rect(60, 0, 72, 30, P.STONE[2])
    c.hline(60, 72, 0, P.STONE[1])
    for sy in range(3, 30, 4):
        c.hline(60, 72, sy, P.STONE[3])
    c.rect(61, 1, 71, 4, P.EMBER[2]); c.rect(63, 1, 69, 2, P.EMBER[1])
    for i, (sx, sy) in enumerate([(66, 6), (64, 4), (67, 2), (65, 0)]):
        c.paint(sx, sy, (150, 150, 158, 200 - i * 36))
    # Roof over the main hall (left of the chimney).
    shingle_roof(c, 30, 6, 8, 28, 30, P.ROOF_SLATE)
    # Stone walls.
    c.shade_rect(2, 28, 58, 76, P.STONE[1], P.STONE[2], P.STONE[3])
    for sy in range(31, 76, 5):                   # courses
        c.hline(3, 57, sy, P.STONE[3])
    stone_base(c, 2, 74, 58, 76)
    # Open forge bay (arched) with ember glow + an anvil silhouette.
    c.rect(8, 41, 30, 70, P.STONE[4])
    c.hline(8, 30, 40, P.STONE[3])                # arch lintel
    c.rect(10, 44, 28, 69, (40, 24, 18, 255))     # dark interior
    c.shade_rect(12, 52, 26, 68, P.EMBER[0], P.EMBER[1], P.EMBER[2])  # forge fire
    c.rect(13, 64, 25, 68, P.STONE[4])            # hearth base
    c.rect(16, 60, 22, 64, P.METAL[4])            # anvil body
    c.rect(18, 58, 20, 60, P.METAL[4])            # anvil horn
    # Timber door (right of the bay).
    plank_door(c, 38, 50, 49, 73)

    def shoe(cc, mx, my):                          # horseshoe emblem
        cc.ellipse(mx, my, 3, 3, P.METAL[2], fill=False)
        cc.rect(mx - 3, my + 2, mx + 3, my + 3, (0, 0, 0, 0))
        cc.paint(mx - 3, my + 2, P.METAL[2]); cc.paint(mx + 3, my + 2, P.METAL[2])
    hanging_sign(c, 50, 32, 10, 10, emblem=shoe)
    c.rim_light(0.3)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(80x80)")


def gen_chapel(name="chapel.png"):
    c = Canvas(72, 112)
    GOLD = (236, 206, 96, 255)
    # Bell tower (centered), rising tall.
    plaster_wall(c, 26, 16, 45, 60)
    # Spire.
    for y in range(2, 16):
        t = (y - 2) / 14
        hw = int(1 + 9 * t)
        col = P.ROOF_SLATE[1] if y % 2 == 0 else P.ROOF_SLATE[2]
        c.rect(36 - hw, y, 36 + hw, y, col)
        c.paint(36 - hw, y, P.ROOF_SLATE[3]); c.paint(36 + hw, y, P.ROOF_SLATE[3])
    c.paint(36, 0, GOLD); c.paint(36, 1, GOLD)    # finial
    # Belfry arch with a bell.
    c.rect(31, 22, 40, 34, P.STONE[4]); c.hline(31, 40, 22, P.STONE[3])
    c.rect(34, 26, 37, 32, P.METAL[2]); c.paint(35, 33, P.METAL[3]); c.paint(36, 33, P.METAL[3])
    # Sun-of-Tera emblem.
    c.disc(36, 44, 2, GOLD)
    for (dx, dy) in [(-4, 0), (4, 0), (0, -4), (0, 4), (3, 3), (-3, -3), (3, -3), (-3, 3)]:
        c.paint(36 + dx, 44 + dy, GOLD)
    # Nave walls (wide).
    plaster_wall(c, 6, 60, 65, 108)
    stone_base(c, 6, 108, 65, 111)
    # Short slate roofs flanking the tower, sloping down to the nave.
    shingle_roof(c, 16, 52, 4, 60, 16, P.ROOF_SLATE)
    shingle_roof(c, 56, 52, 4, 60, 16, P.ROOF_SLATE)
    # Big arched stained-glass window (center, below the tower).
    c.rect(28, 66, 43, 88, P.ROOF_SLATE[3])
    c.rect(29, 68, 42, 87, P.WATER[2]); c.rect(29, 67, 42, 68, P.WATER[3])
    c.rect(30, 70, 33, 86, (150, 60, 56, 255))    # red pane
    c.rect(38, 70, 41, 86, (60, 80, 150, 255))    # blue pane
    c.rect(34, 74, 37, 82, GOLD)                  # gold center
    c.vline(35, 67, 87, P.STONE[3]); c.hline(29, 42, 78, P.STONE[3])  # mullions
    # Flanking lancet windows.
    for wx in (12, 52):
        c.rect(wx, 74, wx + 6, 92, P.WATER[2]); c.rect(wx, 72, wx + 6, 74, P.WATER[3])
        c.vline(wx + 3, 72, 92, P.STONE[3]); c.frame(wx - 1, 72, wx + 7, 92, P.STONE[3])
    # Arched double door.
    plank_door(c, 27, 92, 44, 108)
    c.vline(35, 92, 108, P.WOOD[4]); c.rect(28, 90, 43, 92, P.WOOD[2])
    c.rim_light(0.3)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(72x112)")


def gen_market_stall(name="market_stall.png"):
    c = Canvas(48, 44)
    # Posts.
    c.rect(4, 12, 6, 40, P.WOOD[2]); c.vline(4, 12, 40, P.WOOD[1])
    c.rect(41, 12, 43, 40, P.WOOD[2]); c.vline(43, 12, 40, P.WOOD[3])
    # Shadowed interior backboard.
    c.rect(7, 14, 40, 30, P.WOOD[3]); c.rect(7, 14, 40, 16, P.WOOD[4])
    # Counter.
    c.shade_rect(3, 30, 44, 38, P.WOOD[1], P.WOOD[2], P.WOOD[3])
    c.hline(3, 44, 30, P.WOOD[0])
    # Produce on the counter.
    goods = [(9, (150, 60, 56)), (14, (214, 150, 70)), (19, (96, 140, 72)),
             (24, (150, 60, 56)), (29, (206, 192, 120)), (34, (120, 92, 150))]
    for gx, col in goods:
        c.rect(gx, 25, gx + 3, 29, col)
        c.paint(gx, 25, tuple(min(255, v + 40) for v in col[:3]))
    # Striped awning.
    for x in range(2, 46):
        col = P.ROOF[1] if ((x // 4) % 2 == 0) else P.PLASTER[0]
        c.vline(x, 2, 12, col)
    c.hline(2, 45, 2, P.PLASTER[0])
    for x in range(2, 46, 4):                     # scalloped lip
        c.rect(x, 12, x + 1, 13, P.ROOF[2])
    c.rim_light(0.3)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(48x44)")


def gen_lamp_post(name="lamp_post.png"):
    c = Canvas(16, 48)
    c.rect(4, 43, 11, 46, P.METAL[3]); c.rect(5, 44, 10, 45, P.METAL[2])  # base
    c.rect(7, 14, 8, 44, P.METAL[3]); c.vline(7, 14, 44, P.METAL[2])      # post
    c.rect(4, 6, 11, 16, P.METAL[4]); c.frame(4, 6, 11, 16, P.METAL[3])   # lantern frame
    c.shade_rect(5, 8, 10, 14, P.EMBER[0], P.EMBER[1], P.EMBER[2])        # warm glass
    c.paint(7, 10, (255, 244, 200, 255)); c.paint(8, 10, (255, 244, 200, 255))
    c.rect(5, 4, 10, 5, P.METAL[3])               # cap
    c.paint(7, 2, P.METAL[2]); c.paint(8, 2, P.METAL[2]); c.paint(7, 1, P.METAL[3])
    c.rim_light(0.3)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(16x48)")


def gen_signpost(name="signpost.png"):
    c = Canvas(22, 34)
    # Post.
    c.rect(10, 8, 12, 32, P.WOOD[2])
    c.vline(10, 8, 32, P.WOOD[1]); c.vline(12, 8, 32, P.WOOD[3])
    # Main board (points right).
    c.rect(2, 8, 19, 16, P.WOOD[2]); c.frame(2, 8, 19, 16, P.WOOD[4])
    c.hline(2, 19, 8, P.WOOD[1])
    c.paint(20, 11, P.WOOD[2]); c.paint(20, 12, P.WOOD[2]); c.paint(20, 13, P.WOOD[4])
    for ly in (11, 13):                           # faint carved text
        c.hline(5, 15, ly, P.WOOD[4])
    # Small lower board (points left).
    c.rect(4, 20, 17, 27, P.WOOD[3]); c.frame(4, 20, 17, 27, P.WOOD[4])
    c.hline(7, 14, 23, P.WOOD[4])
    c.rim_light(0.3)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(22x34)")


def main():
    gen_cabin()
    gen_townhouse()
    gen_shop()
    gen_tavern()
    gen_blacksmith()
    gen_chapel()
    gen_market_stall()
    gen_lamp_post()
    gen_signpost()


if __name__ == "__main__":
    main()
