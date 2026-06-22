#!/usr/bin/env python3
"""Procedural humanoid generator for Teramor, built on pixelforge.

Renders 8-direction walk sheets (24x40 frames, 4 cols x 8 rows = 96x320). Facing
rows are 0=S, 1=SE, 2=E, 3=NE, 4=N, 5=NW, 6=W, 7=SW; the 4 columns are walk
phases (player.gd cycles [0,1,0,2]). Only five rows are drawn by hand (S, SE, E,
NE, N); the three west/up-west rows are horizontal mirrors (E->W, SE->SW,
NE->NW), which keeps the lit-from-upper-left volume consistent.

The character actually turns: front and back share the broad two-shoulder torso
with arms at the sides, the east profile is a narrow side view whose near arm and
both legs swing fore-and-aft (a real walk, not a forward-locked shuffle), and the
diagonals are three-quarter blends that stride along the travel direction. The
art is GROUNDED, not Stardew-cute: a muted ranger in leather and wool, lit from
the upper-left with real tonal volume (multi-step ramps, ambient occlusion in the
creases, a buckled chest strap + lit belt + shoulder seams for gear detail). A warm
`rim_light` pass then catches the upper-left silhouette edge so the figure pops off
grass/stone/timber (the Withered gets a cold rim instead of a heroic one), and a
restrained dark-umber selout sits just outside it, no heavy cartoon ink line.

Two kinds of output:
  * Layered, tintable parts for the player paper-doll. Skin and hair are drawn
    in greyscale so the scene's `modulate` recolors them; the outfit is fixed.
  * Baked, flattened sheets for NPCs and humanoid enemies (skin+outfit+hair
    composited with concrete colors) so every human shares the silhouette.

Dependency-free via pixelforge (stdlib zlib+struct under the hood).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas, P, rgb, shade  # noqa: E402

FW, FH = 24, 40
COLS, ROWS = 4, 8
W, H = FW * COLS, FH * ROWS  # 96 x 320

# Facing rows used by DirUtil/player.gd, clockwise from south.
S, SE, E, NE, N, NW, W_, SW = 0, 1, 2, 3, 4, 5, 6, 7
PHASES = [0, 1, 2, 3]

# Only these five rows are painted; the rest are mirrored from them. Each entry
# is (row, head_mode, body_kind).
BAKE = [
    (S, "front", "front"),
    (SE, "front", "tq_down"),
    (E, "side", "profile"),
    (NE, "back", "tq_up"),
    (N, "back", "back"),
]
MIRRORS = [(E, W_), (SE, SW), (NE, NW)]

# Selout (selective outline) tones. Tintable layers get a near-neutral dark so
# the skin/hair modulate keeps it dark; baked humans get the grounded umber.
INK = rgb(40, 34, 38)
INK_TINT = rgb(52, 50, 54)

# --- tintable greyscale ramps (light -> dark) -------------------------------
# Kept bright so a skin/hair modulate lands in range; 5 steps for smooth volume.
SKIN = [rgb(240, 240, 240), rgb(216, 216, 216), rgb(190, 190, 190),
        rgb(164, 164, 164), rgb(138, 138, 138)]
SKIN_HI = rgb(252, 252, 252)
HAIR = [rgb(232, 232, 232), rgb(198, 198, 198), rgb(166, 166, 166),
        rgb(134, 134, 134), rgb(106, 106, 106)]

# --- outfit palettes (fixed) ------------------------------------------------
# A ranger: sage wool tunic under a brown leather jerkin, wool breeches, boots.
RANGER = {
    "tunic": [rgb(116, 124, 92), rgb(92, 100, 70), rgb(70, 78, 52)],
    "leather": [rgb(146, 106, 66), rgb(118, 82, 48), rgb(92, 62, 36),
                rgb(68, 44, 26)],
    "trouser": [rgb(98, 84, 64), rgb(78, 64, 48), rgb(58, 47, 34)],
    "boot": [rgb(64, 48, 34), rgb(44, 32, 22)],
    "belt": rgb(74, 52, 32),
    "buckle": rgb(150, 128, 78),
}
VILLAGER = {
    "tunic": [rgb(132, 110, 158), rgb(106, 86, 130), rgb(80, 64, 102)],
    "leather": [rgb(120, 108, 96), rgb(96, 86, 76), rgb(74, 66, 58),
                rgb(54, 48, 42)],
    "trouser": [rgb(100, 92, 84), rgb(80, 72, 66), rgb(60, 54, 48)],
    "boot": [rgb(58, 50, 44), rgb(40, 34, 30)],
    "belt": rgb(70, 60, 52),
    "buckle": rgb(126, 118, 96),
}
BANDIT = {
    "tunic": [rgb(126, 78, 72), rgb(100, 60, 56), rgb(76, 44, 40)],
    "leather": [rgb(86, 80, 82), rgb(66, 62, 64), rgb(48, 45, 47),
                rgb(34, 32, 34)],
    "trouser": [rgb(74, 68, 70), rgb(56, 52, 54), rgb(40, 37, 39)],
    "boot": [rgb(44, 40, 40), rgb(28, 26, 26)],
    "belt": rgb(52, 44, 44),
    "buckle": rgb(120, 116, 110),
}
ARCHER = {
    "tunic": [rgb(96, 124, 96), rgb(74, 100, 76), rgb(54, 76, 56)],
    "leather": [rgb(120, 100, 64), rgb(96, 78, 48), rgb(74, 58, 34),
                rgb(54, 42, 24)],
    "trouser": [rgb(86, 80, 64), rgb(66, 62, 48), rgb(48, 45, 34)],
    "boot": [rgb(56, 48, 36), rgb(38, 32, 24)],
    "belt": rgb(92, 74, 46),
    "buckle": rgb(140, 120, 76),
}
BRUTE = {
    "tunic": [rgb(132, 84, 70), rgb(104, 64, 52), rgb(78, 46, 38)],
    "leather": [rgb(96, 70, 56), rgb(74, 54, 42), rgb(54, 40, 30),
                rgb(40, 30, 22)],
    "trouser": [rgb(80, 72, 66), rgb(62, 56, 50), rgb(46, 41, 37)],
    "boot": [rgb(48, 40, 34), rgb(32, 26, 22)],
    "belt": rgb(64, 50, 42),
    "buckle": rgb(118, 104, 84),
}
# The Withered: a former man rotted by the blight. Tattered, colour-drained
# rags — sodden grey-green wool, cracked leather, filthy wraps. Nothing shines.
WITHERED = {
    "tunic": [rgb(96, 104, 82), rgb(74, 82, 62), rgb(54, 60, 44)],
    "leather": [rgb(78, 68, 56), rgb(60, 52, 42), rgb(44, 38, 30),
                rgb(30, 26, 20)],
    "trouser": [rgb(78, 74, 64), rgb(60, 56, 48), rgb(44, 41, 35)],
    "boot": [rgb(46, 42, 36), rgb(30, 27, 23)],
    "belt": rgb(52, 48, 40),
    "buckle": rgb(86, 90, 74),
}

SKIN_TONES = {
    "pale": rgb(244, 214, 184), "tan": rgb(226, 178, 134),
    "brown": rgb(166, 114, 78), "deep": rgb(110, 74, 50),
}
HAIR_COLORS = {
    "black": rgb(52, 46, 44), "brown": rgb(96, 62, 36),
    "blonde": rgb(206, 168, 96), "auburn": rgb(128, 62, 38),
    "ash": rgb(170, 172, 178), "white": rgb(222, 222, 226),
}

# --- villager wardrobe (baked townsfolk looks) ------------------------------
# Distinct outfit palettes so each named NPC reads as an individual instead of a
# tinted clone, all kept in the grounded, muted register of the art bible. Same
# six keys every outfit uses (tunic[3], leather[4], trouser[3], boot[2], belt,
# buckle); "robe" looks fake a full-length gown by matching trouser to tunic.
WARDEN = {  # town guard: quilted steel-blue gambeson, dark leather, iron
    "tunic": [rgb(92, 108, 124), rgb(70, 84, 100), rgb(52, 64, 78)],
    "leather": [rgb(86, 74, 60), rgb(66, 56, 44), rgb(48, 40, 30), rgb(34, 28, 20)],
    "trouser": [rgb(74, 78, 84), rgb(56, 60, 66), rgb(42, 45, 50)],
    "boot": [rgb(48, 44, 40), rgb(32, 28, 26)],
    "belt": rgb(58, 48, 38),
    "buckle": rgb(150, 152, 158),
}
TOWNSWOMAN = {  # warm russet wool dress (skirt tone = tunic)
    "tunic": [rgb(150, 92, 72), rgb(122, 70, 54), rgb(94, 52, 40)],
    "leather": [rgb(120, 96, 78), rgb(96, 74, 58), rgb(72, 54, 40), rgb(52, 38, 28)],
    "trouser": [rgb(132, 80, 62), rgb(104, 62, 48), rgb(78, 46, 34)],
    "boot": [rgb(58, 46, 38), rgb(40, 30, 24)],
    "belt": rgb(74, 56, 42),
    "buckle": rgb(150, 132, 92),
}
CHILD_GARB = {  # bright ochre tunic, simple green breeches
    "tunic": [rgb(196, 158, 86), rgb(166, 130, 64), rgb(132, 100, 46)],
    "leather": [rgb(150, 120, 80), rgb(120, 94, 60), rgb(92, 70, 44), rgb(68, 50, 30)],
    "trouser": [rgb(96, 110, 96), rgb(74, 88, 74), rgb(54, 66, 54)],
    "boot": [rgb(70, 56, 42), rgb(48, 38, 28)],
    "belt": rgb(96, 74, 48),
    "buckle": rgb(150, 130, 86),
}
SMITH_GARB = {  # sooty: dull ember tunic under a scorched leather apron
    "tunic": [rgb(140, 80, 60), rgb(110, 60, 44), rgb(82, 44, 32)],
    "leather": [rgb(74, 62, 54), rgb(56, 46, 40), rgb(40, 32, 28), rgb(28, 22, 18)],
    "trouser": [rgb(70, 64, 60), rgb(54, 48, 45), rgb(40, 35, 32)],
    "boot": [rgb(46, 40, 36), rgb(30, 25, 22)],
    "belt": rgb(54, 44, 38),
    "buckle": rgb(120, 110, 96),
}
CLERIC_GARB = {  # pale plaster robe with a cool slate mantle
    "tunic": [rgb(206, 198, 182), rgb(176, 168, 152), rgb(146, 138, 124)],
    "leather": [rgb(120, 126, 138), rgb(96, 102, 114), rgb(74, 80, 92), rgb(56, 60, 70)],
    "trouser": [rgb(196, 188, 172), rgb(166, 158, 144), rgb(136, 128, 116)],
    "boot": [rgb(72, 66, 60), rgb(50, 45, 40)],
    "belt": rgb(110, 100, 84),
    "buckle": rgb(176, 158, 110),
}
GROCER_GARB = {  # earth-brown shirt under a sage apron
    "tunic": [rgb(120, 100, 80), rgb(96, 80, 62), rgb(72, 60, 46)],
    "leather": [rgb(108, 124, 86), rgb(84, 100, 66), rgb(62, 76, 48), rgb(46, 56, 36)],
    "trouser": [rgb(98, 88, 72), rgb(78, 70, 56), rgb(58, 52, 42)],
    "boot": [rgb(58, 48, 38), rgb(40, 32, 26)],
    "belt": rgb(80, 64, 46),
    "buckle": rgb(140, 122, 80),
}
KEEPER_GARB = {  # tavern keeper: wine shirt, rolled sleeves, buff apron
    "tunic": [rgb(140, 84, 84), rgb(112, 64, 64), rgb(84, 48, 48)],
    "leather": [rgb(168, 146, 110), rgb(138, 118, 86), rgb(108, 90, 64), rgb(82, 66, 46)],
    "trouser": [rgb(92, 80, 72), rgb(72, 62, 56), rgb(54, 46, 42)],
    "boot": [rgb(56, 46, 40), rgb(38, 30, 26)],
    "belt": rgb(80, 64, 50),
    "buckle": rgb(150, 130, 90),
}
ELDER_GARB = {  # dull blue-grey shawl and wool, for the old gossip
    "tunic": [rgb(110, 116, 128), rgb(88, 94, 106), rgb(66, 72, 84)],
    "leather": [rgb(96, 92, 96), rgb(74, 72, 76), rgb(56, 54, 58), rgb(40, 38, 42)],
    "trouser": [rgb(92, 92, 98), rgb(72, 72, 78), rgb(54, 54, 60)],
    "boot": [rgb(54, 50, 50), rgb(36, 33, 34)],
    "belt": rgb(70, 66, 66),
    "buckle": rgb(140, 140, 146),
}
QUARTERMASTER = {  # Mara: practical olive wool + buff leather
    "tunic": [rgb(120, 118, 84), rgb(96, 94, 64), rgb(72, 70, 46)],
    "leather": [rgb(140, 104, 64), rgb(112, 80, 48), rgb(86, 60, 34), rgb(64, 44, 24)],
    "trouser": [rgb(96, 86, 66), rgb(76, 68, 52), rgb(56, 50, 38)],
    "boot": [rgb(60, 48, 34), rgb(42, 32, 22)],
    "belt": rgb(92, 70, 44),
    "buckle": rgb(146, 124, 78),
}
DRUID_GARB = {  # mossy grey-green grove robe
    "tunic": [rgb(108, 122, 102), rgb(84, 98, 80), rgb(62, 74, 58)],
    "leather": [rgb(96, 102, 84), rgb(74, 80, 64), rgb(54, 60, 46), rgb(40, 44, 32)],
    "trouser": [rgb(100, 112, 96), rgb(78, 90, 74), rgb(58, 68, 56)],
    "boot": [rgb(60, 58, 46), rgb(42, 40, 30)],
    "belt": rgb(78, 72, 54),
    "buckle": rgb(150, 140, 96),
}
FARMHAND_GARB = {  # Bram: dusty olive work tunic, brown leather
    "tunic": [rgb(138, 134, 92), rgb(112, 108, 72), rgb(86, 82, 52)],
    "leather": [rgb(120, 92, 60), rgb(96, 72, 46), rgb(72, 52, 32), rgb(52, 38, 22)],
    "trouser": [rgb(108, 96, 72), rgb(86, 76, 56), rgb(64, 56, 42)],
    "boot": [rgb(60, 48, 34), rgb(42, 32, 22)],
    "belt": rgb(86, 64, 42),
    "buckle": rgb(146, 124, 80),
}
FORAGER_GARB = {  # Wrenna / Sorrel: deep forest-green cloak + tunic
    "tunic": [rgb(86, 114, 82), rgb(66, 92, 64), rgb(48, 70, 48)],
    "leather": [rgb(96, 100, 72), rgb(74, 80, 56), rgb(54, 60, 40), rgb(40, 46, 30)],
    "trouser": [rgb(80, 90, 72), rgb(62, 72, 56), rgb(46, 54, 42)],
    "boot": [rgb(54, 52, 40), rgb(38, 36, 28)],
    "belt": rgb(72, 66, 46),
    "buckle": rgb(140, 130, 90),
}
WOODCUTTER_GARB = {  # Hadrin: heavy brown wool + thick leather
    "tunic": [rgb(126, 96, 66), rgb(100, 74, 50), rgb(76, 56, 36)],
    "leather": [rgb(92, 72, 54), rgb(72, 56, 42), rgb(54, 42, 30), rgb(38, 30, 20)],
    "trouser": [rgb(88, 76, 62), rgb(70, 60, 48), rgb(52, 44, 36)],
    "boot": [rgb(52, 42, 34), rgb(36, 28, 22)],
    "belt": rgb(78, 60, 42),
    "buckle": rgb(140, 120, 82),
}

# Each entry bakes a full 8-direction sheet: (filename, outfit, skin, hair, style).
VILLAGER_WARDROBE = [
    ("npc_warden.png", WARDEN, "tan", "black", "short"),
    ("npc_townswoman.png", TOWNSWOMAN, "pale", "brown", "long"),
    ("npc_child.png", CHILD_GARB, "pale", "blonde", "short"),
    ("npc_smith.png", SMITH_GARB, "brown", "black", "spiky"),
    ("npc_cleric.png", CLERIC_GARB, "pale", "auburn", "long"),
    ("npc_grocer.png", GROCER_GARB, "tan", "brown", "short"),
    ("npc_keeper.png", KEEPER_GARB, "tan", "brown", "short"),
    ("npc_gossip.png", ELDER_GARB, "pale", "white", "long"),
    ("npc_quartermaster.png", QUARTERMASTER, "tan", "auburn", "long"),
    ("npc_druid.png", DRUID_GARB, "deep", "ash", "long"),
]

# The named camp / story NPCs each get their OWN baked sheet whose skin, hair,
# style and garb match that NPC's dialogue portrait (gen_portraits.py), so the
# bust and the world sprite read as the same individual. Their .tres reference
# these directly with a neutral (white) tint — no more sharing a tinted sheet
# (which made Elkar/Hadrin/Sorrel one guard, and Wrenna/Maelon one druid).
NAMED_CAST = [
    ("npc_bram.png",   FARMHAND_GARB,   "tan",   "brown",  "short"),
    ("npc_wrenna.png", FORAGER_GARB,    "pale",  "auburn", "long"),
    ("npc_pell.png",   TOWNSWOMAN,      "brown", "black",  "short"),
    ("npc_hadrin.png", WOODCUTTER_GARB, "tan",   "black",  "short"),
    ("npc_mara.png",   VILLAGER,        "pale",  "brown",  "long"),
    ("npc_maelon.png", ELDER_GARB,      "pale",  "white",  "short"),
    ("npc_elkar.png",  RANGER,          "tan",   "ash",    "short"),
    ("npc_sorrel.png", FORAGER_GARB,    "pale",  "black",  "long"),
]

# --- blight (the Withered) --------------------------------------------------
# Ashen, grey-green dead flesh and greasy matted hair (tints for the greyscale
# ramps), plus the sickly glow that leaks from sunken sockets.
ASHEN = rgb(150, 162, 134)
MATTED = rgb(104, 106, 88)
BLIGHT_SOCKET = rgb(24, 34, 26)    # hollow, light-swallowing eye pit
BLIGHT_EYE = rgb(150, 235, 150)    # the glow itself
BLIGHT_CORE = rgb(214, 255, 198)   # hot centre of the glow
BLIGHT_ROT = rgb(84, 104, 70)      # weeping rot blotches on skin/cloth
BLIGHT_OUTLINE = rgb(22, 30, 24)   # cold near-black silhouette

# Per-row face exposure (for the withered's glowing eyes + gaunt cheeks).
ROW_FACE = {S: "front", SE: "front", E: "side_r", NE: "back",
            N: "back", NW: "back", W_: "side_l", SW: "front"}
# Per-row body kind, used by the directional vest overlay.
ROW_KIND = {S: "front", SE: "tq_down", E: "profile", NE: "tq_up",
            N: "back", NW: "tq_up", W_: "profile", SW: "tq_down"}
# Head/upper-body lean (px, east positive) so the three-quarter rows turn into
# the travel direction instead of reading as a straight front/back.
HEAD_DX = {S: 0, SE: 1, E: 0, NE: 1, N: 0, NW: -1, W_: 0, SW: -1}


# --- walk-cycle motion ------------------------------------------------------

def arm_swing(phase):
    # Vertical hand lift for the front/back rows; stride extremes on 1 & 2.
    return {0: 0, 1: -2, 2: 2, 3: 0}[phase]


def leg_lift(phase):
    # Per-leg vertical lift (left, right). One foot lifts per stride extreme.
    return {0: (0, 0), 1: (0, 2), 2: (2, 0), 3: (0, 0)}[phase]


def body_bob(phase):
    return {0: 0, 1: -1, 2: -1, 3: 0}[phase]


def stride(phase):
    # Fore-aft swing for profile/three-quarter rows: +1 and -1 are the two
    # opposite contact poses; 0 is the passing pose.
    return {0: 0, 1: 1, 2: -1, 3: 0}[phase]


# --- low-level shading helpers ----------------------------------------------

def vcol(c, x, y0, y1, ramp, top=0, bot=2):
    """Vertical run with a top highlight fading to a bottom shadow."""
    n = len(ramp)
    span = max(y1 - y0, 1)
    for y in range(y0, y1 + 1):
        t = (y - y0) / span
        idx = int(top + (bot - top) * t + 0.5)
        c.paint(x, y, ramp[max(0, min(n - 1, idx))])


# --- head / face / hair -----------------------------------------------------
# Local frame layout: head y4..14, neck y14..16, torso y16..27, belt y27..28,
# legs y29..38, feet y38. Horizontal center ~x11.5 (frame is 24 wide).

def draw_head(skin, hair, ox, oy, mode, style, bob):
    oy += bob
    if mode == "back":
        # Back of the head: all hair, only a sliver of nape skin.
        skin.rect(ox + 9, oy + 13, ox + 14, oy + 15, SKIN[2])
        skin.rect(ox + 9, oy + 13, ox + 14, oy + 13, SKIN[3])  # nape AO
    else:
        # Solid face oval (rows 4..13), centred ~x11.5. Fill flat, then carve
        # volume: upper-left key light, right-side + jaw ambient occlusion.
        face_rows = [
            (4, 9, 14), (5, 8, 15), (6, 7, 16), (7, 7, 16), (8, 7, 16),
            (9, 7, 16), (10, 7, 16), (11, 8, 15), (12, 8, 15), (13, 9, 14),
        ]
        for dy, x0, x1 in face_rows:
            skin.rect(ox + x0, oy + dy, ox + x1, oy + dy, SKIN[1])
        # key light (upper-left cheek + temple)
        skin.rect(ox + 7, oy + 6, ox + 9, oy + 10, SKIN[0])
        skin.paint(ox + 8, oy + 6, SKIN_HI)
        skin.paint(ox + 7, oy + 7, SKIN_HI)
        # ambient occlusion: right cheek/jaw and chin
        skin.rect(ox + 15, oy + 6, ox + 16, oy + 11, SKIN[2])
        skin.rect(ox + 16, oy + 7, ox + 16, oy + 10, SKIN[3])
        skin.rect(ox + 9, oy + 12, ox + 14, oy + 13, SKIN[2])  # under-cheek
        skin.rect(ox + 10, oy + 13, ox + 13, oy + 13, SKIN[3])  # chin shadow
        _ears(skin, ox, oy, mode)
        if mode == "front":
            _face_front(skin, ox, oy)
        else:
            _face_side(skin, ox, oy)
    # neck
    skin.rect(ox + 10, oy + 14, ox + 13, oy + 16, SKIN[2])
    skin.rect(ox + 10, oy + 14, ox + 13, oy + 14, SKIN[4])  # under-chin AO
    skin.paint(ox + 10, oy + 15, SKIN[3])
    _hair(hair, ox, oy, mode, style)


def _ears(skin, ox, oy, mode):
    if mode == "side":
        # near ear only (right side); mirror builds the west rows.
        skin.rect(ox + 16, oy + 8, ox + 16, oy + 10, SKIN[1])
        skin.paint(ox + 16, oy + 7, SKIN[2])   # subtle point
        skin.paint(ox + 16, oy + 9, SKIN[3])
        return
    # pointed half-elf ears, tucked close to the skull (no horn flare).
    skin.rect(ox + 6, oy + 8, ox + 6, oy + 10, SKIN[1])
    skin.paint(ox + 6, oy + 7, SKIN[2])
    skin.rect(ox + 17, oy + 8, ox + 17, oy + 10, SKIN[2])
    skin.paint(ox + 17, oy + 7, SKIN[3])


def _face_front(skin, ox, oy):
    # soft brows (one step from skin so they frame, not mask)
    skin.rect(ox + 8, oy + 8, ox + 9, oy + 8, SKIN[2])
    skin.rect(ox + 14, oy + 8, ox + 15, oy + 8, SKIN[3])
    # eyes on lit skin: dark iris + a light catch toward the key side.
    skin.paint(ox + 8, oy + 9, SKIN_HI)
    skin.paint(ox + 9, oy + 9, INK)
    skin.paint(ox + 14, oy + 9, INK)
    skin.paint(ox + 15, oy + 9, SKIN[1])
    # nose: short soft shadow on the right of the bridge.
    skin.paint(ox + 12, oy + 10, SKIN[2])
    skin.paint(ox + 12, oy + 11, SKIN[3])
    # mouth: understated neutral.
    skin.rect(ox + 11, oy + 12, ox + 12, oy + 12, SKIN[3])


def _face_side(skin, ox, oy):
    skin.rect(ox + 13, oy + 8, ox + 14, oy + 8, SKIN[3])   # brow
    skin.paint(ox + 14, oy + 9, INK)                        # eye
    skin.paint(ox + 13, oy + 9, SKIN[0])                    # catch
    skin.paint(ox + 17, oy + 10, SKIN[1])                   # nose bridge
    skin.paint(ox + 17, oy + 11, SKIN[3])                   # nostril/under
    skin.paint(ox + 16, oy + 12, SKIN[3])                   # lip line


def _hair(hair, ox, oy, mode, style):
    if mode == "back":
        # full rounded back of head
        for dy, x0, x1 in ((2, 9, 14), (3, 8, 15), (4, 7, 16), (5, 6, 17),
                           (6, 6, 17), (7, 6, 17), (8, 6, 17), (9, 6, 17),
                           (10, 7, 16), (11, 7, 16), (12, 8, 15)):
            hair.rect(ox + x0, oy + dy, ox + x1, oy + dy, HAIR[2])
        hair.rect(ox + 8, oy + 3, ox + 14, oy + 4, HAIR[0])   # crown light
        hair.paint(ox + 9, oy + 5, HAIR[1])
        hair.rect(ox + 6, oy + 8, ox + 6, oy + 12, HAIR[3])   # left shade
        hair.rect(ox + 17, oy + 8, ox + 17, oy + 12, HAIR[4])  # right shade
        if style == "long":
            for dy in range(12, 25):
                hair.rect(ox + 7, oy + dy, ox + 16, oy + dy, HAIR[3])
            hair.rect(ox + 8, oy + 12, ox + 15, oy + 12, HAIR[2])
            hair.rect(ox + 16, oy + 13, ox + 16, oy + 24, HAIR[4])
        elif style == "spiky":
            for x in range(7, 16, 2):
                hair.paint(ox + x, oy + 1, HAIR[1])
        return

    # front/side: a tousled cap framing the brow; tucked, no side flare.
    cap = ((1, 9, 14), (2, 8, 15), (3, 7, 16), (4, 7, 16))
    for dy, x0, x1 in cap:
        hair.rect(ox + x0, oy + dy, ox + x1, oy + dy, HAIR[2])
    # crown highlight + off-centre part
    hair.rect(ox + 8, oy + 1, ox + 12, oy + 1, HAIR[0])
    hair.rect(ox + 8, oy + 2, ox + 11, oy + 2, HAIR[0])
    hair.paint(ox + 10, oy + 3, HAIR[1])
    # fringe dipping onto the forehead, lit left -> shadowed right
    hair.rect(ox + 7, oy + 5, ox + 9, oy + 5, HAIR[1])
    hair.rect(ox + 13, oy + 5, ox + 16, oy + 5, HAIR[3])
    hair.paint(ox + 7, oy + 6, HAIR[1])      # short sideburn (lit)
    hair.paint(ox + 16, oy + 6, HAIR[4])     # short sideburn (shadow)
    if style == "long":
        for dy in range(5, 21):
            hair.paint(ox + 6, oy + dy, HAIR[3])
            hair.paint(ox + 17, oy + dy, HAIR[4])
        hair.rect(ox + 6, oy + 19, ox + 7, oy + 21, HAIR[3])
        hair.rect(ox + 16, oy + 19, ox + 17, oy + 21, HAIR[4])
    elif style == "spiky":
        for x in range(8, 15, 2):
            hair.paint(ox + x, oy + 0, HAIR[1])
            hair.paint(ox + x, oy + 1, HAIR[0])


# --- body: shared torso -----------------------------------------------------

def _torso(outfit, ox, oy, pal, back):
    """The broad two-shoulder torso shared by the front and back rows: sage
    tunic, leather jerkin over the chest, belt + buckle. `back` swaps the front
    lacing/collar for a plain back seam and drops the buckle."""
    tun, lea = pal["tunic"], pal["leather"]
    for dy in range(16, 28):
        x0, x1 = 7, 16
        if dy == 16:
            x0, x1 = 8, 15
        outfit.rect(ox + x0, oy + dy, ox + x1, oy + dy, tun[1])
    outfit.rect(ox + 7, oy + 17, ox + 8, oy + 27, tun[0])   # left key light
    outfit.rect(ox + 16, oy + 17, ox + 16, oy + 27, tun[2])  # right shadow
    outfit.rect(ox + 15, oy + 24, ox + 16, oy + 27, tun[2])
    # leather jerkin panel
    for dy in range(17, 26):
        outfit.rect(ox + 8, oy + dy, ox + 15, oy + dy, lea[1])
    outfit.rect(ox + 8, oy + 17, ox + 9, oy + 25, lea[0])   # jerkin highlight
    outfit.rect(ox + 14, oy + 17, ox + 15, oy + 25, lea[2])  # jerkin shadow
    outfit.rect(ox + 8, oy + 25, ox + 15, oy + 25, lea[3])  # hem AO
    if not back:
        outfit.rect(ox + 11, oy + 17, ox + 12, oy + 25, lea[2])  # lacing seam
        outfit.paint(ox + 11, oy + 19, lea[0])
        outfit.paint(ox + 11, oy + 22, lea[0])
        # a buckled chest strap across the jerkin (a fastening, breaks the flat panel)
        outfit.rect(ox + 9, oy + 20, ox + 14, oy + 20, lea[3])
        outfit.rect(ox + 9, oy + 19, ox + 14, oy + 19, lea[0])   # lit edge above it
        outfit.paint(ox + 12, oy + 20, pal["buckle"])
        # collar of the tunic showing above the jerkin
        outfit.rect(ox + 9, oy + 16, ox + 14, oy + 16, tun[0])
        outfit.paint(ox + 11, oy + 16, tun[2])
        outfit.paint(ox + 12, oy + 16, tun[2])
    else:
        outfit.rect(ox + 11, oy + 17, ox + 12, oy + 24, lea[2])  # back seam
        outfit.rect(ox + 8, oy + 16, ox + 15, oy + 16, tun[1])
    # shoulders / sleeve caps, with a seam shadow defining where the arm meets torso
    outfit.rect(ox + 6, oy + 17, ox + 6, oy + 19, tun[1])
    outfit.rect(ox + 17, oy + 17, ox + 17, oy + 19, tun[2])
    outfit.paint(ox + 8, oy + 17, tun[0])                    # lit left shoulder seam
    outfit.paint(ox + 15, oy + 17, tun[2])                   # shaded right shoulder
    # belt + buckle, with a lit top edge so the leather catches the key light
    outfit.rect(ox + 7, oy + 26, ox + 16, oy + 27, pal["belt"])
    outfit.rect(ox + 7, oy + 26, ox + 16, oy + 26, shade(pal["belt"], 1.22))
    if not back:
        outfit.rect(ox + 11, oy + 26, ox + 12, oy + 27, pal["buckle"])


# --- body: front / back rows ------------------------------------------------

def _body_fb(skin, outfit, ox, oy, phase, pal, back):
    bob = body_bob(phase)
    sw = arm_swing(phase)
    ll, rl = leg_lift(phase)
    oy += bob
    tro = pal["trouser"]
    # legs + boots first; the torso hem overlaps the tops.
    _leg(outfit, ox + 8, oy + 29, tro, pal["boot"], ll, inner=True)
    _leg(outfit, ox + 12, oy + 29, tro, pal["boot"], rl, inner=False)
    outfit.rect(ox + 11, oy + 29, ox + 12, oy + 35, tro[2])  # center gap AO
    _torso(outfit, ox, oy, pal, back)
    # arms: tunic sleeve -> leather bracer -> skin hand (vertical swing).
    _arm(skin, outfit, ox + 5, oy + 18, pal["tunic"], pal["leather"], SKIN,
         sw, left=True)
    _arm(skin, outfit, ox + 17, oy + 18, pal["tunic"], pal["leather"], SKIN,
         -sw, left=False)


def _leg(c, x, y, tro, boot, lift, inner):
    y -= lift
    hi = tro[0] if inner else tro[1]
    sh = tro[1] if inner else tro[2]
    for dy in range(0, 7):
        c.rect(x, y + dy, x + 3, y + dy, tro[1])
    c.rect(x, y, x, y + 6, hi)        # outer/key column
    c.rect(x + 3, y, x + 3, y + 6, sh)  # inner shadow column
    c.rect(x, y + 3, x + 3, y + 3, tro[2])  # knee crease
    # boot
    c.rect(x, y + 7, x + 3, y + 9, boot[0])
    c.rect(x, y + 9, x + 3, y + 9, boot[1])     # sole
    c.paint(x, y + 7, boot[0])
    c.paint(x + 3, y + 7, boot[1])


def _arm(skin, outfit, x, y, tun, lea, sk, lift, left):
    y -= lift
    hi = tun[0] if left else tun[1]
    sh = tun[1] if left else tun[2]
    # upper sleeve (tunic)
    outfit.rect(x, y, x + 1, y + 3, tun[1])
    outfit.rect(x, y, x, y + 3, hi)
    outfit.rect(x + 1, y, x + 1, y + 3, sh)
    # leather bracer
    outfit.rect(x, y + 4, x + 1, y + 5, lea[1])
    outfit.rect(x, y + 4, x, y + 5, lea[0] if left else lea[2])
    # hand
    skin.rect(x, y + 6, x + 1, y + 7, sk[1] if left else sk[2])
    skin.paint(x, y + 6, sk[0] if left else sk[1])


# --- body: east profile row -------------------------------------------------

def _body_profile(skin, outfit, ox, oy, phase, pal):
    """A true side view facing east. The torso is narrow (chest leads at the
    right), both legs and the near arm swing fore-and-aft so the walk reads as
    real locomotion rather than a forward-locked shuffle."""
    bob = body_bob(phase)
    s = stride(phase)
    oy += bob
    tun, lea, tro = pal["tunic"], pal["leather"], pal["trouser"]

    # far arm + far hand, tucked behind the torso (drawn first, darker).
    outfit.rect(ox + 8, oy + 18, ox + 9, oy + 23, tun[2])
    outfit.rect(ox + 8, oy + 23, ox + 9, oy + 24, lea[2])
    skin.rect(ox + 8, oy + 25, ox + 9, oy + 25, SKIN[3])

    # legs: back leg (darker) then front leg, swinging fore-aft.
    _pleg(outfit, ox + 10 - s * 2, oy + 29, tro, pal["boot"], back=True)
    _pleg(outfit, ox + 11 + s * 2, oy + 29, tro, pal["boot"], back=False)

    # narrow side torso (tunic).
    for dy in range(16, 28):
        x0, x1 = 9, 14
        if dy == 16:
            x0, x1 = 10, 14
        outfit.rect(ox + x0, oy + dy, ox + x1, oy + dy, tun[1])
    outfit.rect(ox + 9, oy + 17, ox + 9, oy + 27, tun[0])    # lit back edge
    outfit.rect(ox + 14, oy + 17, ox + 14, oy + 27, tun[2])  # chest shadow
    # leather jerkin
    for dy in range(17, 26):
        outfit.rect(ox + 10, oy + dy, ox + 13, oy + dy, lea[1])
    outfit.rect(ox + 10, oy + 17, ox + 10, oy + 25, lea[0])
    outfit.rect(ox + 13, oy + 17, ox + 13, oy + 25, lea[2])
    outfit.rect(ox + 10, oy + 25, ox + 13, oy + 25, lea[3])
    outfit.rect(ox + 13, oy + 16, ox + 14, oy + 16, tun[0])  # collar at front
    # belt + buckle toward the front
    outfit.rect(ox + 9, oy + 26, ox + 14, oy + 27, pal["belt"])
    outfit.rect(ox + 13, oy + 26, ox + 14, oy + 27, pal["buckle"])

    # near arm swinging over the torso (counter to the front leg).
    _parm(skin, outfit, ox, oy, s, tun, lea)


def _pleg(c, x, y, tro, boot, back):
    """Profile leg, 3 wide, toe pointing east."""
    base = 1 if not back else 2
    for dy in range(0, 7):
        c.rect(x, y + dy, x + 2, y + dy, tro[base])
    c.rect(x, y, x, y + 6, tro[max(base - 1, 0)])      # lit column
    c.rect(x + 2, y, x + 2, y + 6, tro[min(base + 1, 2)])  # shadow column
    c.rect(x, y + 3, x + 2, y + 3, tro[2])             # knee
    bi = 0 if not back else 1
    c.rect(x, y + 7, x + 2, y + 9, boot[bi])
    c.rect(x + 2, y + 8, x + 3, y + 9, boot[bi])       # toe forward (east)
    c.rect(x, y + 9, x + 3, y + 9, boot[1])            # sole


def _parm(skin, outfit, ox, oy, s, tun, lea):
    hx = ox + 11 - s * 3       # hand swings opposite the front leg
    # shoulder/upper arm at the front of the torso
    outfit.rect(ox + 11, oy + 17, ox + 12, oy + 20, tun[1])
    outfit.rect(ox + 11, oy + 17, ox + 11, oy + 20, tun[0])
    # forearm (leather) reaching toward the hand
    x0, x1 = min(ox + 11, hx), max(ox + 12, hx)
    outfit.rect(x0, oy + 21, x1, oy + 22, lea[1])
    outfit.rect(x0, oy + 21, x0, oy + 21, lea[0])
    # hand
    skin.rect(hx, oy + 23, hx + 1, oy + 24, SKIN[1])
    skin.paint(hx, oy + 23, SKIN[0])


# --- body: three-quarter rows -----------------------------------------------

def _body_tq(skin, outfit, ox, oy, phase, pal, up):
    """Down-east / up-east three-quarter. Reuses the broad torso but strides the
    legs along the travel direction and counter-swings the arms, so a diagonal
    walk reorients its limbs instead of staying forward-locked."""
    bob = body_bob(phase)
    s = stride(phase)
    oy += bob
    tro = pal["trouser"]
    # lead (east/right) leg steps forward, trail (left) leg steps back.
    lead_x = ox + 12 + (1 if s > 0 else 0)
    trail_x = ox + 8 - (1 if s < 0 else 0)
    lead_lift = 2 if s > 0 else 0
    trail_lift = 2 if s < 0 else 0
    _leg(outfit, trail_x, oy + 29, tro, pal["boot"], trail_lift, inner=True)
    _leg(outfit, lead_x, oy + 29, tro, pal["boot"], lead_lift, inner=False)
    outfit.rect(ox + 11, oy + 29, ox + 12, oy + 34, tro[2])
    # Lean the upper body east over the centred hips so the turn reads as 3/4.
    _torso(outfit, ox + 1, oy, pal, back=up)
    # arms counter-swing the legs (vertical lift reads as a gait at 3/4).
    _arm(skin, outfit, ox + 6, oy + 18, pal["tunic"], pal["leather"], SKIN,
         -s * 2, left=True)
    _arm(skin, outfit, ox + 18, oy + 18, pal["tunic"], pal["leather"], SKIN,
         s * 2, left=False)


# --- assembly ---------------------------------------------------------------

def render_human(pal, style):
    skin, outfit, hair = Canvas(W, H), Canvas(W, H), Canvas(W, H)
    for row, head_mode, kind in BAKE:
        for phase in PHASES:
            ox, oy = phase * FW, row * FH
            draw_body(skin, outfit, ox, oy, kind, phase, pal)
            draw_head(skin, hair, ox + HEAD_DX[row], oy, head_mode, style,
                      body_bob(phase))
    for src, dst in MIRRORS:
        for c in (skin, outfit, hair):
            _mirror(c, src, dst)
    return skin, outfit, hair


def draw_body(skin, outfit, ox, oy, kind, phase, pal):
    if kind == "front":
        _body_fb(skin, outfit, ox, oy, phase, pal, back=False)
    elif kind == "back":
        _body_fb(skin, outfit, ox, oy, phase, pal, back=True)
    elif kind == "profile":
        _body_profile(skin, outfit, ox, oy, phase, pal)
    elif kind == "tq_down":
        _body_tq(skin, outfit, ox, oy, phase, pal, up=False)
    elif kind == "tq_up":
        _body_tq(skin, outfit, ox, oy, phase, pal, up=True)


def _mirror(c, src_facing, dst_facing):
    sy, dy = src_facing * FH, dst_facing * FH
    for col in range(COLS):
        bx = col * FW
        for y in range(FH):
            for x in range(FW):
                px = c.at(bx + x, sy + y)
                if px[3]:
                    c.paint(bx + (FW - 1 - x), dy + y, px)


def _selout(c, color):
    """Outline only the outer silhouette (4-neighbour), grounded dark tone."""
    c.outline(color)


# A warm lit rim along the upper-left silhouette (the key-light edge) makes the
# figure pop off grass/stone/timber; the cold variant separates the Withered
# without making it look heroic.
RIM_WARM = rgb(250, 236, 200)
RIM_COLD = rgb(150, 176, 156)


# --- outputs ----------------------------------------------------------------

BASE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                     "..", "assets", "placeholder"))


def save_layered_player():
    cdir = os.path.join(BASE, "char")
    skin, outfit, _ = render_human(RANGER, "short")
    # Rim each layer before its ink. Skin/hair are greyscale (the scene tints them),
    # so their rim lands as a bright edge in the final skin/hair hue — a natural
    # per-material lit edge; the fixed outfit takes the warm rim directly.
    skin.rim_light(0.5, RIM_WARM)
    outfit.rim_light(0.5, RIM_WARM)
    _selout(skin, INK_TINT)
    _selout(outfit, INK)
    skin.save(os.path.join(cdir, "body.png"))
    outfit.save(os.path.join(cdir, "outfit_ranger.png"))
    for style in ("short", "long", "spiky"):
        _, _, hair = render_human(RANGER, style)
        hair.rim_light(0.5, RIM_WARM)
        _selout(hair, INK_TINT)
        hair.save(os.path.join(cdir, "hair_%s.png" % style))


def bake_sheet(pal, skin_tone, hair_color, style):
    """Compose a flattened, outlined 8-direction humanoid sheet (96x320)."""
    skin, outfit, hair = render_human(pal, style)
    skin.tint(skin_tone)
    hair.tint(hair_color)
    base = Canvas(W, H)
    base.blit(skin, 0, 0, mode="over")
    base.blit(outfit, 0, 0, mode="over")
    base.blit(hair, 0, 0, mode="over")
    base.rim_light(0.5, RIM_WARM)
    _selout(base, P.OUTLINE)
    return base


def save_baked(path, pal, skin_tone, hair_color, style):
    bake_sheet(pal, skin_tone, hair_color, style).save(path)


def save_wardrobe():
    """Bake every named townsfolk look, plus a side-by-side contact sheet so the
    whole cast can be eyeballed without launching the engine."""
    faces = []
    for fname, pal, skin, hair, style in VILLAGER_WARDROBE:
        sheet = bake_sheet(pal, SKIN_TONES[skin], HAIR_COLORS[hair], style)
        sheet.save(os.path.join(BASE, fname))
        faces.append(sheet.region(0, 0, FW, FH))  # south idle
    pad = 3
    cell = FW + pad
    mont = Canvas(cell * len(faces) + pad, FH + pad * 2)
    mont.rect(0, 0, mont.w - 1, mont.h - 1, rgb(120, 128, 96))
    for i, face in enumerate(faces):
        mont.blit(face, pad + i * cell, pad, mode="over")
    mont.scaled(4).save(os.path.join(BASE, "_preview_wardrobe.png"))


def _blight_eye(c, ex, ey):
    """Carve a sunken socket and light it from within — the eye should look
    hollow yet lit, the blight glowing out of a dead face."""
    c.rect(ex - 1, ey - 1, ex + 1, ey + 1, BLIGHT_SOCKET)  # recessed pit
    c.paint(ex, ey - 2, BLIGHT_SOCKET)                      # deep brow shadow
    c.paint(ex - 1, ey, BLIGHT_EYE)                         # glow bleeding out
    c.paint(ex + 1, ey, BLIGHT_EYE)
    c.paint(ex, ey, BLIGHT_CORE)                            # hot pinpoint


def _rot_blotches(c, ox, oy, face):
    """Scatter a few weeping sores across flesh and rags (opaque pixels only)."""
    spots = [(9, 20), (14, 23), (8, 25), (16, 19), (11, 28), (13, 17)]
    for sx, sy in spots:
        if c.opaque(ox + sx, oy + sy):
            c.paint(ox + sx, oy + sy, BLIGHT_ROT)
    if face == "front":                                      # gaunt hollow cheeks
        for sx, sy in ((8, 11), (15, 11)):
            if c.opaque(ox + sx, oy + sy):
                c.paint(ox + sx, oy + sy, BLIGHT_ROT)


def save_withered(path):
    """A baked humanoid corrupted in post: ashen flesh, matted hair, rotted
    rags, then sunken glowing sockets and weeping sores stamped per frame."""
    skin, outfit, hair = render_human(WITHERED, "long")
    skin.tint(ASHEN)
    hair.tint(MATTED)
    base = Canvas(W, H)
    base.blit(skin, 0, 0, mode="over")
    base.blit(outfit, 0, 0, mode="over")
    base.blit(hair, 0, 0, mode="over")
    for row, face in ROW_FACE.items():
        for phase in PHASES:
            ox, oy = phase * FW, row * FH + body_bob(phase)
            hx = ox + HEAD_DX[row]
            if face == "front":
                _blight_eye(base, hx + 9, oy + 9)
                _blight_eye(base, hx + 14, oy + 9)
            elif face == "side_r":
                _blight_eye(base, hx + 14, oy + 9)
            elif face == "side_l":
                _blight_eye(base, hx + 9, oy + 9)
            _rot_blotches(base, ox, oy, face)
    base.rim_light(0.34, RIM_COLD)   # a cold, dead separation — not a heroic glow
    _selout(base, BLIGHT_OUTLINE)
    base.save(path)
    # eyeball preview on a murky backdrop so the glow reads.
    bg = Canvas(W, H)
    bg.rect(0, 0, W - 1, H - 1, rgb(38, 44, 40))
    bg.blit(base, 0, 0, mode="over")
    bg.scaled(4).save(os.path.join(BASE, "_preview_withered.png"))


def torso_bounds(kind):
    if kind == "profile":
        return (9, 14)
    if kind in ("tq_down", "tq_up"):
        return (8, 15)
    return (7, 16)


def render_vest():
    """Leather chest armour (BODY slot) aligned to each directional torso, synced
    per frame. Drawn symmetrically so the mirrored rows need no extra pass."""
    lea = [rgb(158, 116, 70), rgb(128, 90, 52), rgb(98, 66, 36), rgb(72, 48, 26)]
    c = Canvas(W, H)
    for row, kind in ROW_KIND.items():
        x0, x1 = torso_bounds(kind)
        for phase in PHASES:
            ox, oy = phase * FW, row * FH + body_bob(phase)
            for dy in range(17, 27):
                c.rect(ox + x0, oy + dy, ox + x1, oy + dy, lea[1])
            c.rect(ox + x0, oy + 17, ox + x0 + 1, oy + 26, lea[0])
            c.rect(ox + x1 - 1, oy + 17, ox + x1, oy + 26, lea[2])
            c.rect(ox + x0, oy + 26, ox + x1, oy + 26, lea[3])
            c.rect(ox + x0 - 1, oy + 17, ox + x0 - 1, oy + 19, lea[1])  # pads
            c.rect(ox + x1 + 1, oy + 17, ox + x1 + 1, oy + 19, lea[2])
            if kind == "front":
                c.rect(ox + 11, oy + 18, ox + 12, oy + 25, lea[2])  # strap
    _selout(c, P.OUTLINE)
    c.save(os.path.join(BASE, "items", "vest_overlay.png"))


# --- holstered / slung gear overlays ----------------------------------------
# Directional 96x320 sheets synced to the body frame, exactly like the vest.
# They show a weapon/shield stowed on the body when it is NOT in hand: a sword
# in a hip scabbard, a bow or round shield slung on the back. Occlusion is baked
# per facing — full on the back rows, an edge on the profiles, and only a peeking
# sliver plus a carry strap on the front rows where the body hides them.

SCAB_LEATHER = [rgb(98, 66, 40), rgb(74, 50, 30), rgb(52, 34, 22)]
HILT_GRIP = [rgb(78, 54, 36), rgb(54, 38, 26)]
HILT_METAL = [rgb(178, 182, 190), rgb(120, 124, 132), rgb(78, 82, 92)]
BOW_WOOD = [rgb(152, 114, 68), rgb(120, 86, 50), rgb(90, 62, 36)]
BOW_STRING = rgb(214, 210, 198)
SHIELD_WOOD = [rgb(158, 116, 70), rgb(128, 90, 52), rgb(96, 64, 36)]
SHIELD_RIM = [rgb(150, 150, 156), rgb(108, 110, 120), rgb(74, 78, 88)]
SHIELD_BOSS = [rgb(184, 188, 196), rgb(120, 124, 132)]
STRAP = rgb(70, 50, 34)

# Which hip the scabbard hangs at, per facing, so the sword reads as worn on one
# side of the body and swaps sides as the character turns.
HIP_X = {S: 15, SE: 14, E: 9, NE: 9, N: 8, NW: 14, W_: 15, SW: 10}


def _round_shield(c, cx, cy, r):
    c.disc(cx, cy, r, SHIELD_WOOD[1])
    c.vline(cx - 2, cy - r + 1, cy + r - 1, SHIELD_WOOD[2])  # plank seams
    c.vline(cx + 2, cy - r + 1, cy + r - 1, SHIELD_WOOD[2])
    c.disc(cx - 1, cy - 2, 1, SHIELD_WOOD[0])                # upper-left light
    c.ellipse(cx, cy, r, r, SHIELD_RIM[1], False)            # iron rim
    c.rect(cx - 1, cy - 1, cx + 1, cy + 1, SHIELD_BOSS[1])   # central boss
    c.paint(cx - 1, cy - 1, SHIELD_BOSS[0])


def _shield_edge(c, bx, cy):
    c.ellipse(bx, cy, 1.6, 5, SHIELD_WOOD[1], True)
    c.vline(bx, cy - 4, cy + 4, SHIELD_RIM[1])
    c.rect(bx - 1, cy - 1, bx, cy + 1, SHIELD_BOSS[1])


def render_back_shield():
    c = Canvas(W, H)
    for row, kind in ROW_KIND.items():
        x0, x1 = torso_bounds(kind)
        cx = (x0 + x1) // 2
        for phase in PHASES:
            ox, oy = phase * FW, row * FH + body_bob(phase)
            if kind in ("back", "tq_up"):
                _round_shield(c, ox + cx, oy + 21, 5)
            elif kind == "profile":
                bx = ox + x0 - 1 if row == E else ox + x1 + 1
                _shield_edge(c, bx, oy + 21)
            else:  # hidden behind the body: a rim sliver + a carry strap.
                c.vline(ox + x1 + 1, oy + 18, oy + 22, SHIELD_RIM[1])
                c.paint(ox + x1 + 1, oy + 19, SHIELD_WOOD[1])
                c.paint(ox + x1 + 1, oy + 21, SHIELD_WOOD[1])
                c.line(ox + x1 - 1, oy + 17, ox + x0 + 1, oy + 26, STRAP)
    _selout(c, P.OUTLINE)
    c.save(os.path.join(BASE, "items", "back_shield.png"))


def _slung_bow(c, cx, oy):
    bx = cx - 1
    c.line(bx, oy + 16, bx - 2, oy + 21, BOW_WOOD[1])   # upper limb
    c.line(bx - 2, oy + 21, bx, oy + 27, BOW_WOOD[1])   # lower limb
    c.paint(bx - 2, oy + 21, BOW_WOOD[0])               # lit belly
    c.line(bx, oy + 16, bx, oy + 27, BOW_STRING)        # string
    c.paint(bx, oy + 16, BOW_WOOD[2])                   # nocks
    c.paint(bx, oy + 27, BOW_WOOD[2])


def render_back_bow():
    c = Canvas(W, H)
    for row, kind in ROW_KIND.items():
        x0, x1 = torso_bounds(kind)
        cx = (x0 + x1) // 2
        for phase in PHASES:
            ox, oy = phase * FW, row * FH + body_bob(phase)
            if kind in ("back", "tq_up"):
                _slung_bow(c, ox + cx, oy)
            elif kind == "profile":
                bx = ox + x0 - 1 if row == E else ox + x1 + 1
                c.vline(bx, oy + 16, oy + 27, BOW_WOOD[1])
                c.paint(bx, oy + 16, BOW_WOOD[0])
                c.paint(bx, oy + 27, BOW_WOOD[2])
            else:  # only the limb tips clear the body; a strap crosses the chest.
                c.vline(ox + x0 - 1, oy + 14, oy + 16, BOW_WOOD[1])
                c.paint(ox + x0 - 1, oy + 14, BOW_WOOD[0])
                c.vline(ox + x1 + 1, oy + 26, oy + 28, BOW_WOOD[1])
                c.line(ox + x0 + 1, oy + 17, ox + x1 - 1, oy + 26, STRAP)
    _selout(c, P.OUTLINE)
    c.save(os.path.join(BASE, "items", "back_bow.png"))


def _sheathed_sword(c, x, oy):
    c.rect(x, oy + 24, x + 1, oy + 33, SCAB_LEATHER[1])     # scabbard body
    c.vline(x, oy + 24, oy + 33, SCAB_LEATHER[0])           # lit edge
    c.vline(x + 1, oy + 24, oy + 33, SCAB_LEATHER[2])       # shade edge
    c.rect(x, oy + 32, x + 1, oy + 33, HILT_METAL[1])       # chape
    c.paint(x, oy + 32, HILT_METAL[0])
    c.rect(x, oy + 19, x + 1, oy + 22, HILT_GRIP[0])        # grip above the belt
    c.paint(x + 1, oy + 20, HILT_GRIP[1])
    c.rect(x - 1, oy + 22, x + 2, oy + 22, HILT_METAL[1])   # crossguard
    c.paint(x - 1, oy + 22, HILT_METAL[0])
    c.paint(x, oy + 18, HILT_METAL[0])                      # pommel
    c.paint(x + 1, oy + 18, HILT_METAL[1])


def render_sheath_sword():
    c = Canvas(W, H)
    for row in ROW_KIND:
        x = HIP_X[row]
        for phase in PHASES:
            ox, oy = phase * FW, row * FH + body_bob(phase)
            _sheathed_sword(c, ox + x, oy)
    _selout(c, P.OUTLINE)
    c.save(os.path.join(BASE, "items", "sheath_sword.png"))


def render_attack_arm():
    """A single forearm sprite (sleeve -> leather bracer) pointing +X. It rides
    the weapon pivot so a swing sweeps the arm with the blade instead of leaving
    the body's idle arms pinned at the sides."""
    tun, lea = RANGER["tunic"], RANGER["leather"]
    c = Canvas(14, 8)
    c.rect(0, 2, 6, 5, tun[1])
    c.rect(0, 2, 6, 2, tun[0])
    c.rect(0, 5, 6, 5, tun[2])
    c.rect(7, 2, 12, 5, lea[1])
    c.rect(7, 2, 12, 2, lea[0])
    c.rect(7, 5, 12, 5, lea[2])
    c.rect(11, 3, 13, 4, lea[0])   # gloved knuckles toward the grip
    _selout(c, INK)
    c.save(os.path.join(BASE, "items", "attack_arm.png"))


