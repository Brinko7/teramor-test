#!/usr/bin/env python3
"""Cabin interior for Teramor - a furnished one-room home, foot-anchored.

Bakes the room backdrop (log back wall + plank floor + window + door) plus the
furniture set the home needs to stop feeling like a tent: hearth, table, chairs,
bookshelf, cupboard, rug. Lighting (warm CanvasModulate + a flickering hearth
light + a cool window shaft) is wired in the .tscn; the art here stays neutral-
warm so the lights can do the mood. Grounded palette, top-left key light.

Run:  python3 tools/gen_interior.py
"""
import math
import random

from pixelforge import Canvas, P, asset, lerp, shade, rgb

# --- room geometry (must match cabin_interior.tscn) -------------------------
# A cozy great-room. The .tscn zooms the interior camera 2x, so this 320x224
# room (20x14 tiles) fills the 480x270 viewport crisply with a gentle pan.
ROOM_W, ROOM_H = 320, 224
WALL_TOP = 44          # back-wall band: y 0..43
WALL_SIDE = 12         # side-wall strips: x 0..11 and 308..319
FLOOR_Y0 = WALL_TOP    # floor starts under the back wall
DOOR_X0, DOOR_X1 = 147, 173   # back-wall doorway (exit)


# --- shared painters --------------------------------------------------------

