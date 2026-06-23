#!/usr/bin/env python3
"""Segment rig — the remaster's modular HERO character MODEL.

A ground-up rebuild aimed at a *heroic*, grounded-fantasy look (no more blocky
mannequin): taller adventurer proportions, rounded + cel-shaded forms, a flowing
cloak for silhouette, and a leather ranger kit — all posed from a data-driven
skeleton so every facing + walk frame stays aligned, and **fully parameterized**
so the character creator still drives it (skin tone, hair colour, hair style
incl. long hair, and beard).

Model:
  * 4 facings: front (down), side (right; left = mirror), back (up).
  * JOINTS[view] gives rest joint positions; resolve(view, phase) bends the
    skeleton per walk phase (leg stride/lift, torso bob, arm swing).
  * Bare parts and every garment/cloak/weapon draw FROM the live joints, so the
    body and everything worn stay aligned across all frames automatically.
  * compose(view, phase, opts) — opts carries the look (skin/hair/style/beard +
    outfit ramps). anchor(view, phase, name) exposes a joint for gear/FX.

Run:  python3 tools/segment_rig.py   ->  /tmp/segment_turn.png (+ walk strips)
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas, ramp_hue  # noqa: E402
from gen_cast import SKIN, HAIR, CLOTH, LEA, GOLD, SILV, INK, WHITE, BLUSH  # noqa: E402
import gifutil  # noqa: E402

FW, FH = 84, 120
EYE = (96, 132, 92, 255); MOUTH = (150, 86, 78, 255); DARK = (52, 40, 38, 255)
SCAR = (216, 176, 150, 255); WARPAINT = (150, 52, 48, 255)
SMALL = CLOTH["cream"]
BUILD = {"slim": -3, "average": 0, "broad": 5}
# metal + cloth ramps for the wardrobe (light -> dark)
STEEL = [(226, 232, 242, 255), (192, 200, 214, 255), (152, 162, 178, 255), (112, 122, 140, 255), (80, 90, 106, 255)]
IRON  = [(158, 164, 174, 255), (128, 134, 146, 255), (100, 106, 120, 255), (74, 80, 92, 255), (52, 58, 68, 255)]
RANGER_CLOAK = [(86, 108, 92, 255), (66, 86, 72, 255), (50, 68, 56, 255), (36, 52, 42, 255), (26, 38, 30, 255)]
KNIGHT_CLOAK = [(168, 72, 64, 255), (140, 54, 50, 255), (112, 40, 38, 255), (84, 30, 30, 255), (60, 22, 22, 255)]
DLEA = [(120, 94, 66, 255), (98, 74, 50, 255), (78, 58, 38, 255), (58, 42, 28, 255), (40, 28, 18, 255)]   # dark leather
ROGUE_CLOAK = [(78, 80, 88, 255), (60, 62, 70, 255), (46, 48, 56, 255), (34, 36, 42, 255), (24, 26, 30, 255)]
TREE = (96, 150, 96, 255)   # the Children-of-Tera heraldic green

# ============================================================================
# Skeleton — rest joints per view, and the walk that bends them.
# Heroic proportions: small head, long legs, broad shoulders tapering to waist.
# ============================================================================

JOINTS = {
	"front": {
		"head": (42, 20), "neck": (42, 33), "chest": (42, 50), "pelvis": (42, 72),
		"shoulder_l": (28, 39), "shoulder_r": (56, 39),
		"hand_l": (24, 80), "hand_r": (60, 80),
		"hip_l": (35, 73), "hip_r": (49, 73),
		"foot_l": (35, 115), "foot_r": (49, 115),
	},
	"side": {
		"head": (41, 20), "neck": (41, 33), "chest": (41, 50), "pelvis": (41, 72),
		"shoulder_l": (39, 39), "shoulder_r": (44, 39),
		"hand_l": (37, 80), "hand_r": (47, 80),     # _l = far, _r = near (lit)
		"hip_l": (39, 73), "hip_r": (44, 73),
		"foot_l": (38, 115), "foot_r": (45, 115),
	},
	"back": {
		"head": (42, 20), "neck": (42, 33), "chest": (42, 50), "pelvis": (42, 72),
		"shoulder_l": (28, 39), "shoulder_r": (56, 39),
		"hand_l": (24, 80), "hand_r": (60, 80),
		"hip_l": (35, 73), "hip_r": (49, 73),
		"foot_l": (35, 115), "foot_r": (49, 115),
	},
}

# Walk phases: (l_lift, r_lift, bob, swing, near_dx, far_dx).
WALK = [
	(0, 0, 0,  0,  0,  0),
	(0, 3, 1, -2,  5, -5),
	(0, 0, 0,  0,  0,  0),
	(3, 0, 1,  2, -5,  5),
]
# Idle "breathing": the upper body lifts a hair mid-cycle, feet planted.
IDLE_BOB = [0, 1, 1, 0]

def resolve(view, phase, mode="walk"):
	J = {k: list(v) for k, v in JOINTS[view].items()}
	if mode == "idle":
		bob = IDLE_BOB[phase % len(IDLE_BOB)]
		for k in ("head", "neck", "chest", "shoulder_l", "shoulder_r"):
			J[k][1] -= bob                                       # chest + head rise on the breath
		return {k: (int(round(v[0])), int(round(v[1]))) for k, v in J.items()}
	l_lift, r_lift, bob, swing, near_dx, far_dx = WALK[phase]
	for k in ("head", "neck", "chest", "shoulder_l", "shoulder_r", "hand_l", "hand_r", "pelvis"):
		J[k][1] -= bob
	J["hand_r"][1] += swing; J["hand_l"][1] -= swing
	if view == "side":
		J["foot_r"][0] += near_dx; J["foot_l"][0] += far_dx
		J["hand_r"][0] += near_dx // 2; J["hand_l"][0] += far_dx // 2
		J["foot_r"][1] -= max(0, r_lift - 1)
	else:
		J["foot_l"][1] -= l_lift; J["foot_r"][1] -= r_lift
	return {k: (int(round(v[0])), int(round(v[1]))) for k, v in J.items()}

def anchor(view, phase, name):
	return resolve(view, phase)[name]

# ============================================================================
# Look — resolve a customization dict into the ramps the parts draw with.
# ============================================================================

def _ramp_from(col):
	"""A 5-step light->dark hue-shifted ramp from one base colour (for the
	character creator's arbitrary skin/hair colours)."""
	if isinstance(col, (list, tuple)) and len(col) == 5 and isinstance(col[0], tuple):
		return col                                   # already a ramp
	r, g, b = col[0], col[1], col[2]
	return ramp_hue((r, g, b, 255), steps=5)

DEFAULT = {
	"skin": SKIN["tan"], "hair": HAIR["brown"], "hair_style": "short", "beard": "none",
	"build": "average", "mark": "none", "mark_col": WARPAINT, "armor": "ranger",
}

def look(opts=None):
	o = dict(DEFAULT)
	if opts:
		o.update(opts)
	o["skin"] = _ramp_from(o["skin"]); o["hair"] = _ramp_from(o["hair"])
	return o

# ============================================================================
# Wardrobe — equippable armour sets, each a stack of layers keyed off the joints.
# A set names which piece style draws for chest / pauldron / legs / boots / helm,
# the ramps those pieces use, and whether a cloak hangs behind. "ranger" is the
# starter look (the model's default); the rest are equippable tiers.
# ============================================================================

ARMOR = {
	"ranger": {  # leather jerkin + cloak — the starter
		"chest": "jerkin", "pauldron": "leather", "legs": "trousers", "boots": "leather",
		"helm": "none", "cloak": RANGER_CLOAK,
		"body": LEA, "tunic": CLOTH["cream"], "trouser": CLOTH["slate"], "boot": CLOTH["brown"],
	},
	"iron": {  # mail shirt + iron — a soldier
		"chest": "mail", "pauldron": "steel", "legs": "greaves", "boots": "plated",
		"helm": "coif", "cloak": None,
		"body": IRON, "tunic": CLOTH["rust"], "trouser": CLOTH["slate"], "boot": IRON, "metal": IRON,
	},
	"plate": {  # heavy knight plate + tabard + cape — the badass tier
		"chest": "plate", "pauldron": "plate", "legs": "greaves", "boots": "plated",
		"helm": "helm", "cloak": KNIGHT_CLOAK,
		"body": STEEL, "tunic": KNIGHT_CLOAK, "trouser": CLOTH["slate"], "boot": STEEL,
		"metal": STEEL, "tabard": KNIGHT_CLOAK,
	},
	"robe": {  # mage robe + hood — the caster
		"chest": "robe", "pauldron": "none", "legs": "robe", "boots": "leather",
		"helm": "hood", "cloak": None,
		"body": CLOTH["blue"], "tunic": CLOTH["blue"], "trouser": CLOTH["slate"], "boot": CLOTH["brown"],
	},
	"rogue": {  # hooded dark-leather skirmisher
		"chest": "jerkin", "pauldron": "leather", "legs": "trousers", "boots": "leather",
		"helm": "hood", "cloak": ROGUE_CLOAK, "studs": True,
		"body": DLEA, "tunic": CLOTH["brown"], "trouser": CLOTH["slate"], "boot": DLEA,
	},
}

# ============================================================================
# Shading helpers — rounded, cel-shaded limbs (no more single-pixel slabs).
# ============================================================================

def _cap(c, p0, p1, w0, w1, ramp, far=False):
	"""A tapered, shaded limb from p0(width w0) to p1(width w1)."""
	(x0, y0), (x1, y1) = p0, p1
	R = ramp if not far else [ramp[1], ramp[2], ramp[3], ramp[4], ramp[4]]
	n = max(abs(x1 - x0), abs(y1 - y0), 1)
	for i in range(n + 1):
		t = i / n
		x = x0 + (x1 - x0) * t; y = y0 + (y1 - y0) * t; w = w0 + (w1 - w0) * t
		xi = int(round(x)); yi = int(round(y)); wi = max(1, int(round(w)))
		c.rect(xi - wi, yi, xi + wi, yi, R[2])
		c.paint(xi - wi, yi, R[1]); c.paint(xi - wi + 1, yi, R[0])   # lit (upper-left)
		c.paint(xi + wi, yi, R[3])                                   # shaded edge
	c.ellipse(int(round(x1)), int(round(y1)), max(1, int(round(w1))), max(1, int(round(w1))), R[2])

# ============================================================================
# Bare base — skin + smallclothes, posed from J. Customizable skin ramp.
# ============================================================================

def base_legs(c, J, view, SK):
	for side in ("l", "r"):
		hip = J["hip_%s" % side]; foot = J["foot_%s" % side]
		far = (side == "l" and view == "side")
		_cap(c, (hip[0], hip[1]), (foot[0], foot[1] - 5), 4, 3, SK, far)
		c.ellipse(foot[0], foot[1] - 2, 4, 3, SK[2 if not far else 3])           # bare foot
		c.paint(foot[0] - 2, foot[1] - 3, SK[1])
	px, py = J["pelvis"]
	c.rect(px - 8, py - 1, px + 8, py + 7, SMALL[1]); c.rect(px - 8, py - 1, px - 6, py + 7, SMALL[0])
	c.rect(px + 6, py - 1, px + 8, py + 7, SMALL[2]); c.rect(px - 8, py + 6, px + 8, py + 7, SMALL[3])

def base_torso(c, J, view, SK):
	cx, cy = J["chest"]; px, py = J["pelvis"]; sl = J["shoulder_l"]; sr = J["shoulder_r"]
	top = sl[1]
	if view == "side":
		# profile: chest forward up top, tucking back to the waist
		for y in range(top, py + 1):
			t = (y - top) / max(1, py - top)
			fwd = int(round(8 - 3 * t)); back = 6
			c.rect(cx - back, y, cx + fwd, y, SK[2])
			c.rect(cx - back, y, cx - back + 1, y, SK[3])               # shaded back
			c.paint(cx + fwd, y, SK[1])                                 # lit front
		return
	w = (sr[0] - sl[0]) // 2
	for y in range(top, py + 1):
		t = (y - top) / max(1, py - top)
		half = int(round(w * (1.0 - 0.28 * t)))
		half -= max(0, 2 - (y - top))                                  # round shoulder caps
		c.rect(cx - half, y, cx + half, y, SK[2])
		c.rect(cx - half, y, cx - half + 2, y, SK[1]); c.paint(cx - half, y, SK[0])
		c.rect(cx + half - 2, y, cx + half, y, SK[3])
	c.ellipse(cx, cy - 1, w - 5, 6, SK[1])                            # upper-chest light
	if view == "front":
		c.paint(cx, cy + 1, SK[3]); c.paint(cx, cy + 2, SK[3])        # short sternum dimple
		c.ellipse(cx - 6, cy + 1, 3, 2, SK[1]); c.ellipse(cx + 6, cy + 1, 3, 2, SK[1])   # pecs
		c.paint(cx - 5, cy + 7, SK[3]); c.paint(cx + 5, cy + 7, SK[3])
	else:
		c.line(cx, top + 2, cx, py - 2, SK[3])                         # spine
		c.paint(cx - 6, cy, SK[1]); c.paint(cx + 6, cy, SK[1])         # shoulder blades catch light

def base_arms(c, J, view, SK):
	for side in ("l", "r"):
		sh = J["shoulder_%s" % side]; hand = J["hand_%s" % side]
		far = (side == "l" and view == "side")
		_cap(c, sh, (hand[0], hand[1] - 3), 3, 2, SK, far)
		c.ellipse(hand[0], hand[1], 3, 4, SK[2 if not far else 3])               # bare hand
		c.paint(hand[0] - 1, hand[1] - 1, SK[1]); c.paint(hand[0] + 2, hand[1] + 1, SK[3])

# ---- head + face, per view ----

def base_head(c, J, view, SK, HR, style, beard, mark="none", mark_col=WARPAINT):
	hx, hy = J["head"]
	if view == "back":
		_head_back(c, hx, hy, SK, HR, style); return
	if view == "side":
		_head_side(c, hx, hy, SK, HR, style, beard, mark, mark_col); return
	_head_front(c, hx, hy, SK, HR, style, beard, mark, mark_col)

def _neck(c, cx, ny, SK):
	c.rect(cx - 4, ny, cx + 3, ny + 7, SK[3]); c.rect(cx - 4, ny, cx - 3, ny + 7, SK[2])
	c.rect(cx + 2, ny, cx + 3, ny + 7, SK[4])

def _head_front(c, cx, cy, SK, HR, style, beard, mark, mark_col):
	_neck(c, cx, cy + 9, SK)
	c.ellipse(cx, cy, 11, 12, SK[2]); c.ellipse(cx - 3, cy - 2, 7, 7, SK[1])      # face + lit cheek
	c.ellipse(cx, cy + 6, 8, 4, SK[2]); c.ellipse(cx, cy + 10, 5, 2, SK[3])       # jaw/chin
	c.paint(cx - 8, cy + 3, SK[3]); c.paint(cx + 8, cy + 3, SK[3])                # cheekbone shade
	for s in (-1, 1):                                                              # ears
		ex = cx + s * 11; c.line(ex, cy + 1, ex + s * 2, cy - 3, SK[2]); c.paint(ex + s, cy, SK[1])
	# level brows (calm + confident, not a frown) set well above the eyes
	c.line(cx - 8, cy - 5, cx - 4, cy - 5, HR[3]); c.line(cx + 4, cy - 5, cx + 8, cy - 5, HR[3])
	# almond eyes: lid-shadow, sclera, iris, pupil, glint
	for s in (-1, 1):
		ox = cx + s * 5
		c.rect(ox - 2, cy - 2, ox + 2, cy - 2, SK[3])                              # upper lid
		c.rect(ox - 2, cy - 1, ox + 2, cy + 1, WHITE)                              # sclera
		c.rect(ox - 1, cy - 1, ox + 1, cy + 1, EYE); c.paint(ox, cy, DARK)         # iris + pupil
		c.paint(ox - 1, cy - 1, WHITE); c.paint(ox + s * 2, cy + 1, SK[3])         # glint + outer corner
	# nose + calm neutral mouth with a soft lower lip
	c.paint(cx - 1, cy + 2, SK[1]); c.paint(cx - 1, cy + 4, SK[0]); c.paint(cx, cy + 5, SK[3]); c.paint(cx + 1, cy + 4, SK[3])
	c.line(cx - 2, cy + 7, cx + 2, cy + 7, MOUTH); c.paint(cx, cy + 8, SK[1])
	_face_mark(c, cx, cy, mark, mark_col, "front")
	_beard(c, cx, cy, HR, beard, "front")
	_hair_front(c, cx, cy, HR, style)

def _head_side(c, cx, cy, SK, HR, style, beard, mark, mark_col):
	# neck tucked under the skull (no craning), head mass over the spine
	c.rect(cx - 3, cy + 9, cx + 3, cy + 17, SK[3]); c.rect(cx + 2, cy + 9, cx + 3, cy + 17, SK[2])
	c.ellipse(cx, cy, 10, 12, SK[2]); c.ellipse(cx + 2, cy + 1, 7, 8, SK[1])      # skull + lit cheek
	c.rect(cx + 7, cy - 3, cx + 9, cy + 6, SK[1])                                  # face plane
	c.paint(cx + 10, cy + 1, SK[1]); c.paint(cx + 10, cy + 2, SK[2]); c.paint(cx + 9, cy + 3, SK[3])   # nose
	c.paint(cx + 8, cy + 4, SK[2])                                                 # philtrum
	c.ellipse(cx + 3, cy + 9, 5, 3, SK[2]); c.paint(cx + 6, cy + 8, SK[3])         # chin set back
	c.ellipse(cx - 3, cy + 1, 2, 3, SK[2]); c.paint(cx - 3, cy + 1, SK[3])         # ear
	c.line(cx + 4, cy - 4, cx + 8, cy - 4, HR[3])                                  # level brow
	c.rect(cx + 5, cy, cx + 7, cy + 1, WHITE); c.paint(cx + 7, cy, EYE); c.paint(cx + 6, cy, DARK)
	c.line(cx + 5, cy + 7, cx + 8, cy + 7, MOUTH); c.paint(cx + 6, cy + 8, SK[1])
	_face_mark(c, cx, cy, mark, mark_col, "side")
	_beard(c, cx, cy, HR, beard, "side")
	_hair_side(c, cx, cy, HR, style)

def _face_mark(c, cx, cy, mark, col, view):
	"""Optional badass face cosmetic: a scar or a stripe of war-paint."""
	if mark == "scar":
		if view == "side":
			c.line(cx + 6, cy - 3, cx + 8, cy + 4, SCAR); return
		c.line(cx + 4, cy - 4, cx + 6, cy + 3, SCAR); c.paint(cx + 5, cy, SCAR)
	elif mark == "warpaint":
		if view == "side":
			c.rect(cx + 4, cy - 1, cx + 9, cy + 1, col); return
		c.rect(cx - 8, cy - 1, cx + 8, cy + 1, col)                                # band across the eyes
		c.paint(cx, cy - 1, col); c.paint(cx - 9, cy, col); c.paint(cx + 9, cy, col)

def _head_back(c, cx, cy, SK, HR, style):
	c.rect(cx - 4, cy + 9, cx + 3, cy + 14, SK[3])                                 # nape
	c.ellipse(cx, cy, 11, 12, SK[3])                                               # back of skull (shade)
	_hair_back(c, cx, cy, HR, style)

# ---- hair styles (short / long / spiky) + beard ----

def _hair_front(c, cx, cy, HR, style):
	if style == "bald":
		c.rect(cx - 12, cy - 3, cx - 9, cy + 3, HR[3]); c.rect(cx + 9, cy - 3, cx + 12, cy + 3, HR[4])  # side ring
		return
	pulled = style in ("ponytail", "bun")
	c.ellipse(cx, cy - 8, 12, 8, HR[2])                                            # crown
	c.rect(cx - 12, cy - 8, cx - 9, cy + 3, HR[2]); c.rect(cx + 9, cy - 8, cx + 12, cy + 3, HR[3])
	if pulled:                                                                     # slicked back, centre part
		c.line(cx, cy - 13, cx, cy - 6, HR[3]); c.ellipse(cx - 4, cy - 10, 6, 4, HR[1])
		c.rect(cx - 9, cy - 5, cx + 8, cy - 5, HR[3])
	else:
		for hxp in (cx - 7, cx, cx + 7): c.ellipse(hxp, cy - 7, 4, 4, HR[2])       # fringe lumps
		c.rect(cx - 9, cy - 5, cx + 8, cy - 4, HR[3]); c.ellipse(cx + 7, cy - 8, 6, 7, HR[3])
	c.ellipse(cx - 4, cy - 11, 7, 3, HR[1]); c.line(cx - 8, cy - 12, cx + 1, cy - 13, HR[0])  # sheen
	if not pulled:
		c.line(cx - 3, cy - 12, cx - 5, cy - 5, HR[4]); c.line(cx + 4, cy - 11, cx + 3, cy - 5, HR[4])
	if style == "spiky":
		for sx, sh in ((cx - 8, -6), (cx - 3, -8), (cx + 2, -8), (cx + 7, -6)):
			c.line(sx, cy - 8, sx + 1, cy - 8 + sh, HR[2]); c.paint(sx, cy - 8 + sh, HR[1])
	elif style == "long":
		c.rect(cx - 13, cy - 2, cx - 9, cy + 20, HR[2]); c.rect(cx - 13, cy - 2, cx - 12, cy + 20, HR[1])
		c.rect(cx + 9, cy - 2, cx + 13, cy + 20, HR[3]); c.rect(cx + 12, cy - 2, cx + 13, cy + 20, HR[4])
		c.line(cx - 11, cy + 4, cx - 11, cy + 18, HR[3]); c.line(cx + 11, cy + 4, cx + 11, cy + 18, HR[2])
	elif style == "bun":
		c.ellipse(cx, cy - 13, 4, 4, HR[2]); c.ellipse(cx, cy - 13, 3, 3, HR[1])   # top-knot bun peeking up

def _hair_side(c, cx, cy, HR, style):
	if style == "bald":
		c.ellipse(cx - 4, cy - 1, 4, 5, HR[3]); return                            # a wisp over the ear
	pulled = style in ("ponytail", "bun")
	c.ellipse(cx, cy - 8, 11, 8, HR[2]); c.rect(cx - 11, cy - 8, cx - 6, cy + 4, HR[3])
	if pulled:
		c.ellipse(cx - 1, cy - 10, 7, 4, HR[1])
	else:
		c.ellipse(cx + 5, cy - 7, 6, 5, HR[2]); c.paint(cx + 8, cy - 4, HR[3])
	c.ellipse(cx - 3, cy - 11, 6, 3, HR[1]); c.line(cx - 8, cy - 12, cx + 1, cy - 13, HR[0])
	if style == "spiky":
		for sx, sh in ((cx - 6, -6), (cx, -8), (cx + 5, -6)):
			c.line(sx, cy - 8, sx - 1, cy - 8 + sh, HR[2]); c.paint(sx - 1, cy - 8 + sh, HR[1])
	elif style == "long":
		c.rect(cx - 11, cy - 2, cx - 6, cy + 22, HR[2]); c.rect(cx - 11, cy - 2, cx - 10, cy + 22, HR[1])
		c.line(cx - 8, cy + 4, cx - 8, cy + 20, HR[3])
	elif style == "ponytail":                                                     # tail streaming back
		c.rect(cx - 13, cy - 6, cx - 9, cy + 12, HR[2]); c.rect(cx - 13, cy - 6, cx - 12, cy + 12, HR[1])
		c.ellipse(cx - 11, cy + 12, 3, 4, HR[3])
	elif style == "bun":
		c.ellipse(cx - 9, cy - 6, 4, 4, HR[2]); c.ellipse(cx - 9, cy - 6, 3, 3, HR[1])

def _hair_back(c, cx, cy, HR, style):
	if style == "bald":
		c.rect(cx - 12, cy - 2, cx - 9, cy + 4, HR[3]); c.rect(cx + 9, cy - 2, cx + 12, cy + 4, HR[4]); return
	pulled = style in ("ponytail", "bun")
	c.ellipse(cx, cy - 4, 12, 13, HR[2]); c.ellipse(cx, cy - 8, 12, 9, HR[2])
	c.rect(cx - 12, cy - 8, cx - 8, cy + 6, HR[2]); c.rect(cx + 8, cy - 8, cx + 12, cy + 6, HR[3])
	if not pulled:
		for h in (cx - 8, cx - 3, cx + 2, cx + 7): c.line(h, cy - 8, h, cy + 6, HR[3])
	c.ellipse(cx - 4, cy - 11, 8, 3, HR[1]); c.line(cx - 8, cy - 12, cx + 2, cy - 13, HR[0])
	if style == "spiky":
		for sx in (cx - 8, cx - 3, cx + 2, cx + 7):
			c.line(sx, cy - 9, sx, cy - 14, HR[2]); c.paint(sx, cy - 14, HR[1])
	elif style == "long":
		c.rect(cx - 12, cy + 4, cx + 12, cy + 24, HR[2])
		c.rect(cx - 12, cy + 4, cx - 10, cy + 24, HR[1]); c.rect(cx + 10, cy + 4, cx + 12, cy + 24, HR[3])
		for h in (cx - 7, cx, cx + 7): c.line(h, cy + 6, h, cy + 23, HR[3])
	elif style == "ponytail":                                                     # a bound tail down the spine
		c.rect(cx - 2, cy - 9, cx + 2, cy - 7, HR[4])                             # tie
		c.rect(cx - 3, cy + 6, cx + 3, cy + 26, HR[2]); c.rect(cx - 3, cy + 6, cx - 2, cy + 26, HR[1])
		c.rect(cx + 2, cy + 6, cx + 3, cy + 26, HR[3]); c.ellipse(cx, cy + 26, 3, 4, HR[3])
	elif style == "bun":
		c.ellipse(cx, cy - 8, 5, 5, HR[2]); c.ellipse(cx - 1, cy - 9, 3, 3, HR[1]); c.line(cx - 4, cy - 8, cx + 4, cy - 8, HR[4])

def _beard(c, cx, cy, HR, beard, view):
	if beard == "none":
		return
	if view == "side":
		if beard in ("full", "stubble"):
			c.ellipse(cx + 4, cy + 7, 5, 4, HR[3])
		c.paint(cx + 6, cy + 6, HR[2]); c.paint(cx + 7, cy + 8, HR[3]); return
	if beard == "stubble":
		for bx, by in ((cx-4,cy+8),(cx-1,cy+9),(cx+2,cy+9),(cx+4,cy+8),(cx,cy+10)): c.paint(bx, by, HR[3])
	elif beard == "goatee":
		c.ellipse(cx, cy + 9, 3, 3, HR[2]); c.paint(cx, cy + 11, HR[3])
	elif beard == "full":
		for yy in range(cy + 5, cy + 12):
			for xx in range(cx - 8, cx + 9):
				if (xx - cx) ** 2 / 64 + (yy - (cy + 8)) ** 2 / 16 <= 1.0: c.paint(xx, yy, HR[2])
		c.rect(cx + 4, cy + 6, cx + 8, cy + 11, HR[3]); c.line(cx - 2, cy + 7, cx + 2, cy + 7, MOUTH)

# ============================================================================
# Apparel layers — the heroic ranger kit, riding the same joints.
# ============================================================================

def cloak_back(c, J, view, CL):
	"""A flowing cloak BEHIND the body — the silhouette win. Drawn first."""
	sl = J["shoulder_l"]; sr = J["shoulder_r"]; py = J["pelvis"]
	hem = py[1] + 32
	if view == "side":
		bx = J["chest"][0] - 7
		for y in range(sl[1] - 1, hem):
			t = (y - sl[1]) / max(1, hem - sl[1])
			w = int(round(2 + 7 * t)); sway = int(round(3 * t))
			c.rect(bx - w - sway, y, bx + 2 - sway, y, CL[2])
			c.paint(bx - w - sway, y, CL[3]); c.paint(bx + 2 - sway, y, CL[1])
		return
	cx = J["chest"][0]
	for y in range(sl[1] - 1, hem):
		t = (y - sl[1]) / max(1, hem - sl[1])
		half = int(round((sr[0] - sl[0]) / 2 + 1 + 7 * t))
		c.rect(cx - half, y, cx + half, y, CL[2])
		c.rect(cx - half, y, cx - half + 2, y, CL[3]); c.rect(cx + half - 1, y, cx + half, y, CL[3])
	if view == "back":
		c.line(cx, sl[1], cx, hem - 1, CL[3])                          # centre seam
		for fx in (cx - 10, cx + 10): c.line(fx, sl[1] + 6, fx, hem - 2, CL[3])
		c.ellipse(cx, sl[1] + 2, (sr[0] - sl[0]) // 2, 5, CL[1])       # lit upper back
	else:
		for fx in (cx - 13, cx + 13): c.line(fx, sl[1] + 8, fx, hem - 2, CL[3])  # side folds peeking

def garment_trousers(c, J, view, TR):
	for side in ("l", "r"):
		hip = J["hip_%s" % side]; foot = J["foot_%s" % side]
		far = (side == "l" and view == "side")
		_cap(c, (hip[0], hip[1] - 1), (foot[0], foot[1] - 7), 5, 4, TR, far)
	px, py = J["pelvis"]
	c.rect(px - 9, py - 2, px + 9, py + 7, TR[1]); c.rect(px - 9, py - 2, px - 7, py + 7, TR[0])
	c.rect(px + 7, py - 2, px + 9, py + 7, TR[2]); c.rect(px - 9, py + 6, px + 9, py + 7, TR[3])

def garment_boots(c, J, view, BT):
	for side in ("l", "r"):
		fx, fy = J["foot_%s" % side]
		c.rect(fx - 5, fy - 16, fx + 5, fy, BT[1]); c.rect(fx - 5, fy - 16, fx - 3, fy, BT[0])
		c.rect(fx + 3, fy - 14, fx + 6, fy, BT[2]); c.rect(fx - 6, fy - 2, fx + 7, fy, BT[3])
		c.rect(fx - 6, fy - 16, fx + 6, fy - 14, BT[0])                # turned cuff
		c.line(fx - 3, fy - 8, fx + 3, fy - 8, BT[3])

def _sleeve(c, J, side, view, ramp, SK, cuff=LEA):
	sh = J["shoulder_%s" % side]; hand = J["hand_%s" % side]
	far = (side == "l" and view == "side")
	_cap(c, sh, (hand[0], hand[1] - 5), 4, 3, ramp, far)
	if cuff is not None:
		c.rect(hand[0] - 4, hand[1] - 5, hand[0] + 4, hand[1] - 2, cuff[2])        # bracer/gauntlet cuff
		c.rect(hand[0] - 4, hand[1] - 5, hand[0] + 4, hand[1] - 5, cuff[1])
	c.ellipse(hand[0], hand[1], 3, 4, SK[2 if not far else 3])                     # bare hand
	c.paint(hand[0] - 1, hand[1] - 1, SK[1]); c.paint(hand[0] + 2, hand[1] + 1, SK[3])

def garment_jerkin(c, J, view, JK, TU, SK, studs=False):
	"""Leather jerkin over an undertunic, with belt, collar + one pauldron.
	`studs` strews rivets across the chest (the rogue's studded leather)."""
	cx, cy = J["chest"]; px, py = J["pelvis"]; sl = J["shoulder_l"]; sr = J["shoulder_r"]
	_sleeve(c, J, "l", view, JK, SK, cuff=JK)                                      # far sleeve first
	if view == "side":
		for y in range(sl[1], py + 4):
			t = (y - sl[1]) / max(1, py - sl[1]); fwd = int(round(8 - 2 * t))
			c.rect(cx - 7, y, cx + fwd, y, JK[1]); c.paint(cx + fwd, y, JK[0]); c.paint(cx - 7, y, JK[3])
		for i in range(20): c.paint(cx + 6 - i // 4, sl[1] + i, LEA[2])           # strap
	else:
		hw = (sr[0] - sl[0]) // 2 + 1
		for y in range(sl[1], py + 4):
			t = (y - sl[1]) / max(1, py - sl[1]); half = int(round(hw * (1.0 - 0.22 * t)))
			c.rect(cx - half, y, cx + half, y, JK[1])
			c.rect(cx - half, y, cx - half + 2, y, JK[0]); c.rect(cx + half - 1, y, cx + half, y, JK[2])
		# undertunic V at the collar
		c.line(cx - 4, sl[1], cx, cy - 4, TU[1]); c.line(cx + 4, sl[1], cx, cy - 4, TU[1])
		c.rect(cx - 3, sl[1] - 1, cx + 3, sl[1], TU[0])
		if view == "front":
			c.line(cx - hw + 3, cy - 4, cx - hw + 5, cy + 8, JK[2])               # lapel folds
			c.line(cx + hw - 3, cy - 4, cx + hw - 5, cy + 8, JK[2])
			i = 0                                                                 # baldric strap
			while sl[1] + 2 + i < py:
				c.paint(cx - 12 + i, sl[1] + 2 + i, LEA[2]); c.paint(cx - 11 + i, sl[1] + 2 + i, LEA[3]); i += 1
		else:
			c.line(cx, sl[1], cx, py, JK[2])
		if studs:
			for sx in (cx - 7, cx, cx + 7):
				c.paint(sx, cy - 2, SILV[1]); c.paint(sx, cy + 4, SILV[1])
			for sx in (cx - 4, cx + 4): c.paint(sx, cy + 1, SILV[1])
	# belt
	c.rect(sl[0] - 1, py - 3, sr[0] + 1, py + 1, LEA[3]); c.rect(sl[0] - 1, py - 3, sr[0] + 1, py - 3, LEA[2])
	c.rect(cx - 3, py - 4, cx + 3, py + 2, GOLD[1]); c.paint(cx + 2, py, GOLD[2]); c.paint(cx - 2, py - 3, GOLD[0])
	_sleeve(c, J, "r", view, JK, SK, cuff=JK)                                      # near sleeve last
	# fitted leather pauldrons with a steel stud
	def _pauldron(px, py, lit):
		b = JK if lit else [JK[1], JK[2], JK[3], JK[4], JK[4]]
		c.ellipse(px, py - 1, 5, 4, b[2]); c.ellipse(px, py - 2, 4, 2, b[1])
		c.line(px - 5, py + 1, px + 5, py + 2, b[3])                               # lower rim shadow
		c.paint(px, py - 3, b[0]); c.paint(px + (1 if lit else -1), py - 1, SILV[1])  # steel stud
	_pauldron(J["shoulder_r"][0], J["shoulder_r"][1], True)
	if view != "side":
		_pauldron(sl[0], sl[1], False)

def cloak_collar(c, J, view, CL):
	"""The cloak's mantle/collar over the shoulders, clasped at the throat."""
	sl = J["shoulder_l"]; sr = J["shoulder_r"]; nx = J["neck"][0]; ny = J["neck"][1]
	if view == "side":
		c.ellipse(nx - 4, ny + 3, 6, 5, CL[2]); c.paint(nx - 7, ny + 4, CL[3]); return
	c.ellipse(nx, ny + 4, (sr[0] - sl[0]) // 2 - 1, 6, CL[2])
	c.rect(sl[0] + 2, ny + 1, sr[0] - 2, ny + 4, CL[2])
	c.rect(sl[0] + 2, ny + 1, sl[0] + 4, ny + 6, CL[1]); c.rect(sr[0] - 4, ny + 1, sr[0] - 2, ny + 6, CL[3])
	if view == "front":
		c.disc(nx, ny + 3, 2, GOLD[1]); c.paint(nx, ny + 2, GOLD[0])              # clasp

# ---- chest variants (each draws its own far+near sleeves) ----

def _belt(c, J, view, buckle=GOLD):
	sl = J["shoulder_l"]; sr = J["shoulder_r"]; cx, py = J["chest"][0], J["pelvis"][1]
	c.rect(sl[0] - 1, py - 3, sr[0] + 1, py + 1, LEA[3]); c.rect(sl[0] - 1, py - 3, sr[0] + 1, py - 3, LEA[2])
	c.rect(cx - 3, py - 4, cx + 3, py + 2, buckle[1]); c.paint(cx + 2, py, buckle[2]); c.paint(cx - 2, py - 3, buckle[0])

def _mail_stipple(c, x0, y0, x1, y1, M, skip=None):
	for yy in range(y0, y1, 2):
		for xx in range(x0 + (yy % 2), x1, 2):
			if skip and skip[0] <= xx <= skip[1] and skip[2] <= yy <= skip[3]:
				continue
			c.paint(xx, yy, M[3])

def chest_mail(c, J, view, SET, SK):
	M = SET["metal"]; cx, cy = J["chest"]; px, py = J["pelvis"]; sl = J["shoulder_l"]; sr = J["shoulder_r"]
	_sleeve(c, J, "l", view, M, SK, cuff=M)
	if view == "side":
		for y in range(sl[1], py + 4):
			t = (y - sl[1]) / max(1, py - sl[1]); fwd = int(round(8 - 2 * t))
			c.rect(cx - 7, y, cx + fwd, y, M[2]); c.paint(cx + fwd, y, M[1]); c.paint(cx - 7, y, M[3])
		_mail_stipple(c, cx - 6, sl[1] + 1, cx + 7, py + 3, M)
	else:
		hw = (sr[0] - sl[0]) // 2 + 1
		for y in range(sl[1], py + 4):
			t = (y - sl[1]) / max(1, py - sl[1]); half = int(round(hw * (1.0 - 0.20 * t)))
			c.rect(cx - half, y, cx + half, y, M[2])
			c.rect(cx - half, y, cx - half + 2, y, M[1]); c.rect(cx + half - 1, y, cx + half, y, M[3])
		_mail_stipple(c, cx - hw + 2, sl[1] + 1, cx + hw - 1, py + 3, M)
		c.rect(cx - 4, sl[1] - 2, cx + 4, sl[1], LEA[2])                           # leather gorget
	_belt(c, J, view, GOLD)
	_sleeve(c, J, "r", view, M, SK, cuff=M)

def chest_plate(c, J, view, SET, SK):
	M = SET["metal"]; TAB = SET.get("tabard"); cx, cy = J["chest"]; px, py = J["pelvis"]; sl = J["shoulder_l"]; sr = J["shoulder_r"]
	_sleeve(c, J, "l", view, M, SK, cuff=M)
	if view == "side":
		for y in range(sl[1], py + 2):
			t = (y - sl[1]) / max(1, py - sl[1]); fwd = int(round(9 - 2 * t))
			c.rect(cx - 7, y, cx + fwd, y, M[2]); c.paint(cx + fwd, y, M[0]); c.paint(cx + fwd - 1, y, M[1]); c.paint(cx - 7, y, M[3])
		c.rect(cx - 7, py, cx + 7, py + 6, M[2]); c.paint(cx + 7, py + 3, M[1])    # fauld
	else:
		hw = (sr[0] - sl[0]) // 2 + 2
		for y in range(sl[1], py + 1):
			t = (y - sl[1]) / max(1, py - sl[1]); half = int(round(hw * (1.0 - 0.16 * t)))
			c.rect(cx - half, y, cx + half, y, M[2])
			c.rect(cx - half, y, cx - half + 2, y, M[1]); c.rect(cx + half - 1, y, cx + half, y, M[3])
		c.ellipse(cx - 6, cy, 4, 5, M[1]); c.ellipse(cx + 6, cy, 4, 5, M[2])       # pec plates
		c.line(cx, sl[1] + 1, cx, py - 1, M[1]); c.rect(cx - 6, sl[1] - 2, cx + 6, sl[1] - 1, M[0])  # ridge + gorget
		for fx in (cx - 9, cx, cx + 9):                                           # fauld lames
			c.rect(fx - 4, py - 1, fx + 4, py + 6, M[2]); c.rect(fx - 4, py + 5, fx + 4, py + 6, M[4]); c.rect(fx - 4, py - 1, fx - 3, py + 6, M[1])
		if TAB and view == "front":                                               # tabard over the plate
			c.rect(cx - 4, cy - 3, cx + 4, py + 9, TAB[1]); c.rect(cx - 4, cy - 3, cx - 3, py + 9, TAB[0]); c.rect(cx + 3, cy - 3, cx + 4, py + 9, TAB[2])
			c.paint(cx, cy + 2, TAB[2])
	_sleeve(c, J, "r", view, M, SK, cuff=M)

def chest_robe(c, J, view, SET, SK):
	CL = SET["body"]; cx, cy = J["chest"]; px, py = J["pelvis"]; sl = J["shoulder_l"]; sr = J["shoulder_r"]
	hem = py + 34
	_sleeve(c, J, "l", view, CL, SK, cuff=None)
	if view == "side":
		c.rect(cx - 7, sl[1], cx + 8, hem, CL[1]); c.rect(cx + 6, sl[1], cx + 8, hem, CL[0]); c.rect(cx - 7, sl[1], cx - 5, hem, CL[3])
	else:
		hw = (sr[0] - sl[0]) // 2 + 1
		for y in range(sl[1], hem):
			t = max(0.0, (y - py) / max(1, hem - py)); half = int(round(hw + 6 * t))
			c.rect(cx - half, y, cx + half, y, CL[1])
			c.rect(cx - half, y, cx - half + 2, y, CL[0]); c.rect(cx + half - 1, y, cx + half, y, CL[2])
		c.rect(cx - 1, sl[1], cx + 1, hem - 2, GOLD[2])                            # gold placket trim
		if view == "front":
			c.line(cx - hw, cy, cx - hw + 1, hem - 3, CL[2]); c.line(cx + hw, cy, cx + hw - 1, hem - 3, CL[2])
		else:
			c.line(cx, sl[1], cx, hem - 2, CL[2])
	c.rect(sl[0], py - 2, sr[0], py, CLOTH["brown"][2])                            # rope belt
	_sleeve(c, J, "r", view, CL, SK, cuff=None)

# ---- pauldrons / legs / boots / helm ----

def pauldrons(c, J, view, M, big):
	def one(px, py, lit):
		r = M if lit else [M[1], M[2], M[3], M[4], M[4]]
		if big:
			c.ellipse(px, py - 1, 7, 5, r[2]); c.ellipse(px, py - 3, 7, 3, r[1])
			c.line(px - 7, py + 2, px + 7, py + 3, r[3]); c.ellipse(px, py + 2, 7, 2, r[2]); c.paint(px, py - 4, r[0])
		else:
			c.ellipse(px, py - 1, 6, 4, r[2]); c.ellipse(px, py - 2, 5, 2, r[1])
			c.line(px - 6, py + 1, px + 6, py + 2, r[3]); c.paint(px, py - 3, r[0])
	one(J["shoulder_r"][0], J["shoulder_r"][1], True)
	if view != "side":
		one(J["shoulder_l"][0], J["shoulder_l"][1], False)

def plate_greaves(c, J, view, M):
	for side in ("l", "r"):
		hip = J["hip_%s" % side]; foot = J["foot_%s" % side]; far = (side == "l" and view == "side")
		r = M if not far else [M[1], M[2], M[3], M[4], M[4]]
		midy = (hip[1] + foot[1]) // 2
		_cap(c, (foot[0], midy), (foot[0], foot[1] - 8), 5, 4, r, far)            # shin plate
		c.ellipse(foot[0], midy, 5, 3, r[1])                                       # knee cop
		c.ellipse(hip[0], hip[1] + 5, 5, 4, r[2])                                  # thigh plate

def boot_plate(c, J, view, M):
	for side in ("l", "r"):
		fx, fy = J["foot_%s" % side]
		c.rect(fx - 6, fy - 3, fx + 7, fy, M[2]); c.rect(fx - 6, fy - 3, fx + 7, fy - 3, M[1])  # sabaton

def draw_outfit(c, J, view, SET, SK):
	chest = SET["chest"]
	if chest == "jerkin":                                                         # ranger / rogue leather kit
		garment_trousers(c, J, view, SET["trouser"]); garment_boots(c, J, view, SET["boot"])
		garment_jerkin(c, J, view, SET["body"], SET["tunic"], SK, SET.get("studs", False))
		return
	# legs
	if SET["legs"] == "greaves":
		garment_trousers(c, J, view, SET["trouser"]); plate_greaves(c, J, view, SET["metal"])
	elif SET["legs"] != "robe":
		garment_trousers(c, J, view, SET["trouser"])
	# boots
	garment_boots(c, J, view, SET["boot"])
	if SET["boots"] == "plated":
		boot_plate(c, J, view, SET["metal"])
	# chest (+ its sleeves)
	{"mail": chest_mail, "plate": chest_plate, "robe": chest_robe}[chest](c, J, view, SET, SK)
	# pauldrons
	if SET["pauldron"] == "steel":
		pauldrons(c, J, view, SET["metal"], big=False)
	elif SET["pauldron"] == "plate":
		pauldrons(c, J, view, SET["metal"], big=True)

def draw_helm(c, J, view, SET):
	h = SET["helm"]
	if h == "none":
		return
	hx, hy = J["head"]
	if h == "coif":
		_helm_coif(c, hx, hy, view, SET["metal"])
	elif h == "helm":
		_helm_iron(c, hx, hy, view, SET["metal"])
	elif h == "hood":
		_helm_hood(c, hx, hy, view, SET["body"])

def _helm_coif(c, hx, hy, view, M):
	if view == "back":
		c.ellipse(hx, hy - 2, 12, 13, M[2]); c.ellipse(hx, hy - 7, 12, 8, M[1]); _mail_stipple(c, hx - 11, hy - 9, hx + 11, hy + 9, M); return
	if view == "side":
		c.ellipse(hx, hy - 1, 11, 13, M[2]); c.rect(hx - 11, hy - 2, hx - 3, hy + 11, M[2]); c.ellipse(hx, hy - 6, 11, 7, M[1])
		_mail_stipple(c, hx - 10, hy - 7, hx + 4, hy + 11, M); return
	c.ellipse(hx, hy - 4, 12, 9, M[2]); c.ellipse(hx, hy - 7, 12, 6, M[1])         # crown
	c.rect(hx - 12, hy - 4, hx - 8, hy + 10, M[2]); c.rect(hx + 8, hy - 4, hx + 12, hy + 10, M[3])  # side falls
	c.rect(hx - 8, hy + 8, hx + 8, hy + 11, M[2]); c.rect(hx - 9, hy - 4, hx + 9, hy - 3, M[3])     # aventail + brow band
	_mail_stipple(c, hx - 11, hy - 6, hx + 11, hy + 11, M, skip=(hx - 7, hx + 7, hy - 2, hy + 8))

def _helm_iron(c, hx, hy, view, M):
	if view == "back":
		c.ellipse(hx, hy - 3, 12, 12, M[2]); c.ellipse(hx, hy - 7, 12, 7, M[1]); c.rect(hx - 11, hy + 4, hx + 11, hy + 9, M[2]); c.line(hx, hy - 8, hx, hy + 8, M[3]); return
	if view == "side":
		c.ellipse(hx - 1, hy - 3, 12, 12, M[2]); c.ellipse(hx - 1, hy - 7, 11, 7, M[1])
		c.rect(hx - 12, hy - 2, hx - 6, hy + 8, M[2]); c.rect(hx + 8, hy - 3, hx + 9, hy + 6, M[1]); c.disc(hx - 2, hy - 8, 2, M[0]); return
	c.ellipse(hx, hy - 4, 12, 9, M[2]); c.ellipse(hx, hy - 7, 12, 6, M[1])         # dome over the hair
	c.rect(hx - 12, hy - 4, hx - 9, hy + 8, M[2]); c.rect(hx + 9, hy - 4, hx + 12, hy + 8, M[3])    # cheek plates
	c.rect(hx - 10, hy - 3, hx + 10, hy - 2, M[3]); c.rect(hx - 1, hy - 2, hx + 1, hy + 6, M[1])    # brow rim + nasal guard
	c.disc(hx, hy - 8, 2, M[0]); c.paint(hx, hy - 10, M[0])                        # crest

def _helm_hood(c, hx, hy, view, CL):
	if view == "back":
		c.ellipse(hx, hy - 2, 13, 14, CL[2]); c.ellipse(hx, hy - 7, 13, 9, CL[1]); return
	if view == "side":
		c.ellipse(hx, hy - 2, 12, 13, CL[2]); c.rect(hx - 12, hy - 2, hx - 3, hy + 12, CL[2]); c.paint(hx + 9, hy + 1, CL[3]); return
	c.ellipse(hx, hy - 5, 13, 9, CL[2]); c.ellipse(hx - 2, hy - 4, 8, 5, CL[1])    # peak
	c.rect(hx - 13, hy - 3, hx - 9, hy + 12, CL[2]); c.rect(hx + 9, hy - 3, hx + 13, hy + 12, CL[3])  # side falls
	c.rect(hx - 9, hy - 3, hx + 9, hy - 2, CL[3])                                  # inner shadow under the rim
	for xx in range(hx - 7, hx + 8): c.paint(xx, hy - 1, CL[3])                    # shade the upper face

# ---- weapons (held at rest in the main hand) ----

WEAPONS = {
	"sword":      {"type": "sword", "blade": STEEL, "hilt": LEA},
	"axe":        {"type": "axe",   "blade": STEEL, "haft": LEA},
	"bow":        {"type": "bow",   "wood": LEA},
	"staff":      {"type": "staff", "wood": LEA, "gem": (120, 186, 214, 255)},
	"dagger":     {"type": "dagger", "blade": STEEL, "hilt": DLEA},
	"mace":       {"type": "mace",  "head": IRON, "haft": LEA},
	"spear":      {"type": "spear", "head": STEEL, "haft": LEA},
	"greatsword": {"type": "greatsword", "blade": STEEL, "hilt": LEA},
}

def held_weapon(c, J, view, wid):
	w = WEAPONS.get(wid) if isinstance(wid, str) else wid
	if w is None:
		return
	hx, hy = J["hand_r"]; t = w.get("type", "sword")
	if t in ("sword", "dagger", "greatsword"):
		bl = w["blade"]; hi = w["hilt"]
		big = (t == "greatsword"); tip = 10 if t == "dagger" else (26 if big else 20)
		gw = 4 if not big else 5
		c.rect(hx - 1, hy - 6, hx + 1, hy - 1, hi[1]); c.paint(hx, hy - 7, hi[0])      # grip
		if big: c.disc(hx, hy - 7, 2, GOLD[1])                                         # pommel
		c.rect(hx - gw, hy, hx + gw, hy + 1, hi[2]); c.paint(hx - gw, hy, hi[1]); c.paint(hx + gw, hy, hi[1])  # crossguard
		for i in range(2, tip):
			ww = (3 if big else 2) if i < tip - 5 else (1 if i < tip - 2 else 0)
			c.rect(hx - ww, hy + i, hx + ww, hy + i, bl[2]); c.paint(hx - ww, hy + i, bl[0])
			if ww > 1: c.paint(hx + ww, hy + i, bl[3])
	elif t == "axe":
		hf = w["haft"]; bl = w["blade"]
		c.rect(hx - 1, hy - 8, hx + 1, hy + 20, hf[2]); c.rect(hx - 1, hy - 8, hx, hy + 20, hf[1])   # haft
		c.ellipse(hx + 5, hy - 3, 5, 7, bl[2]); c.rect(hx + 1, hy - 8, hx + 5, hy + 2, bl[2])        # blade
		c.paint(hx + 9, hy - 3, bl[0]); c.rect(hx + 1, hy - 8, hx + 5, hy - 7, bl[1])
	elif t == "mace":
		hf = w["haft"]; hd = w["head"]
		c.rect(hx - 1, hy - 4, hx + 1, hy + 20, hf[2]); c.rect(hx - 1, hy - 4, hx, hy + 20, hf[1])   # haft
		c.disc(hx, hy - 8, 4, hd[2]); c.paint(hx - 2, hy - 10, hd[1])                                # flanged head
		for dx, dy in ((-5, -8), (5, -8), (0, -13), (-3, -4), (3, -4)): c.paint(hx + dx, hy + dy, hd[3])
	elif t == "spear":
		hf = w["haft"]; hd = w["head"]
		c.rect(hx - 1, hy - 18, hx + 1, hy + 22, hf[2]); c.rect(hx - 1, hy - 18, hx, hy + 22, hf[1]) # long haft
		c.ellipse(hx, hy - 24, 3, 6, hd[2]); c.paint(hx, hy - 29, hd[0]); c.paint(hx - 2, hy - 24, hd[1])  # leaf head
	elif t == "bow":
		wd = w["wood"]
		for i in range(-14, 15):
			bx = hx + 6 - abs(i) * abs(i) // 22
			c.paint(bx, hy + i, wd[2]); c.paint(bx + 1, hy + i, wd[1])
		c.line(hx + 6, hy - 14, hx + 6, hy + 14, (232, 228, 218, 255))                                # string
	elif t == "staff":
		wd = w["wood"]; gem = w["gem"]
		c.rect(hx - 1, hy - 16, hx + 1, hy + 18, wd[2]); c.rect(hx - 1, hy - 16, hx, hy + 18, wd[1])
		c.disc(hx, hy - 18, 3, gem); c.paint(hx - 1, hy - 19, (220, 240, 248, 255))                   # crystal head

# ---- shields (off-hand) + heraldic emblems ----

SHIELDS = {
	"buckler": {"shape": "round", "face": IRON,  "boss": STEEL, "r": 6},
	"round":   {"shape": "round", "face": LEA,   "boss": STEEL, "rim": IRON, "r": 8},
	"heater":  {"shape": "heater", "face": STEEL, "trim": GOLD, "emblem": "tree", "ecol": TREE},
	"kite":    {"shape": "kite",  "face": IRON,  "trim": STEEL, "emblem": "chevron", "ecol": GOLD[1]},
}

def _emblem(c, cx, cy, kind, col):
	if kind == "tree":                                                            # Children-of-Tera crest
		c.rect(cx - 1, cy, cx + 1, cy + 5, (96, 70, 46, 255))                      # trunk
		c.disc(cx, cy - 2, 4, col); c.disc(cx - 3, cy, 2, col); c.disc(cx + 3, cy, 2, col)
		c.paint(cx - 1, cy - 3, (200, 230, 190, 255))
	elif kind == "chevron":
		c.line(cx - 4, cy + 3, cx, cy - 2, col); c.line(cx, cy - 2, cx + 4, cy + 3, col)
		c.line(cx - 4, cy + 5, cx, cy, col); c.line(cx, cy, cx + 4, cy + 5, col)

def held_shield(c, J, view, sid):
	s = SHIELDS.get(sid) if isinstance(sid, str) else sid
	if s is None:
		return
	hx, hy = J["hand_l"]; F = s["face"]; cy = hy - 6
	if view == "side":                                                            # off-hand is behind: a thin edge
		ex = hx - 4
		c.rect(ex - 1, cy - 9, ex + 1, cy + 11, F[3]); c.rect(ex - 1, cy - 9, ex, cy + 11, F[2]); return
	if view == "back":                                                            # we see the boards + arm straps
		c.ellipse(hx, cy, 8, 11, F[3]); c.ellipse(hx, cy, 7, 10, F[2])
		c.rect(hx - 5, cy - 2, hx + 5, cy, LEA[3]); c.rect(hx - 5, cy + 4, hx + 5, cy + 6, LEA[3]); return
	shape = s["shape"]
	if shape == "round":
		r = s["r"]
		c.ellipse(hx, cy, r, r + 2, F[2]); c.ellipse(hx, cy, r, r + 2, s.get("rim", F)[3], fill=False)
		c.ellipse(hx - 2, cy - 2, r - 3, r - 2, F[1])                              # lit face
		c.disc(hx, cy, 2, s["boss"][1]); c.paint(hx - 1, cy - 1, s["boss"][0])     # central boss
	else:                                                                         # heater / kite heraldic shield
		tall = (shape == "kite")
		top = cy - (12 if tall else 9); bot = cy + (14 if tall else 11)
		for y in range(top, bot + 1):
			t = (y - top) / max(1, bot - top)
			half = int(round((7 if not tall else 6) * (1.0 - max(0.0, (t - 0.45) / 0.55) ** 1.5)))
			if half < 1:
				continue
			c.rect(hx - half, y, hx + half, y, F[2])
			c.rect(hx - half, y, hx - half + 1, y, F[1]); c.paint(hx + half, y, F[3])
		trim = s.get("trim", F)
		c.line(hx - 6, top + 1, hx + 6, top + 1, trim[1])                          # top trim
		if s.get("emblem"):
			_emblem(c, hx, cy - 1, s["emblem"], s.get("ecol", GOLD[0]))

# ---- stowed gear (worn on the body when not drawn) ----

BACK_WEAPONS = {"greatsword", "spear", "bow", "staff"}   # slung across the back; the rest ride a hip scabbard

def stow_shield(c, J, view, sid):
	"""A shield slung on the back: full + emblem from behind, a rim peeking past
	the body from the front/side."""
	s = SHIELDS.get(sid) if isinstance(sid, str) else sid
	if s is None:
		return
	F = s["face"]; cx = J["chest"][0]; cy = J["chest"][1] + 2
	if view == "side":
		bx = cx - 8
		c.rect(bx - 1, cy - 9, bx + 1, cy + 10, F[3]); c.rect(bx - 1, cy - 9, bx, cy + 10, F[2]); return
	if s.get("shape", "round") == "round":
		r = s.get("r", 8)
		c.ellipse(cx, cy, r, r + 2, F[2]); c.ellipse(cx - 1, cy - 1, r - 2, r, F[1]); c.disc(cx, cy, 2, s["boss"][1])
	else:
		top = cy - 9; bot = cy + 11
		for y in range(top, bot + 1):
			t = (y - top) / max(1, bot - top); half = int(round(7 * (1.0 - max(0.0, (t - 0.45) / 0.55) ** 1.5)))
			if half < 1:
				continue
			c.rect(cx - half, y, cx + half, y, F[2]); c.rect(cx - half, y, cx - half + 1, y, F[1])
	if view == "back" and s.get("emblem"):
		_emblem(c, cx, cy - 1, s["emblem"], s.get("ecol", GOLD[0]))

def stow_weapon_back(c, J, view, wid):
	"""A two-hander / bow / staff slung diagonally across the back (hilt over the
	right shoulder)."""
	w = WEAPONS.get(wid) if isinstance(wid, str) else wid
	if w is None:
		return
	t = w.get("type"); cx, cy = J["chest"]; sl = J["shoulder_l"][0]; sr = J["shoulder_r"][0]
	if view == "side":
		bx = cx - 7
		c.rect(bx - 1, cy - 12, bx + 1, cy + 14, LEA[2]); c.rect(bx - 1, cy - 12, bx, cy + 14, LEA[1]); return
	if t == "bow":
		bx = cx if view == "back" else sl - 1
		for i in range(-14, 15):
			xx = bx - abs(i) * abs(i) // 24
			c.paint(xx, cy + i, LEA[2]); c.paint(xx + 1, cy + i, LEA[1])
		c.line(bx + 1, cy - 13, bx + 1, cy + 13, (224, 220, 208, 255)); return
	x0, y0 = sl - 1, cy + 16; x1, y1 = sr + 2, cy - 16                             # lower-left -> upper-right
	if t in ("staff", "spear"):
		c.line(x0, y0, x1, y1, LEA[1]); c.line(x0 + 1, y0, x1 + 1, y1, LEA[2]); c.line(x0 - 1, y0, x1 - 1, y1, LEA[3])
		if t == "spear":
			c.ellipse(x1 + 1, y1 - 3, 2, 4, w["head"][2]); c.paint(x1 + 1, y1 - 7, w["head"][0])
		else:
			c.disc(x1 + 1, y1 - 3, 3, w["gem"]); c.paint(x1, y1 - 4, (220, 240, 248, 255))
		return
	bl = w["blade"]; hi = w.get("hilt", LEA)                                       # greatsword
	c.line(x0, y0, x1, y1, bl[2]); c.line(x0 + 1, y0 + 1, x1 + 1, y1 + 1, bl[3]); c.line(x0 - 1, y0 - 1, x1 - 1, y1 - 1, bl[1])
	c.rect(x1, y1 - 3, x1 + 2, y1 + 3, hi[1]); c.disc(x1 + 1, y1 - 4, 2, GOLD[1])  # hilt over the shoulder

def stow_weapon_hip(c, J, view, wid):
	"""A one-hander in a hip scabbard hung off the belt."""
	w = WEAPONS.get(wid) if isinstance(wid, str) else wid
	if w is None:
		return
	py = J["pelvis"][1]; hipx = (J["chest"][0] - 6) if view == "side" else (J["hip_l"][0] - 3)
	short = (w.get("type") == "dagger"); bot = py + (9 if short else 16)
	c.rect(hipx - 2, py - 2, hipx + 2, bot, LEA[2]); c.rect(hipx - 2, py - 2, hipx - 1, bot, LEA[1]); c.rect(hipx + 1, py - 2, hipx + 2, bot, LEA[3])
	c.paint(hipx, bot, LEA[4])
	hi = w.get("hilt", LEA)
	c.rect(hipx - 1, py - 7, hipx + 1, py - 3, hi[1]); c.rect(hipx - 3, py - 3, hipx + 3, py - 2, hi[2])  # grip + guard
	c.paint(hipx, py - 8, hi[0])

# ============================================================================
# Compositor
# ============================================================================

def compose(view, phase, opts=None, dressed=True, weapon=None, shield=None, drawn=True, mode="walk"):
	o = look(opts)
	SK = o["skin"]; HR = o["hair"]; SET = ARMOR.get(o["armor"], ARMOR["ranger"])
	c = Canvas(FW, FH)
	J = resolve(view, phase, mode)
	# body build widens/narrows the shoulders (and the arms ride them out)
	bw = BUILD.get(o["build"], 0)
	if bw and view != "side":
		for k, s in (("shoulder_l", -1), ("shoulder_r", 1), ("hand_l", -1), ("hand_r", 1)):
			J[k] = (J[k][0] + s * bw, J[k][1])
	show_cloak = dressed and SET.get("cloak") is not None
	back_view = (view == "back")
	stow_w = weapon if (weapon is not None and not drawn) else None
	stow_s = shield if (shield is not None and not drawn) else None
	if show_cloak:
		cloak_back(c, J, view, SET["cloak"])
	# stowed back-gear sits BEHIND the body from the front/side (peeks past the edges)
	if not back_view:
		if stow_s is not None:
			stow_shield(c, J, view, stow_s)
		if stow_w is not None and stow_w in BACK_WEAPONS:
			stow_weapon_back(c, J, view, stow_w)
	base_legs(c, J, view, SK)
	base_torso(c, J, view, SK)
	base_arms(c, J, view, SK)
	if dressed:
		draw_outfit(c, J, view, SET, SK)
	# from behind, the same back-gear rides ON TOP of the back
	if back_view:
		if stow_s is not None:
			stow_shield(c, J, view, stow_s)
		if stow_w is not None and stow_w in BACK_WEAPONS:
			stow_weapon_back(c, J, view, stow_w)
	# a hip scabbard sits in front of the body in every view
	if stow_w is not None and stow_w not in BACK_WEAPONS:
		stow_weapon_hip(c, J, view, stow_w)
	base_head(c, J, view, SK, HR, o["hair_style"], o["beard"], o["mark"], o["mark_col"])
	if dressed:
		draw_helm(c, J, view, SET)
	if show_cloak:
		cloak_collar(c, J, view, SET["cloak"])
	# drawn (in-hand / on-arm) gear
	if drawn and shield is not None:
		held_shield(c, J, view, shield)
	if drawn and weapon is not None:
		held_weapon(c, J, view, weapon)
	c.rim_light(0.35)
	c.outline(INK, diagonal=False)
	return c

# ============================================================================
# Output (preview)
# ============================================================================

def _mirror(src):
	out = Canvas(src.w, src.h)
	for y in range(src.h):
		for x in range(src.w):
			out.paint(src.w - 1 - x, y, src.at(x, y))
	return out

def _row(cols, scale=3, bg=(126, 160, 120, 255)):
	gap = 6
	m = Canvas((FW + gap) * len(cols) + gap, FH + 16)
	m.rect(0, 0, m.w - 1, m.h - 1, bg)
	for i, col in enumerate(cols):
		m.blit(col, gap + i * (FW + gap), 8, mode="over")
	return m.scaled(scale)

def _idle_gif(path):
	frames = []
	for p in (0, 1, 2, 3):
		m = Canvas(60, 124); m.rect(0, 0, m.w - 1, m.h - 1, (126, 160, 120, 255))
		m.blit(compose("front", p, None, mode="idle"), (60 - FW) // 2, 124 - FH - 2, mode="over")
		frames.append(m.scaled(3))
	pal, idx = gifutil.quantize(frames)
	gifutil.write_gif(path, pal, idx, frames[0].w, frames[0].h, 5)

def _turn(opts=None, dressed=True):
	cols = []
	for v in ("front", "side", "back"):
		cols.append(compose(v, 1, opts, dressed))
	cols.append(_mirror(compose("side", 1, opts, dressed)))
	return cols

def main():
	_row(_turn(None, False) + _turn(None, True)).save("/tmp/segment_turn.png")
	# customization proof: skin tones x hair styles, dressed
	looks = [
		{"skin": SKIN["fair"], "hair": HAIR["blond"], "hair_style": "long"},
		{"skin": SKIN["tan"],  "hair": HAIR["brown"], "hair_style": "short", "beard": "full"},
		{"skin": SKIN["brown"], "hair": HAIR["black"], "hair_style": "spiky"},
		{"skin": SKIN["deep"], "hair": HAIR["black"], "hair_style": "long"},
	]
	_row([compose("front", 1, o) for o in looks]).save("/tmp/segment_custom.png")
	# every hair style, front (short / long / spiky / ponytail / bun / bald)
	styles = ["short", "long", "spiky", "ponytail", "bun", "bald"]
	_row([compose("front", 0, {"hair_style": s}) for s in styles]).save("/tmp/segment_hair.png")
	# body builds + face marks
	axes = [
		{"build": "slim"}, {"build": "average"}, {"build": "broad", "beard": "full"},
		{"mark": "scar"}, {"mark": "warpaint"}, {"mark": "warpaint", "mark_col": (40, 60, 120, 255)},
	]
	_row([compose("front", 1, o) for o in axes]).save("/tmp/segment_axes.png")
	# wardrobe: each armour set front + side
	sets = ["ranger", "rogue", "iron", "plate", "robe"]
	cols = []
	for a in sets:
		cols.append(compose("front", 1, {"armor": a})); cols.append(compose("side", 1, {"armor": a}))
	_row(cols).save("/tmp/segment_armor.png")
	# armour turnaround for one set (plate) to check all facings
	_row(_turn({"armor": "plate", "build": "broad"}, True)).save("/tmp/segment_plate_turn.png")
	# rogue turnaround
	_row(_turn({"armor": "rogue"}, True)).save("/tmp/segment_rogue_turn.png")
	# all eight weapons in hand
	weaps = ["sword", "greatsword", "axe", "mace", "spear", "dagger", "bow", "staff"]
	_row([compose("front", 0, {"armor": "iron"}, weapon=w) for w in weaps]).save("/tmp/segment_weapons.png")
	# shields (+ a sword), then a knight with shield + the tree crest
	shs = ["buckler", "round", "heater", "kite"]
	_row([compose("front", 0, {"armor": "iron"}, weapon="sword", shield=s) for s in shs]).save("/tmp/segment_shields.png")
	# hero beauty shots: knight w/ greatsword+heater, rogue w/ dagger, ranger w/ bow, mage w/ staff
	heroes = [
		compose("front", 0, {"armor": "plate", "build": "broad"}, weapon="greatsword", shield="heater"),
		compose("front", 0, {"armor": "rogue"}, weapon="dagger"),
		compose("front", 0, {"armor": "ranger"}, weapon="bow"),
		compose("front", 0, {"armor": "robe"}, weapon="staff"),
	]
	_row(heroes).save("/tmp/segment_heroes.png")
	# stowed gear: weapon sheathed + shield slung, front + back
	stowed = [
		compose("front", 0, {"armor": "ranger"}, weapon="sword", shield="heater", drawn=False),
		compose("back", 0, {"armor": "ranger"}, weapon="sword", shield="heater", drawn=False),
		compose("front", 0, {"armor": "iron"}, weapon="greatsword", shield="kite", drawn=False),
		compose("back", 0, {"armor": "iron"}, weapon="greatsword", shield="kite", drawn=False),
		compose("front", 0, {"armor": "rogue"}, weapon="bow", drawn=False),
		compose("back", 0, {"armor": "rogue"}, weapon="bow", drawn=False),
	]
	_row(stowed).save("/tmp/segment_stowed.png")
	# idle breathing frames + an animated GIF to check the motion
	_row([compose("front", p, None, mode="idle") for p in range(4)]).save("/tmp/segment_idle.png")
	_idle_gif("/tmp/segment_idle.gif")
	for v in ("front", "side"):
		_row([compose(v, p, None) for p in range(4)]).save("/tmp/walk_%s.png" % v)
	print("wrote turn + custom + hair + axes + armor + plate/rogue turns + weapons + shields + heroes + walk")

if __name__ == "__main__":
	main()
