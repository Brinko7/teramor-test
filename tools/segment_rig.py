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

FW, FH = 84, 120
EYE = (96, 132, 92, 255); MOUTH = (150, 86, 78, 255); DARK = (52, 40, 38, 255)
SCAR = (216, 176, 150, 255); WARPAINT = (150, 52, 48, 255)
SMALL = CLOTH["cream"]
BUILD = {"slim": -3, "average": 0, "broad": 5}

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

def resolve(view, phase):
	l_lift, r_lift, bob, swing, near_dx, far_dx = WALK[phase]
	J = {k: list(v) for k, v in JOINTS[view].items()}
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
	"build": "average", "mark": "none", "mark_col": WARPAINT,
	"cloak": [(86,108,92,255),(66,86,72,255),(50,68,56,255),(36,52,42,255),(26,38,30,255)],
	"jerkin": LEA, "tunic": CLOTH["cream"], "trouser": CLOTH["slate"], "boots": CLOTH["brown"],
}

def look(opts=None):
	o = dict(DEFAULT)
	if opts:
		o.update(opts)
	o["skin"] = _ramp_from(o["skin"]); o["hair"] = _ramp_from(o["hair"])
	for k in ("cloak", "jerkin", "tunic", "trouser", "boots"):
		o[k] = _ramp_from(o[k])
	return o

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

def _sleeve(c, J, side, view, JK, SK):
	sh = J["shoulder_%s" % side]; hand = J["hand_%s" % side]
	far = (side == "l" and view == "side")
	_cap(c, sh, (hand[0], hand[1] - 5), 4, 3, JK, far)
	c.rect(hand[0] - 4, hand[1] - 5, hand[0] + 4, hand[1] - 2, LEA[2])             # bracer cuff
	c.rect(hand[0] - 4, hand[1] - 5, hand[0] + 4, hand[1] - 5, LEA[1])
	c.ellipse(hand[0], hand[1], 3, 4, SK[2 if not far else 3])                     # bare hand
	c.paint(hand[0] - 1, hand[1] - 1, SK[1]); c.paint(hand[0] + 2, hand[1] + 1, SK[3])

def garment_jerkin(c, J, view, JK, TU, SK):
	"""Leather jerkin over an undertunic, with belt, collar + one pauldron."""
	cx, cy = J["chest"]; px, py = J["pelvis"]; sl = J["shoulder_l"]; sr = J["shoulder_r"]
	_sleeve(c, J, "l", view, JK, SK)                                              # far sleeve first
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
	# belt
	c.rect(sl[0] - 1, py - 3, sr[0] + 1, py + 1, LEA[3]); c.rect(sl[0] - 1, py - 3, sr[0] + 1, py - 3, LEA[2])
	c.rect(cx - 3, py - 4, cx + 3, py + 2, GOLD[1]); c.paint(cx + 2, py, GOLD[2]); c.paint(cx - 2, py - 3, GOLD[0])
	_sleeve(c, J, "r", view, JK, SK)                                              # near sleeve last
	# fitted leather pauldrons with a steel stud — grounded ranger armour
	def _pauldron(px, py, lit):
		b = LEA if lit else [LEA[1], LEA[2], LEA[3], LEA[4], LEA[4]]
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

def held_weapon(c, J, view, kit):
	hx, hy = J["hand_r"]; bl = kit["blade"]; hi = kit["hilt"]
	c.rect(hx - 1, hy - 6, hx + 1, hy - 1, hi[1]); c.paint(hx, hy - 7, hi[0])
	c.rect(hx - 4, hy, hx + 4, hy + 1, hi[2])
	for i in range(2, 20):
		w = 2 if i < 15 else (1 if i < 18 else 0)
		c.rect(hx - w, hy + i, hx + w, hy + i, bl[2]); c.paint(hx - w, hy + i, bl[0])
		if w > 1: c.paint(hx + w, hy + i, bl[3])

# ============================================================================
# Compositor
# ============================================================================

def compose(view, phase, opts=None, dressed=True, weapon=None, cloak=True):
	o = look(opts)
	SK = o["skin"]; HR = o["hair"]
	c = Canvas(FW, FH)
	J = resolve(view, phase)
	# body build widens/narrows the shoulders (and the arms ride them out)
	bw = BUILD.get(o["build"], 0)
	if bw and view != "side":
		for k, s in (("shoulder_l", -1), ("shoulder_r", 1), ("hand_l", -1), ("hand_r", 1)):
			J[k] = (J[k][0] + s * bw, J[k][1])
	if dressed and cloak:
		cloak_back(c, J, view, o["cloak"])
	base_legs(c, J, view, SK)
	base_torso(c, J, view, SK)
	base_arms(c, J, view, SK)
	if dressed:
		garment_trousers(c, J, view, o["trouser"])
		garment_boots(c, J, view, o["boots"])
		garment_jerkin(c, J, view, o["jerkin"], o["tunic"], SK)
	base_head(c, J, view, SK, HR, o["hair_style"], o["beard"], o["mark"], o["mark_col"])
	if dressed and cloak:
		cloak_collar(c, J, view, o["cloak"])
	if weapon is not None:
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
	for v in ("front", "side"):
		_row([compose(v, p, None) for p in range(4)]).save("/tmp/walk_%s.png" % v)
	print("wrote turn + custom + hair + axes + walk strips")

if __name__ == "__main__":
	main()