def render_preview():
    """Zoomed contact sheet (all 8 facings of the baked player) for eyeballing
    without launching the engine. Written next to the other _preview_*.png."""
    skin, outfit, hair = render_human(RANGER, "short")
    skin.tint(SKIN_TONES["tan"])
    hair.tint(HAIR_COLORS["brown"])
    base = Canvas(W, H)
    base.blit(skin, 0, 0, mode="over")
    base.blit(outfit, 0, 0, mode="over")
    base.blit(hair, 0, 0, mode="over")
    base.rim_light(0.5, RIM_WARM)
    _selout(base, P.OUTLINE)
    bg = Canvas(W, H)
    bg.rect(0, 0, W - 1, H - 1, rgb(122, 130, 96))  # grass-ish backdrop
    bg.blit(base, 0, 0, mode="over")
    bg.scaled(5).save(os.path.join(BASE, "_preview_char.png"))


def main():
    save_layered_player()
    save_baked(os.path.join(BASE, "player.png"), RANGER,
               SKIN_TONES["tan"], HAIR_COLORS["brown"], "short")
    save_baked(os.path.join(BASE, "npc_villager.png"), VILLAGER,
               SKIN_TONES["pale"], HAIR_COLORS["auburn"], "long")
    save_wardrobe()
    for fname, pal, skin, hair, style in NAMED_CAST:
        save_baked(os.path.join(BASE, fname), pal, SKIN_TONES[skin],
                   HAIR_COLORS[hair], style)
    save_baked(os.path.join(BASE, "enemy_bandit.png"), BANDIT,
               SKIN_TONES["tan"], HAIR_COLORS["black"], "short")
    save_baked(os.path.join(BASE, "enemies", "enemy_archer.png"), ARCHER,
               SKIN_TONES["brown"], HAIR_COLORS["black"], "short")
    save_baked(os.path.join(BASE, "enemies", "enemy_brute.png"), BRUTE,
               SKIN_TONES["tan"], HAIR_COLORS["black"], "spiky")
    save_withered(os.path.join(BASE, "enemies", "enemy_withered.png"))
    render_vest()
    render_back_shield()
    render_back_bow()
    render_sheath_sword()
    render_attack_arm()
    render_preview()
    print("generated grounded 8-direction character sheets (24x40) + wardrobe + preview")


if __name__ == "__main__":
    main()
