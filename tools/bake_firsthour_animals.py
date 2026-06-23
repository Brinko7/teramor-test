#!/usr/bin/env python3
"""Bake first-hour animal sheets at remaster scale.

Target: 4 dirs × 4 phases grids, each frame ~68×68 (wolf/dog/deer), 48×48 (rabbit),
28×24 (chicken/bird). Grid matches the engine's hframes=4 / vframes=4 convention
(rows down/up/left/right; cols are the walk cycle 0-3).

Remaster scaling:
  Old wolf frame = 24×24  → new wolf frame = 68×68  (~2.83x, re-authored)
  Old deer frame = 24×24  → new deer frame = 68×68  (re-authored)
  Old rabbit frame = 24×24 → new rabbit frame = 48×48 (re-authored)
  Old chicken frame = 18×18 → new chicken frame = 28×28 (re-authored)
  Old bird frame = 14×14  → new bird frame = 22×22 (re-authored)
  Dog frame (new) = 48×40 (re-authored, slightly rectangular)

All baked into assets/remaster/world/.
Stdlib only, no third-party deps.
Run: python3 tools/bake_firsthour_animals.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas, P, rgb  # noqa: E402

OUTDIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "assets", "remaster", "world"))

INK = P.OUTLINE
DOWN, UP, LEFT, RIGHT = 0, 1, 2, 3
COLS = 4

# ─── palette (matching the grounded world) ───────────────────────────────────

# Wolf (grey timber)
WF_L = (162, 164, 174)
WF_M = (124, 126, 138)
WF_D = ( 88,  90, 102)
WF_BL = (198, 200, 208)  # belly
WF_LD = ( 98, 100, 112)  # leg dark
WF_PW = ( 60,  62,  72)  # paw
WF_NS = ( 34,  30,  36)  # nose
WF_EY = (228, 180,  62)  # amber eye
WF_ER = (130,  96,  96)  # ear interior

# Dog (warm brown street dog)
DG_L = (172, 134,  92)
DG_M = (140, 106,  70)
DG_D = (106,  78,  50)
DG_SN = (152, 118,  80)  # snout
DG_NS = P.OUTLINE
DG_CO = rgb(118,  68,  58)  # collar

# Deer (tan forest deer)
DR_L = (188, 148, 102)
DR_M = (152, 114,  74)
DR_D = (114,  82,  52)
DR_BL = (216, 192, 160)
DR_RU = (228, 214, 190)  # rump
DR_LD = ( 98,  70,  46)
DR_HF = ( 50,  40,  36)  # hoof
DR_NS = ( 36,  30,  32)
DR_EY = ( 42,  30,  24)
DR_AN = (206, 192, 162)  # antler
DR_ER = (152, 112, 106)

# Rabbit (grey-brown)
RB_L = (174, 162, 144)
RB_M = (140, 128, 110)
RB_D = (106,  94,  80)
RB_BL = (210, 202, 190)
RB_TL = (236, 232, 224)  # tail
RB_FT = (122, 108,  92)  # foot
RB_NS = (160, 106, 110)
RB_EY = ( 34,  28,  26)
RB_ER = (174, 124, 126)

# Chicken (white hen)
CH_L = (240, 236, 228)
CH_M = (212, 206, 194)
CH_D = (174, 166, 152)
CH_CM = rgb(196,  74,  66)  # comb
CH_BK = rgb(228, 160,  72)  # beak
CH_LG = rgb(214, 150,  66)  # leg
CH_EY = P.OUTLINE

# Bird (grey pigeon)
BD_L = (152, 152, 160)
BD_M = (122, 122, 132)
BD_D = ( 94,  96, 106)
BD_BR = rgb(156, 126, 118)  # breast
BD_BK = rgb(220, 148,  68)  # beak
BD_FT = rgb(198, 122,  98)  # foot


# ─── pixel helpers ───────────────────────────────────────────────────────────

def put(c, x, y, col):
    c.paint(int(x), int(y), col)


def rect(c, x0, y0, x1, y1, col):
    c.rect(int(x0), int(y0), int(x1), int(y1), col)


def shade_rect(c, x0, y0, x1, y1, light, mid, dark):
    c.rect(x0, y0, x1, y1, mid)
    c.rect(x0, y0, x1, y0, light)
    c.rect(x0, y0, x0, y1, light)
    c.rect(x0, y1, x1, y1, dark)
    c.rect(x1, y0, x1, y1, dark)


def leg_seg(c, x, y_top, y_bot, col, paw):
    c.rect(x, y_top, x + 1, y_bot, col)
    c.rect(x, y_bot, x + 2, y_bot, paw)


# ═══════════════════════════════════════════════════════════════════════════════
# WOLF  —  68×68 per frame, 272×272 sheet (4×4)
# ═══════════════════════════════════════════════════════════════════════════════

FW_W = 68

def _wolf_gait_near(phase):
    return {0: (0,0,0,0), 1: (2,3,-2,0), 2: (-2,0,2,3), 3: (0,0,0,0)}[phase]

def _wolf_gait_far(phase):
    return {0: (0,0,0,0), 1: (-2,0,2,3), 2: (2,3,-2,0), 3: (0,0,0,0)}[phase]

def _wolf_pair_lift(phase):
    return {0:(0,0), 1:(3,0), 2:(0,3), 3:(0,0)}[phase]


def _wolf_side(c, ox, oy, phase):
    nf, nfl, nh, nhl = _wolf_gait_near(phase)
    ff, ffl, fh, fhl = _wolf_gait_far(phase)
    # bushy tail
    rect(c, ox+2, oy+22, ox+10, oy+36, WF_M)
    rect(c, ox+2, oy+16, ox+8, oy+22, WF_M)
    put(c, ox+2, oy+16, WF_L)
    rect(c, ox+8, oy+30, ox+10, oy+36, WF_D)
    # far legs
    leg_seg(c, ox+18+fh, oy+40, oy+60-fhl, WF_LD, WF_PW)
    leg_seg(c, ox+34+ff, oy+40, oy+60-ffl, WF_LD, WF_PW)
    # torso
    shade_rect(c, ox+10, oy+28, ox+44, oy+44, WF_L, WF_M, WF_D)
    rect(c, ox+12, oy+28, ox+43, oy+28, WF_D)
    rect(c, ox+16, oy+44, ox+43, oy+44, WF_BL)
    # haunch
    shade_rect(c, ox+8, oy+30, ox+20, oy+44, WF_L, WF_M, WF_D)
    # neck + head
    rect(c, ox+40, oy+24, ox+50, oy+38, WF_M)
    shade_rect(c, ox+46, oy+20, ox+58, oy+36, WF_L, WF_M, WF_D)
    # muzzle
    rect(c, ox+56, oy+28, ox+65, oy+34, WF_L)
    put(c, ox+65, oy+30, WF_NS)
    rect(c, ox+56, oy+34, ox+63, oy+34, WF_D)
    # ear
    put(c, ox+48, oy+12, WF_M)
    rect(c, ox+46, oy+14, ox+49, oy+20, WF_M)
    put(c, ox+48, oy+18, WF_ER)
    # eye
    put(c, ox+51, oy+24, WF_EY)
    # near legs
    leg_seg(c, ox+24+nh, oy+44, oy+62-nhl, WF_M, WF_PW)
    leg_seg(c, ox+40+nf, oy+44, oy+62-nfl, WF_M, WF_PW)


def _wolf_front(c, ox, oy, phase):
    ll, rl = _wolf_pair_lift(phase)
    # ears
    rect(c, ox+18, oy+4, ox+21, oy+10, WF_M)
    put(c, ox+20, oy+7, WF_ER)
    rect(c, ox+46, oy+4, ox+49, oy+10, WF_M)
    put(c, ox+47, oy+7, WF_ER)
    # head
    shade_rect(c, ox+18, oy+10, ox+50, oy+30, WF_L, WF_M, WF_D)
    # muzzle
    rect(c, ox+26, oy+26, ox+42, oy+36, WF_L)
    rect(c, ox+31, oy+34, ox+37, oy+34, WF_NS)
    put(c, ox+31, oy+36, WF_D)
    # eyes
    put(c, ox+22, oy+20, WF_D); put(c, ox+45, oy+20, WF_D)
    put(c, ox+22, oy+22, WF_EY); put(c, ox+45, oy+22, WF_EY)
    # body
    shade_rect(c, ox+18, oy+32, ox+50, oy+50, WF_L, WF_M, WF_D)
    rect(c, ox+26, oy+34, ox+42, oy+48, WF_BL)
    rect(c, ox+16, oy+34, ox+19, oy+48, WF_D)
    rect(c, ox+49, oy+34, ox+52, oy+48, WF_D)
    # front legs
    leg_seg(c, ox+18, oy+50, oy+62-ll, WF_LD, WF_PW)
    leg_seg(c, ox+44, oy+50, oy+62-rl, WF_LD, WF_PW)


def _wolf_back(c, ox, oy, phase):
    ll, rl = _wolf_pair_lift(phase)
    # ears
    rect(c, ox+18, oy+4, ox+21, oy+10, WF_M)
    rect(c, ox+46, oy+4, ox+49, oy+10, WF_M)
    # head back
    shade_rect(c, ox+18, oy+10, ox+50, oy+28, WF_L, WF_M, WF_D)
    # body
    shade_rect(c, ox+18, oy+28, ox+50, oy+50, WF_L, WF_M, WF_D)
    rect(c, ox+30, oy+12, ox+38, oy+48, WF_D)  # spine
    rect(c, ox+16, oy+34, ox+20, oy+48, WF_M)
    rect(c, ox+48, oy+34, ox+52, oy+48, WF_M)
    # tail toward viewer
    rect(c, ox+28, oy+44, ox+40, oy+58, WF_M)
    rect(c, ox+31, oy+50, ox+37, oy+60, WF_D)
    put(c, ox+31, oy+62, WF_M)
    # hind legs
    leg_seg(c, ox+18, oy+50, oy+62-ll, WF_LD, WF_PW)
    leg_seg(c, ox+44, oy+50, oy+62-rl, WF_LD, WF_PW)


def _wolf_mirror(sheet, src_dir, dst_dir):
    fw = FW_W
    for col in range(COLS):
        for y in range(fw):
            for x in range(fw):
                sc = sheet.at(col * fw + x, src_dir * fw + y)
                if sc[3]:
                    sheet.paint(col * fw + (fw - 1 - x), dst_dir * fw + y, sc)


def bake_wolf():
    fw = FW_W
    sheet = Canvas(fw * COLS, fw * 4)
    for phase in range(COLS):
        _wolf_front(sheet, phase * fw, DOWN * fw, phase)
        _wolf_back(sheet,  phase * fw, UP   * fw, phase)
        _wolf_side(sheet,  phase * fw, RIGHT* fw, phase)
    _wolf_mirror(sheet, RIGHT, LEFT)
    sheet.outline(INK)
    return sheet


# ═══════════════════════════════════════════════════════════════════════════════
# DOG  —  48×40 per frame, 192×160 sheet (4×4)
# ═══════════════════════════════════════════════════════════════════════════════

FW_DG = 48
FH_DG = 40

DIP_DG = [0, 1, 2, 1]
STEP_DG = [0, 2, 0, -2]


def _dog_frame(sheet, ox, oy, d, phase):
    fw, fh = FW_DG, FH_DG
    dip = DIP_DG[phase] // 2
    base_y = oy + fh - 3
    cx = ox + fw // 2
    s = STEP_DG[phase]
    bob = 2 if phase in (1, 3) else 0
    by = base_y - 14 - bob

    if d in (LEFT, RIGHT):
        sgn = -1 if d == LEFT else 1
        # legs (fore + hind)
        for fx in (-10, 9):
            sheet.line(cx + fx + s, by + 4, cx + fx + s, base_y, DG_D)
            sheet.line(cx + fx - s, by + 4, cx + fx - s, base_y, DG_M)
        sheet.ellipse(cx, by, 14, 7, DG_M, fill=True)
        sheet.ellipse(cx, by - 2, 14, 5, DG_L, fill=True)
        sheet.rect(cx - 2, by + 4, cx + 2, by + 4, DG_CO)
        # tail
        sheet.line(cx - sgn * 14, by - 2, cx - sgn * 18, by - 8, DG_D)
        # head + snout
        hx = cx + sgn * 14
        hy = by - 4 + dip
        sheet.disc(hx, hy, 5, DG_L)
        sheet.line(hx - sgn, hy - 7, hx - sgn * 3, hy - 11, DG_D)
        sheet.rect(hx + sgn * 4, hy, hx + sgn * 6, hy + 2, DG_SN)
        put(sheet, hx + sgn * 7, hy, DG_NS)
        put(sheet, hx + sgn * 2, hy - 2, DG_NS)
    else:
        for fx in (-6, 6):
            sheet.line(cx + fx, by + 4, cx + fx, base_y, DG_D)
        sheet.ellipse(cx, by, 9, 7, DG_M, fill=True)
        sheet.ellipse(cx, by - 2, 9, 5, DG_L, fill=True)
        hy = by - 8 + dip
        sheet.disc(cx, hy, 5, DG_L)
        sheet.line(cx - 5, hy - 5, cx - 3, hy - 9, DG_D)
        sheet.line(cx + 5, hy - 5, cx + 3, hy - 9, DG_D)
        if d == DOWN:
            put(sheet, cx, hy + 4, DG_NS)
            put(sheet, cx - 2, hy + 2, DG_NS); put(sheet, cx + 2, hy + 2, DG_NS)
        else:
            sheet.rect(cx - 2, by + 2, cx + 2, by + 5, DG_D)


def bake_dog():
    fw, fh = FW_DG, FH_DG
    sheet = Canvas(fw * COLS, fh * 4)
    for d in range(4):
        for col in range(COLS):
            _dog_frame(sheet, col * fw, d * fh, d, col)
    sheet.outline(INK)
    return sheet


# ═══════════════════════════════════════════════════════════════════════════════
# DEER  —  68×68 per frame, 272×272 sheet (4×4)
# ═══════════════════════════════════════════════════════════════════════════════

FW_DR = 68

def _deer_gait_near(phase):
    return {0:(0,0,0,0), 1:(2,3,-2,0), 2:(-2,0,2,3), 3:(0,0,0,0)}[phase]

def _deer_gait_far(phase):
    return {0:(0,0,0,0), 1:(-2,0,2,3), 2:(2,3,-2,0), 3:(0,0,0,0)}[phase]

def _deer_pair_lift(phase):
    return {0:(0,0), 1:(3,0), 2:(0,3), 3:(0,0)}[phase]


def _deer_leg(sheet, x, y_top, y_bot, col):
    sheet.vline(x, y_top, y_bot, col)
    put(sheet, x, y_bot, DR_HF)


def _deer_side(sheet, ox, oy, phase):
    nf, nfl, nh, nhl = _deer_gait_near(phase)
    ff, ffl, fh, fhl = _deer_gait_far(phase)
    # tail
    sheet.rect(ox+6, oy+20, ox+9, oy+30, DR_M)
    sheet.rect(ox+6, oy+20, ox+7, oy+28, DR_RU)
    # far legs (long, slender)
    _deer_leg(sheet, ox+18+fh, oy+36, oy+60-fhl, DR_LD)
    _deer_leg(sheet, ox+34+ff, oy+36, oy+60-ffl, DR_LD)
    # torso
    shade_rect(sheet, ox+10, oy+20, ox+44, oy+36, DR_L, DR_M, DR_D)
    sheet.rect(ox+12, oy+20, ox+43, oy+20, DR_D)
    sheet.rect(ox+16, oy+36, ox+43, oy+36, DR_BL)
    sheet.rect(ox+10, oy+22, ox+13, oy+34, DR_RU)
    # long neck
    sheet.rect(ox+40, oy+8, ox+46, oy+26, DR_M)
    sheet.rect(ox+45, oy+8, ox+46, oy+22, DR_L)
    # head
    shade_rect(sheet, ox+43, oy+4, ox+56, oy+14, DR_L, DR_M, DR_D)
    # muzzle
    sheet.rect(ox+54, oy+8, ox+62, oy+14, DR_L)
    put(sheet, ox+62, oy+11, DR_NS)
    sheet.rect(ox+54, oy+14, ox+61, oy+14, DR_D)
    # ear
    sheet.rect(ox+40, oy+4, ox+42, oy+7, DR_M)
    put(sheet, ox+40, oy+7, DR_ER)
    # antler
    sheet.rect(ox+48, oy+1, ox+48, oy+6, DR_AN)
    put(sheet, ox+49, oy+1, DR_AN); put(sheet, ox+47, oy+1, DR_AN)
    # eye
    put(sheet, ox+50, oy+8, DR_EY)
    # near legs
    _deer_leg(sheet, ox+24+nh, oy+36, oy+62-nhl, DR_M)
    _deer_leg(sheet, ox+40+nf, oy+36, oy+62-nfl, DR_M)


def _deer_front(sheet, ox, oy, phase):
    ll, rl = _deer_pair_lift(phase)
    # antlers
    sheet.rect(ox+20, oy+1, ox+20, oy+8, DR_AN); put(sheet, ox+19, oy+1, DR_AN)
    sheet.rect(ox+46, oy+1, ox+46, oy+8, DR_AN); put(sheet, ox+47, oy+1, DR_AN)
    # ears
    sheet.rect(ox+14, oy+8, ox+17, oy+13, DR_M); put(sheet, ox+17, oy+10, DR_ER)
    sheet.rect(ox+50, oy+8, ox+53, oy+13, DR_M); put(sheet, ox+50, oy+10, DR_ER)
    # head
    shade_rect(sheet, ox+18, oy+8, ox+50, oy+26, DR_L, DR_M, DR_D)
    # muzzle
    sheet.rect(ox+24, oy+22, ox+42, oy+30, DR_L)
    sheet.rect(ox+28, oy+28, ox+38, oy+30, DR_NS)
    # eyes
    put(sheet, ox+20, oy+16, DR_EY); put(sheet, ox+46, oy+16, DR_EY)
    # body
    shade_rect(sheet, ox+18, oy+30, ox+50, oy+48, DR_L, DR_M, DR_D)
    sheet.rect(ox+24, oy+32, ox+42, oy+46, DR_BL)
    # front legs
    _deer_leg(sheet, ox+22, oy+48, oy+62-ll, DR_LD)
    _deer_leg(sheet, ox+44, oy+48, oy+62-rl, DR_LD)


def _deer_back(sheet, ox, oy, phase):
    ll, rl = _deer_pair_lift(phase)
    put(sheet, ox+20, oy+1, DR_AN); put(sheet, ox+46, oy+1, DR_AN)
    # ears
    sheet.rect(ox+14, oy+5, ox+17, oy+10, DR_M)
    sheet.rect(ox+50, oy+5, ox+53, oy+10, DR_M)
    shade_rect(sheet, ox+18, oy+8, ox+50, oy+24, DR_L, DR_M, DR_D)
    shade_rect(sheet, ox+18, oy+24, ox+50, oy+48, DR_L, DR_M, DR_D)
    sheet.rect(ox+30, oy+10, ox+38, oy+44, DR_D)
    sheet.rect(ox+22, oy+34, ox+30, oy+48, DR_RU)
    sheet.rect(ox+38, oy+34, ox+46, oy+48, DR_RU)
    sheet.rect(ox+28, oy+44, ox+38, oy+54, DR_RU)
    put(sheet, ox+28, oy+40, DR_M)
    _deer_leg(sheet, ox+22, oy+48, oy+62-ll, DR_LD)
    _deer_leg(sheet, ox+44, oy+48, oy+62-rl, DR_LD)


def _deer_mirror(sheet, src_dir, dst_dir):
    fw = FW_DR
    for col in range(COLS):
        for y in range(fw):
            for x in range(fw):
                sc = sheet.at(col * fw + x, src_dir * fw + y)
                if sc[3]:
                    sheet.paint(col * fw + (fw - 1 - x), dst_dir * fw + y, sc)


def bake_deer():
    fw = FW_DR
    sheet = Canvas(fw * COLS, fw * 4)
    for phase in range(COLS):
        _deer_front(sheet, phase * fw, DOWN  * fw, phase)
        _deer_back( sheet, phase * fw, UP    * fw, phase)
        _deer_side( sheet, phase * fw, RIGHT * fw, phase)
    _deer_mirror(sheet, RIGHT, LEFT)
    sheet.outline(INK)
    return sheet


# ═══════════════════════════════════════════════════════════════════════════════
# RABBIT  —  48×48 per frame, 192×192 sheet (4×4)
# ═══════════════════════════════════════════════════════════════════════════════

FW_RB = 48

def _rb_bob(phase): return {0:0, 1:-2, 2:-2, 3:0}[phase]
def _rb_kick(phase): return {0:0, 1:2, 2:4, 3:0}[phase]


def _rb_side(sheet, ox, oy, phase):
    b = _rb_bob(phase); k = _rb_kick(phase)
    base_y = oy + FW_RB - 4
    # cotton tail
    sheet.rect(ox+8, oy+26+b, ox+11, oy+32+b, RB_TL)
    # hind haunch
    shade_rect(sheet, ox+9, oy+24+b, ox+22, oy+38+b, RB_L, RB_M, RB_D)
    # body
    shade_rect(sheet, ox+18, oy+24+b, ox+34, oy+36+b, RB_L, RB_M, RB_D)
    sheet.rect(ox+20, oy+36+b, ox+33, oy+36+b, RB_BL)
    # head
    shade_rect(sheet, ox+28, oy+18+b, ox+40, oy+30+b, RB_L, RB_M, RB_D)
    # muzzle
    sheet.rect(ox+38, oy+24+b, ox+43, oy+28+b, RB_L)
    put(sheet, ox+43, oy+26+b, RB_NS)
    put(sheet, ox+36, oy+22+b, RB_EY)
    # ears
    sheet.rect(ox+28, oy+5+b, ox+30, oy+18+b, RB_M)
    put(sheet, ox+28, oy+9+b, RB_ER)
    sheet.rect(ox+32, oy+5+b, ox+34, oy+18+b, RB_M)
    put(sheet, ox+32, oy+9+b, RB_ER)
    # feet
    sheet.rect(ox+10-k, oy+37+b, ox+16, oy+40, RB_FT)
    sheet.rect(ox+28, oy+36+b, ox+32, oy+40, RB_FT)


def _rb_front(sheet, ox, oy, phase):
    b = _rb_bob(phase)
    base_y = oy + FW_RB - 4
    # ears
    sheet.rect(ox+18, oy+4+b, ox+20, oy+18+b, RB_M)
    put(sheet, ox+18, oy+8+b, RB_ER)
    sheet.rect(ox+26, oy+4+b, ox+28, oy+18+b, RB_M)
    put(sheet, ox+26, oy+8+b, RB_ER)
    # head
    shade_rect(sheet, ox+14, oy+16+b, ox+32, oy+28+b, RB_L, RB_M, RB_D)
    put(sheet, ox+21, oy+26+b, RB_NS); put(sheet, ox+22, oy+26+b, RB_NS)
    put(sheet, ox+16, oy+22+b, RB_EY); put(sheet, ox+28, oy+22+b, RB_EY)
    # body
    shade_rect(sheet, ox+14, oy+28+b, ox+32, oy+40+b, RB_L, RB_M, RB_D)
    sheet.rect(ox+18, oy+30+b, ox+28, oy+39+b, RB_BL)
    # paws
    sheet.rect(ox+14, oy+40+b, ox+17, oy+44, RB_FT)
    sheet.rect(ox+29, oy+40+b, ox+32, oy+44, RB_FT)


def _rb_back(sheet, ox, oy, phase):
    b = _rb_bob(phase)
    # ears
    sheet.rect(ox+18, oy+4+b, ox+20, oy+18+b, RB_M)
    sheet.rect(ox+26, oy+4+b, ox+28, oy+18+b, RB_M)
    shade_rect(sheet, ox+14, oy+16+b, ox+32, oy+26+b, RB_L, RB_M, RB_D)
    shade_rect(sheet, ox+12, oy+26+b, ox+34, oy+40+b, RB_L, RB_M, RB_D)
    sheet.rect(ox+21, oy+18+b, ox+24, oy+38+b, RB_D)
    # tail
    sheet.rect(ox+18, oy+38+b, ox+26, oy+44, RB_TL)
    # hind feet
    sheet.rect(ox+14, oy+40+b, ox+17, oy+44, RB_FT)
    sheet.rect(ox+28, oy+40+b, ox+32, oy+44, RB_FT)


def _rb_mirror(sheet, src_dir, dst_dir):
    fw = FW_RB
    for col in range(COLS):
        for y in range(fw):
            for x in range(fw):
                sc = sheet.at(col * fw + x, src_dir * fw + y)
                if sc[3]:
                    sheet.paint(col * fw + (fw - 1 - x), dst_dir * fw + y, sc)


def bake_rabbit():
    fw = FW_RB
    sheet = Canvas(fw * COLS, fw * 4)
    for phase in range(COLS):
        _rb_front(sheet, phase * fw, DOWN  * fw, phase)
        _rb_back( sheet, phase * fw, UP    * fw, phase)
        _rb_side( sheet, phase * fw, RIGHT * fw, phase)
    _rb_mirror(sheet, RIGHT, LEFT)
    sheet.outline(INK)
    return sheet


# ═══════════════════════════════════════════════════════════════════════════════
# CHICKEN  —  28×28 per frame, 112×112 sheet (4×4)
# ═══════════════════════════════════════════════════════════════════════════════

FW_CH = 28

_DIP_CH  = [0, 2, 5, 2]
_STEP_CH = [0, 2, 0, -2]


def _chicken_frame(sheet, ox, oy, d, phase):
    fw = FW_CH
    dip = _DIP_CH[phase]
    base_y = oy + fw - 3
    cx = ox + fw // 2
    lx = _STEP_CH[phase]
    # legs
    sheet.line(cx - 3 + lx, base_y - 7, cx - 3 + lx, base_y, CH_LG)
    sheet.line(cx + 3 - lx, base_y - 7, cx + 3 - lx, base_y, CH_LG)
    # body
    by = base_y - 13
    sheet.ellipse(cx, by, 8, 7, CH_M, fill=True)
    sheet.ellipse(cx, by - 2, 8, 5, CH_L, fill=True)
    sheet.line(cx + 6, by + 2, cx + 8, by + 3, CH_D)
    # tail
    if d == LEFT:
        sheet.rect(cx + 7, by - 4, cx + 11, by - 2, CH_L)
    elif d == RIGHT:
        sheet.rect(cx - 11, by - 4, cx - 7, by - 2, CH_L)
    elif d == DOWN:
        sheet.rect(cx - 2, by - 7, cx + 2, by - 5, CH_L)
    # head
    hx = cx + (-5 if d == LEFT else 5 if d == RIGHT else 0)
    hy = by - 8 + dip
    sheet.disc(hx, hy, 4, CH_L)
    # comb
    put(sheet, hx, hy - 5, CH_CM)
    put(sheet, hx - 2, hy - 4, CH_CM)
    put(sheet, hx + 2, hy - 4, CH_CM)
    # beak + eye by facing
    if d == LEFT:
        put(sheet, hx - 5, hy, CH_BK); put(sheet, hx - 4, hy, CH_BK)
        put(sheet, hx - 2, hy - 2, CH_EY)
    elif d == RIGHT:
        put(sheet, hx + 5, hy, CH_BK); put(sheet, hx + 4, hy, CH_BK)
        put(sheet, hx + 2, hy - 2, CH_EY)
    elif d == DOWN:
        put(sheet, hx, hy + 4, CH_BK)
        put(sheet, hx - 2, hy, CH_EY); put(sheet, hx + 2, hy, CH_EY)


def bake_chicken():
    fw = FW_CH
    sheet = Canvas(fw * COLS, fw * 4)
    for d in range(4):
        for col in range(COLS):
            _chicken_frame(sheet, col * fw, d * fw, d, col)
    sheet.outline(INK)
    return sheet


# ═══════════════════════════════════════════════════════════════════════════════
# BIRD (ground pigeon)  —  22×22 per frame, 88×88 sheet (4×4)
# ═══════════════════════════════════════════════════════════════════════════════

FW_BD = 22

_DIP_BD  = [0, 2, 5, 2]
_STEP_BD = [0, 1, 0, -1]


def _bird_frame(sheet, ox, oy, d, phase):
    fw = FW_BD
    dip = _DIP_BD[phase]
    base_y = oy + fw - 3
    cx = ox + fw // 2
    put(sheet, cx - 1, base_y, BD_FT); put(sheet, cx + 2, base_y, BD_FT)
    by = base_y - 7
    # body
    sheet.ellipse(cx, by, 5, 5, BD_M, fill=True)
    sheet.ellipse(cx, by - 2, 5, 3, BD_L, fill=True)
    # wing flutter on peck frame
    if phase == 2:
        sheet.line(cx - 5, by - 3, cx - 7, by - 5, BD_D)
        sheet.line(cx + 5, by - 3, cx + 7, by - 5, BD_D)
    # tail
    if d == LEFT:
        sheet.rect(cx + 4, by - 2, cx + 7, by - 1, BD_D)
    elif d == RIGHT:
        sheet.rect(cx - 7, by - 2, cx - 4, by - 1, BD_D)
    elif d == DOWN:
        sheet.rect(cx - 1, by - 6, cx + 1, by - 4, BD_D)
    # head
    hx = cx + (-3 if d == LEFT else 3 if d == RIGHT else 0)
    hy = by - 5 + dip
    sheet.disc(hx, hy, 3, BD_D)
    put(sheet, hx, hy - 1, BD_M)
    if d == LEFT:
        put(sheet, hx - 4, hy, BD_BK); put(sheet, hx - 2, hy - 2, P.OUTLINE)
        sheet.rect(cx + 1, by + 2, cx + 3, by + 4, BD_BR)
    elif d == RIGHT:
        put(sheet, hx + 4, hy, BD_BK); put(sheet, hx + 2, hy - 2, P.OUTLINE)
        sheet.rect(cx - 3, by + 2, cx - 1, by + 4, BD_BR)
    elif d == DOWN:
        put(sheet, hx, hy + 2, BD_BK)
        put(sheet, hx - 2, hy, P.OUTLINE); put(sheet, hx + 2, hy, P.OUTLINE)
        sheet.rect(cx - 2, by + 2, cx + 2, by + 4, BD_BR)


def bake_bird():
    fw = FW_BD
    sheet = Canvas(fw * COLS, fw * 4)
    for d in range(4):
        for col in range(COLS):
            _bird_frame(sheet, col * fw, d * fw, d, col)
    sheet.outline(INK)
    return sheet


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

ANIMALS = [
    # (filename, bake_fn, fw, fh, notes)
    ("wolf.png",    bake_wolf,    FW_W,  FW_W,  "re-authored 68×68 frames, 4×4 grid"),
    ("dog.png",     bake_dog,     FW_DG, FH_DG, "re-authored 48×40 frames, 4×4 grid"),
    ("deer.png",    bake_deer,    FW_DR, FW_DR, "re-authored 68×68 frames, 4×4 grid"),
    ("rabbit.png",  bake_rabbit,  FW_RB, FW_RB, "re-authored 48×48 frames, 4×4 grid"),
    ("chicken.png", bake_chicken, FW_CH, FW_CH, "re-authored 28×28 frames, 4×4 grid"),
    ("bird.png",    bake_bird,    FW_BD, FW_BD, "re-authored 22×22 frames, 4×4 grid"),
]


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    print("=" * 62)
    print("bake_firsthour_animals.py  ->  assets/remaster/world/")
    print("=" * 62)
    for name, fn, fw, fh, note in ANIMALS:
        sheet = fn()
        path = os.path.join(OUTDIR, name)
        sheet.save(path)
        print("  %-16s  %4dx%-4d  grid=4×4  %s" % (name, sheet.w, sheet.h, note))
    print("\nDone.")


if __name__ == "__main__":
    main()