def log_courses(c, x0, y0, x1, y1, rnd, course=13):
    """Stacked horizontal logs (the back wall). Each log is a lit cylinder."""
    y = y0
    while y <= y1:
        yy = min(y + course - 1, y1)
        c.v_gradient(x0, y, x1, yy, shade(P.WOOD[1], 1.12), shade(P.WOOD[3], 0.92))
        c.hline(x0, x1, y, shade(P.WOOD[0], 1.12))        # top highlight
        c.hline(x0, x1, yy, shade(P.WOOD[4], 0.92))       # seam shadow
        for _ in range(max(1, (x1 - x0) // 46)):          # knots
            kx = rnd.randint(x0 + 4, x1 - 4)
            ky = (y + yy) // 2
            c.disc(kx, ky, 1, shade(P.WOOD[3], 0.85))
            c.paint(kx, ky - 1, shade(P.WOOD[1], 1.05))
        y += course


def plank_floor(c, x0, y0, x1, y1, rnd, board_h=11):
    """Weathered-grey floorboards (cool, to read distinct from the warm wall):
    alternating tone, grain, staggered butt-joints."""
    base = P.WOOD_GREY
    y = y0
    row = 0
    while y <= y1:
        yy = min(y + board_h - 1, y1)
        tone = base[1] if row % 2 == 0 else shade(base[1], 0.9)
        c.rect(x0, y, x1, yy, tone)
        c.hline(x0, x1, y, shade(tone, 1.1))              # board top catch-light
        c.hline(x0, x1, yy, shade(base[3], 0.9))          # groove shadow
        for gx in range(x0, x1):                          # grain streaks
            if rnd.random() < 0.05:
                gl = min(yy - 1, y + rnd.randint(2, board_h - 2))
                c.vline(gx, y + 1, gl, shade(tone, 0.9))
        off = (row * 67) % 130                            # sparse butt-joints
        bx = x0 + off
        while bx < x1:
            c.vline(bx, y, yy, shade(base[4], 0.95))
            c.vline(bx + 1, y, yy, shade(tone, 1.05))
            bx += 132
        y += board_h
        row += 1


def plank_door(c, x0, y0, x1, y1):
    """A heavy plank door set in the back wall (the exit)."""
    c.rect(x0 - 3, y0 - 3, x1 + 3, y1, P.WOOD[4])         # frame
    c.shade_rect(x0, y0, x1, y1, shade(P.WOOD[2], 1.05), P.WOOD[3], P.WOOD[4])
    n = max(2, (x1 - x0) // 9)
    pw = (x1 - x0) / n
    for i in range(1, n):                                 # plank seams
        px = int(x0 + i * pw)
        c.vline(px, y0 + 1, y1 - 1, shade(P.WOOD[4], 0.9))
        c.vline(px + 1, y0 + 1, y1 - 1, shade(P.WOOD[2], 1.08))
    for by in (y0 + 6, y1 - 7):                           # iron cross-braces
        c.rect(x0 + 2, by, x1 - 2, by + 2, P.METAL[3])
        c.hline(x0 + 2, x1 - 2, by, P.METAL[1])
    c.disc(x1 - 6, (y0 + y1) // 2, 2, P.METAL[2])         # ring handle
    c.disc(x1 - 6, (y0 + y1) // 2, 1, rgb(20, 16, 18))


def window(c, x0, y0, x1, y1):
    """A glazed window on the back wall - cool daylight behind muntins."""
    c.rect(x0 - 4, y0 - 4, x1 + 4, y1 + 4, P.WOOD[3])     # outer frame
    c.frame(x0 - 4, y0 - 4, x1 + 4, y1 + 4, P.WOOD[4])
    c.frame(x0 - 1, y0 - 1, x1 + 1, y1 + 1, shade(P.WOOD[1], 1.05))
    c.v_gradient(x0, y0, x1, y1, rgb(168, 186, 196), rgb(96, 122, 138))
    span = y1 - y0
    for d in range(3, x1 - x0, 7):                         # faint sheen (clipped)
        for k in range(min(d, span) + 1):
            px, py = x0 + d - k, y0 + k
            if x0 <= px <= x1 and y0 <= py <= y1:
                c.over(px, py, rgb(212, 226, 232, 55))
    mx = (x0 + x1) // 2
    my = (y0 + y1) // 2
    c.vline(mx, y0, y1, P.WOOD[3])                         # muntins
    c.hline(x0, x1, my, P.WOOD[3])
    c.vline(mx + 1, y0, y1, shade(P.WOOD[1], 1.0))
    c.rect(x0 - 5, y1 + 4, x1 + 5, y1 + 6, P.WOOD[2])      # sill


def wall_shelf(c, x0, y, w):
    """A little peg shelf with jars - decor on the back wall."""
    c.rect(x0, y, x0 + w, y + 2, P.WOOD[3])
    c.hline(x0, x0 + w, y, shade(P.WOOD[1], 1.1))
    c.rect(x0 - 1, y + 2, x0 - 1, y + 4, P.WOOD[4])
    c.rect(x0 + w + 1, y + 2, x0 + w + 1, y + 4, P.WOOD[4])
    jars = [P.WATER[2], P.FOLIAGE[2], P.LEATHER[2], P.CLOTH[1]]
    jx = x0 + 3
    for j in jars:
        if jx + 5 > x0 + w:
            break
        c.rect(jx, y - 6, jx + 4, y - 1, j)
        c.hline(jx, jx + 4, y - 6, shade(j, 1.2))
        c.rect(jx + 1, y - 8, jx + 3, y - 7, P.WOOD[3])   # cork
        jx += 9


def goods_shelf(c, x0, y, w):
    """A back-wall shelf stocked with merchant wares: sacks, bottles, a wheel."""
    c.rect(x0, y, x0 + w, y + 2, P.WOOD[3])               # board
    c.hline(x0, x0 + w, y, shade(P.WOOD[1], 1.1))
    c.rect(x0 - 1, y + 2, x0 - 1, y + 5, P.WOOD[4])       # brackets
    c.rect(x0 + w + 1, y + 2, x0 + w + 1, y + 5, P.WOOD[4])
    x = x0 + 2
    for sc in (P.LEATHER[2], P.CLOTH[2]):                 # tied sacks
        c.rect(x, y - 5, x + 6, y - 1, sc)
        c.disc(x + 3, y - 5, 3, sc)
        c.hline(x + 1, x + 5, y - 7, shade(sc, 0.85))     # cinched neck
        c.paint(x + 3, y - 8, P.WOOD[3])
        x += 9
    for bc in (P.WATER[2], P.FOLIAGE[2], P.WATER[1]):     # bottles
        c.rect(x, y - 8, x + 2, y - 1, bc)
        c.hline(x, x + 2, y - 8, shade(bc, 1.25))
        c.paint(x + 1, y - 10, P.WOOD[3])                 # cork
        x += 5
    if x + 7 <= x0 + w:                                   # a wheel of cheese
        c.disc(x + 3, y - 3, 3, rgb(214, 186, 98))
        c.ellipse(x + 3, y - 3, 3, 3, rgb(176, 146, 78), False)
        c.paint(x + 3, y - 4, rgb(236, 214, 150))


def keg_rack(c, x0, y, w):
    """An A-frame rack of two kegs - the tavern bar-back."""
    c.shade_rect(x0, y - 16, x0 + 2, y + 4,
                 shade(P.WOOD[1], 1.05), P.WOOD[3], P.WOOD[4])   # uprights
    c.shade_rect(x0 + w - 2, y - 16, x0 + w, y + 4,
                 shade(P.WOOD[1], 1.05), P.WOOD[3], P.WOOD[4])
    c.rect(x0, y + 3, x0 + w, y + 4, P.WOOD[4])           # base rail
    for i, ky in enumerate((y - 12, y - 1)):              # two stacked kegs
        kx0, kx1 = x0 + 4, x0 + w - 4
        c.v_gradient(kx0, ky - 6, kx1, ky, shade(P.WOOD[1], 1.1),
                     shade(P.WOOD[3], 0.95))
        c.ellipse(kx0, ky - 3, 2, 3, P.WOOD[4], True)     # end hoops
        c.ellipse(kx1, ky - 3, 2, 3, P.WOOD[4], True)
        for hx in (kx0 + (kx1 - kx0) // 3, kx0 + 2 * (kx1 - kx0) // 3):
            c.vline(hx, ky - 6, ky, P.METAL[3])           # iron hoops
        if i == 1:
            c.rect((kx0 + kx1) // 2, ky + 1, (kx0 + kx1) // 2, ky + 3, P.METAL[2])  # tap


def hanging_tankards(c, x0, y):
    """A beam of pewter tankards hung over the bar."""
    c.rect(x0, y, x0 + 44, y + 1, P.WOOD[4])              # beam
    c.hline(x0, x0 + 44, y, shade(P.WOOD[1], 1.05))
    for i in range(4):
        tx = x0 + 5 + i * 11
        c.rect(tx, y + 1, tx, y + 3, P.METAL[3])          # hook
        c.shade_rect(tx - 2, y + 3, tx + 3, y + 9,
                     shade(P.METAL[1], 1.1), P.METAL[2], P.METAL[3])  # tankard
        c.rect(tx + 3, y + 4, tx + 4, y + 7, P.METAL[2])  # handle


# --- the room backdrop ------------------------------------------------------

def gen_room(name="cabin_room.png", decor="cabin"):
    c = Canvas(ROOM_W, ROOM_H)
    rnd = random.Random(41)

    # floor (full, then walls paint over the margins)
    plank_floor(c, 0, FLOOR_Y0, ROOM_W - 1, ROOM_H - 1, rnd)

    # back wall
    log_courses(c, 0, 0, ROOM_W - 1, WALL_TOP - 3, rnd)
    # baseboard timber between wall and floor
    c.shade_rect(0, WALL_TOP - 3, ROOM_W - 1, WALL_TOP - 1,
                 shade(P.WOOD[1], 1.05), P.WOOD[3], P.WOOD[4])

    # side walls (in shadow), with a soft inner ambient-occlusion edge
    c.v_gradient(0, 0, WALL_SIDE, ROOM_H - 1, P.WOOD[3], P.WOOD[4])
    c.v_gradient(ROOM_W - 1 - WALL_SIDE, 0, ROOM_W - 1, ROOM_H - 1,
                 P.WOOD[3], P.WOOD[4])
    for y in range(0, ROOM_H, 13):                        # log-end seams
        c.hline(0, WALL_SIDE, y, shade(P.WOOD[4], 0.9))
        c.hline(ROOM_W - 1 - WALL_SIDE, ROOM_W - 1, y, shade(P.WOOD[4], 0.9))
    for x in range(WALL_SIDE + 1, WALL_SIDE + 5):         # AO into the room
        a = 150 - (x - WALL_SIDE) * 30
        c.rect_over(x, WALL_TOP, x, ROOM_H - 1, rgb(20, 16, 22, max(0, a)))
        rx = ROOM_W - 1 - x
        c.rect_over(rx, WALL_TOP, rx, ROOM_H - 1, rgb(20, 16, 22, max(0, a)))
    for y in range(WALL_TOP, WALL_TOP + 5):               # AO under back wall
        a = 150 - (y - WALL_TOP) * 30
        c.rect_over(WALL_SIDE + 1, y, ROOM_W - 2 - WALL_SIDE, y,
                    rgb(20, 16, 22, max(0, a)))

    # features on the back wall (door + window are shared; decor varies)
    plank_door(c, DOOR_X0, 4, DOOR_X1, WALL_TOP - 2)
    window(c, 38, 10, 70, 34)
    if decor == "shop":
        goods_shelf(c, 90, 16, 52)
        goods_shelf(c, 198, 20, 56)
        wall_shelf(c, 198, 36, 56)
    elif decor == "tavern":
        hanging_tankards(c, 92, 6)
        keg_rack(c, 204, 26, 46)
    else:  # cabin
        wall_shelf(c, 222, 22, 40)
        # a hanging cloak on pegs, right of the door
        c.rect(190, 5, 191, 8, P.WOOD[4])
        c.rect(186, 8, 196, 30, P.CLOTH[2])
        c.rect(186, 8, 187, 30, shade(P.CLOTH[1], 1.1))
        c.line(191, 8, 191, 30, shade(P.CLOTH[3], 0.95))

    c.save(asset(name))
    return name


# --- a soft radial light texture for PointLight2D ---------------------------

def gen_light(name="light_soft.png", size=256):
    c = Canvas(size, size)
    cx = cy = size / 2.0
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            dx = (x + 0.5 - cx) / r
            dy = (y + 0.5 - cy) / r
            d = math.sqrt(dx * dx + dy * dy)
            if d >= 1.0:
                continue
            a = (1.0 - d)
            a = a * a                       # smooth quadratic falloff
            v = int(255 * a)
            c.paint(x, y, rgb(v, v, v, v))  # fade rgb AND alpha
    c.save(asset(name))
    return name


# --- furniture (foot-anchored: contact row == BASE, offset = (-w//2, -BASE)) -

def _ground(c, soft=True):
    c.outline(P.OUTLINE_SOFT if soft else P.OUTLINE)
    c.drop_shadow()


def gen_hearth(name="hearth.png"):
    """Signature piece: a stone fireplace with a live fire (warm glow baked)."""
    W, H = 56, 62
    c = Canvas(W, H)
    rnd = random.Random(11)
    bx0, by0, bx1, by1 = 5, 8, 50, 58
    # chimney breast tapering up behind the body
    c.shade_rect(16, 0, 39, 9, shade(P.STONE[1], 1.05), P.STONE[2], P.STONE[3])
    # stone body
    c.mottle(bx0, by0, bx1, by1, P.STONE, rnd, scale=3)
    for yy in range(by0 + 7, by1, 9):                     # mortar courses
        c.hline(bx0, bx1, yy, shade(P.STONE[4], 0.95))
        c.hline(bx0, bx1, yy + 1, shade(P.STONE[0], 1.05))
    c.rect(bx0, by0, bx1, by0, shade(P.STONE[0], 1.12))   # bevel
    c.rect(bx0, by0, bx0, by1, shade(P.STONE[0], 1.06))
    c.rect(bx1, by0, bx1, by1, P.STONE[4])
    # timber mantel
    c.shade_rect(1, by0 - 3, 54, by0 + 3,
                 shade(P.WOOD[1], 1.12), P.WOOD[2], P.WOOD[4])
    # firebox (arched opening)
    fx0, fy0, fx1, fy1 = 17, 24, 38, 53
    dark = rgb(22, 16, 18)
    c.rect(fx0, fy0, fx1, fy1, dark)
    c.ellipse((fx0 + fx1) // 2, fy0 + 1, (fx1 - fx0) // 2, 5, dark, True)
    c.frame(fx0 - 1, fy0 - 1, fx1 + 1, fy1 + 1, P.STONE[4])
    # back-wall ember glow inside the box (dark low -> bright at the coals)
    for i, co in enumerate((P.EMBER[3], P.EMBER[2], P.EMBER[1])):
        yy = fy1 - 2 - i * 3
        c.rect_over(fx0 + 1 + i, yy, fx1 - 1 - i, yy + 2, rgb(co[0], co[1], co[2], 150))
    # logs + coals
    c.rect(fx0 + 1, fy1 - 4, fx1 - 1, fy1 - 1, P.EMBER[3])
    c.line(fx0 + 2, fy1 - 2, fx1 - 2, fy1 - 5, P.WOOD[4])
    c.line(fx0 + 2, fy1 - 4, fx1 - 2, fy1 - 1, P.WOOD[3])
    for _ in range(10):                                   # glowing coals
        gx = rnd.randint(fx0 + 2, fx1 - 2)
        c.paint(gx, fy1 - 1, P.EMBER[rnd.randint(0, 1)])
    # flames
    cx = (fx0 + fx1) // 2
    for fxo, h, co in ((-5, 8, P.EMBER[2]), (0, 13, P.EMBER[1]),
                       (5, 9, P.EMBER[2]), (0, 6, P.EMBER[0])):
        bx = cx + fxo
        for k in range(h):
            wv = max(1, (h - k) // 3)
            yy = fy1 - 4 - k
            c.rect_over(bx - wv, yy, bx + wv, yy, co)
    c.disc(cx, fy1 - 11, 2, P.EMBER[0])                   # hot core
    _ground(c)
    # warm light spill over the stone (after outline so it isn't ringed)
    for ry, ra in ((0, 70), (6, 48), (12, 28)):
        c.ellipse(cx, fy0 + 8, 16 - ry // 2, 12 - ry // 3,
                  rgb(255, 180, 90, ra), True)
    c.save(asset(name))
    return name


def gen_table(name="table.png"):
    """Round-ish wooden table with a couple of objects on top."""
    W, H = 50, 38
    c = Canvas(W, H)
    cx = W // 2
    # legs
    for lx in (8, W - 9):
        c.shade_rect(lx - 1, 22, lx + 1, 33, shade(P.WOOD[1], 1.05),
                     P.WOOD[3], P.WOOD[4])
    # apron
    c.shade_rect(6, 18, W - 7, 23, shade(P.WOOD[2], 1.05), P.WOOD[3], P.WOOD[4])
    # top (elliptical), planked
    c.ellipse(cx, 14, cx - 3, 9, P.WOOD[2], True)
    c.ellipse(cx, 14, cx - 3, 9, P.WOOD[4], False)
    c.ellipse(cx, 13, cx - 5, 7, shade(P.WOOD[1], 1.08), True)
    for px in range(10, W - 9, 7):
        c.line(px, 7, px, 21, shade(P.WOOD[3], 0.95))
    c.ellipse(cx, 12, cx - 6, 5, rgb(255, 240, 210, 40), True)  # sheen
    # a bowl + a candle on the table
    c.disc(cx - 9, 13, 4, P.METAL[2])
    c.disc(cx - 9, 12, 3, shade(P.METAL[1], 1.1))
    c.rect(cx - 10, 9, cx - 8, 12, P.FOLIAGE[2])               # fruit in bowl
    c.rect(cx + 7, 6, cx + 8, 13, P.CLOTH[0])                  # candle
    c.disc(cx + 7, 5, 1, P.EMBER[0])
    c.paint(cx + 7, 4, P.EMBER[1])
    _ground(c)
    c.save(asset(name))
    return name


def gen_chair(name="chair.png"):
    W, H = 18, 30
    c = Canvas(W, H)
    # back posts + slats
    c.shade_rect(3, 2, 5, 20, shade(P.WOOD[1], 1.05), P.WOOD[3], P.WOOD[4])
    c.shade_rect(W - 6, 2, W - 4, 20, shade(P.WOOD[1], 1.05), P.WOOD[3], P.WOOD[4])
    for sy in (5, 9):
        c.rect(5, sy, W - 6, sy + 1, P.WOOD[3])
        c.hline(5, W - 6, sy, shade(P.WOOD[1], 1.1))
    # seat
    c.shade_rect(2, 16, W - 3, 21, shade(P.WOOD[1], 1.08), P.WOOD[2], P.WOOD[4])
    # front legs
    for lx in (4, W - 5):
        c.shade_rect(lx - 1, 21, lx + 1, 28, shade(P.WOOD[2], 1.05),
                     P.WOOD[3], P.WOOD[4])
    _ground(c)
    c.save(asset(name))
    return name


def gen_bookshelf(name="bookshelf.png"):
    W, H = 36, 54
    c = Canvas(W, H)
    rnd = random.Random(7)
    # carcass
    c.shade_rect(0, 0, W - 1, 50, shade(P.WOOD[2], 1.05), P.WOOD[3], P.WOOD[4])
    c.rect(2, 2, W - 3, 48, P.WOOD[4])                    # interior recess
    spines = [P.CLOTH[1], P.WATER[2], P.LEATHER[1], P.FOLIAGE[2],
              P.ROOF[1], P.CLOTH[2], P.WATER[1], P.LEATHER[2]]
    for sy in (3, 18, 33):                                # three shelves
        c.rect(2, sy + 12, W - 3, sy + 13, P.WOOD[3])     # shelf board
        x = 4
        while x < W - 5:
            bw = rnd.randint(2, 4)
            bh = rnd.randint(9, 12)
            col = spines[rnd.randrange(len(spines))]
            top = sy + 13 - bh
            c.rect(x, top, x + bw - 1, sy + 12, col)
            c.hline(x, x + bw - 1, top, shade(col, 1.2))
            c.vline(x, top, sy + 12, shade(col, 1.15))
            if rnd.random() < 0.3:                        # a leaning book
                c.vline(x + bw, top + 2, sy + 12, shade(col, 0.85))
            x += bw + 1
    c.frame(0, 0, W - 1, 50, P.WOOD[4])                   # outer edge
    c.rect(0, 0, W - 1, 0, shade(P.WOOD[1], 1.1))
    # feet
    c.rect(2, 51, 5, 52, P.WOOD[4])
    c.rect(W - 6, 51, W - 3, 52, P.WOOD[4])
    _ground(c)
    c.save(asset(name))
    return name


def gen_cupboard(name="cupboard.png"):
    W, H = 30, 46
    c = Canvas(W, H)
    c.shade_rect(0, 0, W - 1, 42, shade(P.WOOD[1], 1.05), P.WOOD[2], P.WOOD[4])
    # two doors
    midx = W // 2
    for dx0, dx1 in ((2, midx - 1), (midx + 1, W - 3)):
        c.shade_rect(dx0, 3, dx1, 39, shade(P.WOOD[2], 1.04), P.WOOD[3], P.WOOD[4])
        c.frame(dx0 + 1, 5, dx1 - 1, 37, shade(P.WOOD[1], 1.06))  # panel
        c.frame(dx0 + 2, 6, dx1 - 2, 24, shade(P.WOOD[3], 0.95))
    c.vline(midx, 3, 39, P.WOOD[4])                       # centre stile
    c.disc(midx - 2, 22, 1, P.METAL[1])                   # knobs
    c.disc(midx + 2, 22, 1, P.METAL[1])
    c.rect(0, 0, W - 1, 1, shade(P.WOOD[1], 1.1))         # cornice
    c.rect(0, 0, W - 1, 0, shade(P.WOOD[0], 1.05))
    c.rect(2, 43, 6, 44, P.WOOD[4])                       # feet
    c.rect(W - 7, 43, W - 3, 44, P.WOOD[4])
    # a jug on top
    c.rect(W // 2 - 8, -0, W // 2 - 4, 0, P.PLASTER[1])
    _ground(c)
    c.save(asset(name))
    return name


def gen_counter(name="counter.png"):
    """A long serving counter / bar. Foot-anchored (BASE == H); the
    merchant or keeper stands behind it. Used by both shop & tavern interiors."""
    W, H = 108, 30
    c = Canvas(W, H)
    # front panel (planked, in shadow)
    c.shade_rect(2, 8, W - 3, H - 2, shade(P.WOOD[2], 1.04), P.WOOD[3], P.WOOD[4])
    n = 6
    pw = (W - 6) / n
    for i in range(1, n):                                 # plank seams
        px = int(2 + i * pw)
        c.vline(px, 9, H - 3, shade(P.WOOD[4], 0.92))
        c.vline(px + 1, 9, H - 3, shade(P.WOOD[2], 1.06))
    # top surface (overhangs, lit)
    c.shade_rect(0, 2, W - 1, 9, shade(P.WOOD[1], 1.12), P.WOOD[2], P.WOOD[3])
    c.hline(0, W - 1, 2, shade(P.WOOD[0], 1.12))          # front-edge catch-light
    c.hline(0, W - 1, 9, shade(P.WOOD[4], 0.9))           # underlip shadow
    for sx in range(6, W - 6, 6):                         # faint top grain
        c.vline(sx, 3, 8, shade(P.WOOD[2], 0.96))
    c.rect(4, H - 3, W - 5, H - 2, P.METAL[3])            # brass foot rail
    _ground(c)
    c.save(asset(name))
    return name


def gen_rug(name="rug.png"):
    """A flat woven rug. Centered in the .tscn, drawn under the furniture."""
    W, H = 124, 74
    c = Canvas(W, H)
    cx, cy = W // 2, H // 2
    rx, ry = W // 2 - 2, H // 2 - 2
    c.ellipse(cx, cy, rx, ry, P.CLOTH[3], True)           # field
    c.ellipse(cx, cy, rx, ry, P.CLOTH[4], False)          # dark edge
    c.ellipse(cx, cy, rx - 5, ry - 4, rgb(150, 120, 78), False)   # tan band
    c.ellipse(cx, cy, rx - 9, ry - 7, P.CLOTH[2], False)
    # central medallion
    c.ellipse(cx, cy, 22, 14, P.LEATHER[2], True)
    c.ellipse(cx, cy, 22, 14, rgb(176, 146, 88), False)
    c.ellipse(cx, cy, 12, 8, P.CLOTH[1], True)
    c.ellipse(cx, cy, 5, 4, rgb(176, 146, 88), True)
    # woven diamonds along the band
    for t in range(0, 360, 30):
        a = math.radians(t)
        dx = int(cx + math.cos(a) * (rx - 7))
        dy = int(cy + math.sin(a) * (ry - 5))
        c.disc(dx, dy, 2, rgb(160, 130, 84))
        c.paint(dx, dy, P.CLOTH[1])
    # fringe at the two ends
    for fy in range(cy - 6, cy + 7, 3):
        c.hline(2, 5, fy, P.CLOTH[2])
        c.hline(W - 6, W - 3, fy, P.CLOTH[2])
    c.save(asset(name))
    return name


def main():
    made = [
        gen_light(),
        gen_room(),
        gen_room("shop_room.png", decor="shop"),
        gen_room("tavern_room.png", decor="tavern"),
        gen_counter(),
        gen_hearth(),
        gen_table(),
        gen_chair(),
        gen_bookshelf(),
        gen_cupboard(),
        gen_rug(),
    ]
    print("gen_interior ->", ", ".join(made))


if __name__ == "__main__":
    main()
