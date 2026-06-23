#!/usr/bin/env python3
"""Segment rig — the remaster's modular character MODEL (the foundation for
changing armour and clothes).

Unlike the old rig, which baked a green-cloaked hero straight into the sheet,
this builds the figure from a BARE mannequin (skin / hair / face / smallclothes)
posed by a data-driven SKELETON, and treats every garment, armour piece and
weapon as a LAYER that attaches to the same joints. So "dress the hero" = stack
layers, and a new gear piece is "draw within this joint's box", not "guess
pixels per direction".

Model:
  * 4 facings: front (down), side (right; left = mirror), back (up).
  * JOINTS[view] gives rest joint positions; walk_offsets(view, phase) bends the
    skeleton per walk phase. resolve(view, phase) returns the live joint dict J.
  * Parts/garments draw themselves FROM J (single source of truth), so the body
    and everything worn stay aligned across all frames automatically.
  * anchor(view, phase, name) exposes a joint for gear/FX placement.

Run:  python3 tools/segment_rig.py   ->  /tmp/segment_turn.png (+ walk GIFs)
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
from gen_cast import SKIN, HAIR, CLOTH, LEA, GOLD, INK, WHITE, BLUSH  # noqa: E402
import gifutil  # noqa: E402

FW, FH = 84, 120
SK = SKIN["tan"]; HR = HAIR["brown"]
SK_HI = (255, 238, 214, 255); EYE = (112, 146, 92, 255); MOUTH = (150, 86, 78, 255)
SMALL = CLOTH["cream"]   # smallclothes (the only thing the bare base "wears")

# ============================================================================
# Skeleton — rest joints per view, and the walk that bends them.
# ============================================================================

JOINTS = {
	"front": {
		"head": (42, 23), "neck": (42, 40), "chest": (42, 55), "pelvis": (42, 73),
		"shoulder_l": (22, 46), "shoulder_r": (62, 46),
		"hand_l": (23, 84), "hand_r": (61, 84),
		"hip_l": (36, 74), "hip_r": (48, 74),
		"foot_l": (35, 112), "foot_r": (49, 112),
	},
	"side": {
		"head": (40, 22), "neck": (40, 40), "chest": (40, 55), "pelvis": (40, 73),
		"shoulder_l": (38, 47), "shoulder_r": (43, 47),
		"hand_l": (35, 82), "hand_r": (46, 82),     # _l = far, _r = near (lit)
		"hip_l": (38, 74), "hip_r": (42, 74),
		"foot_l": (35, 112), "foot_r": (45, 112),
	},
	"back": {
		"head": (42, 23), "neck": (42, 40), "chest": (42, 55), "pelvis": (42, 73),
		"shoulder_l": (22, 46), "shoulder_r": (62, 46),
		"hand_l": (23, 84), "hand_r": (61, 84),
		"hip_l": (36, 74), "hip_r": (48, 74),
		"foot_l": (35, 112), "foot_r": (49, 112),
	},
}

# Walk phases. Upper body bobs; the two legs lift on alternate passes; the hands
# swing in opposition. Side view also strides the feet fore/aft.
# (l_lift, r_lift, bob, swing, near_dx, far_dx)
WALK = [
	(0, 0, 0,  0,  0,  0),
	(0, 3, 1, -1,  4, -4),
	(0, 0, 0,  0,  0,  0),
	(3, 0, 1,  1, -4,  4),
]

def resolve(view, phase):
	"""Live joint positions for this view + walk phase."""
	l_lift, r_lift, bob, swing, near_dx, far_dx = WALK[phase]
	J = {k: list(v) for k, v in JOINTS[view].items()}
	# upper body bobs up
	for k in ("head", "neck", "chest", "shoulder_l", "shoulder_r", "hand_l", "hand_r", "pelvis"):
		J[k][1] -= bob
	# arms swing in opposition (front/back read as the hands rising/falling)
	J["hand_r"][1] += swing
	J["hand_l"][1] -= swing
	if view == "side":
		# feet stride fore/aft; near foot lifts on the passing phase
		J["foot_r"][0] += near_dx; J["foot_l"][0] += far_dx
		J["hand_r"][0] += near_dx // 2; J["hand_l"][0] += far_dx // 2
		J["foot_r"][1] -= max(0, r_lift - 1)
	else:
		J["foot_l"][1] -= l_lift; J["foot_r"][1] -= r_lift
	return {k: (int(round(v[0])), int(round(v[1]))) for k, v in J.items()}

def anchor(view, phase, name):
	return resolve(view, phase)[name]

# ============================================================================
# Helpers
# ============================================================================

def _limb(c, top, bot, w, ramp):
	"""A simple shaded limb segment from `top` to `bot` joint, width w."""
	(x0, y0), (x1, y1) = top, bot
	steps = max(abs(y1 - y0), abs(x1 - x0), 1)
	for i in range(steps + 1):
		t = i / steps
		x = int(round(x0 + (x1 - x0) * t)); y = int(round(y0 + (y1 - y0) * t))
		c.rect(x - w, y, x + w, y, ramp[1])
		c.paint(x - w, y, ramp[0]); c.paint(x + w, y, ramp[2])

# ============================================================================
# Bare base parts — skin + smallclothes, posed from J.
# ============================================================================

def base_legs(c, J, view):
	for side, lit in (("l", False), ("r", True)):
		hip = J["hip_%s" % side]; foot = J["foot_%s" % side]
		ramp = SK if lit or view == "front" else [SK[1], SK[2], SK[3], SK[4], SK[4]]
		_limb(c, (hip[0], hip[1] + 1), (foot[0], foot[1] - 4), 3, ramp)
		# bare foot
		c.ellipse(foot[0], foot[1] - 2, 4, 3, SK[2], fill=True)
		c.paint(foot[0] - 2, foot[1] - 3, SK[1])
	# smallclothes around the hips
	px, py = J["pelvis"]
	c.rect(px - 8, py - 2, px + 8, py + 6, SMALL[1]); c.rect(px - 8, py - 2, px - 6, py + 6, SMALL[0])
	c.rect(px + 6, py - 2, px + 8, py + 6, SMALL[2]); c.rect(px - 8, py + 5, px + 8, py + 6, SMALL[3])

def base_torso(c, J, view):
	cx, cy = J["chest"]; px, py = J["pelvis"]
	sl = J["shoulder_l"]; sr = J["shoulder_r"]
	if view == "side":
		# torso in profile: a forward chest up top tapering back to the waist,
		# so the body carries mass under the head instead of a flat slab.
		c.ellipse(cx, cy + 2, 8, 17, SK[2], fill=True)
		c.rect(cx - 6, sl[1], cx + 8, cy + 1, SK[2])               # chest (pushed forward)
		c.rect(cx - 5, cy + 1, cx + 6, py, SK[2])                  # waist (tucks back)
		c.rect(cx + 6, sl[1], cx + 8, cy + 1, SK[1])               # lit chest front
		c.rect(cx + 4, cy + 1, cx + 6, py, SK[1])                  # lit belly front
		c.rect(cx - 6, sl[1], cx - 4, py, SK[3])                   # shaded back
		return
	w = (sr[0] - sl[0]) // 2
	# tapered trunk — broad shoulders narrowing to the waist (a capable V build)
	for y in range(sl[1], py + 1):
		t = (y - sl[1]) / max(1, py - sl[1])
		half = int(round(w * (1.0 - 0.30 * t)))         # ~30% taper to the waist
		half -= max(0, 2 - (y - sl[1]))                 # round the shoulder caps
		c.rect(cx - half, y, cx + half, y, SK[2])
		c.rect(cx - half, y, cx - half + 2, y, SK[1])   # lit left edge
		c.rect(cx + half - 2, y, cx + half, y, SK[3])   # shaded right edge
	c.ellipse(cx, cy - 1, w - 4, 9, SK[1], fill=True)   # chest/pec highlight
	if view == "front":
		c.line(cx, cy - 3, cx, py - 2, SK[3])           # sternum line
		c.paint(cx - 5, cy + 6, SK[3]); c.paint(cx + 5, cy + 6, SK[3])  # pec shade

def base_arms(c, J, view):
	for side in ("l", "r"):
		sh = J["shoulder_%s" % side]; hand = J["hand_%s" % side]
		lit = (side == "r")
		ramp = SK if (lit or view == "front") else [SK[1], SK[2], SK[3], SK[4], SK[4]]
		_limb(c, sh, (hand[0], hand[1] - 3), 3, ramp)
		c.ellipse(hand[0], hand[1], 4, 4, SK[2], fill=True)        # bare hand
		c.paint(hand[0] - 1, hand[1] - 1, SK[1]); c.paint(hand[0] + 2, hand[1] + 1, SK[3])

def base_head(c, J, view):
	hx, hy = J["head"]
	if view == "back":
		# back of the head — all hair
		c.ellipse(hx, hy + 1, 14, 15, SK[3], fill=True)
		c.ellipse(hx, hy - 2, 15, 13, HR[2], fill=True); c.ellipse(hx, hy - 7, 15, 9, HR[2], fill=True)
		c.rect(hx - 15, hy - 9, hx - 11, hy + 7, HR[2]); c.rect(hx + 11, hy - 9, hx + 15, hy + 7, HR[3])
		for h in (hx - 8, hx - 3, hx + 2, hx + 7): c.line(h, hy - 9, h, hy + 7, HR[3])
		c.ellipse(hx - 5, hy - 13, 9, 4, HR[1]); c.line(hx - 11, hy - 14, hx + 2, hy - 16, HR[0])
		return
	if view == "side":
		_head_side(c, hx, hy); return
	_head_front(c, hx, hy)

def _head_front(c, cx, cy):
	c.rect(cx - 5, cy + 13, cx + 4, cy + 19, SK[3])                 # neck
	c.ellipse(cx, cy, 14, 15, SK[2], fill=True); c.ellipse(cx - 3, cy - 3, 9, 9, SK[1], fill=True)
	c.ellipse(cx, cy + 8, 9, 5, SK[2], fill=True); c.ellipse(cx, cy + 13, 6, 2, SK[3], fill=True)
	for s in (-1, 1):
		ex = cx + s * 13; c.line(ex, cy + 1, ex + s * 3, cy - 4, SK[2]); c.paint(ex + s * 1, cy - 1, SK[1])
	for bx in (cx - 8, cx - 7, cx + 7, cx + 8): c.paint(bx, cy + 5, BLUSH)
	# eyes + brows + nose + mouth
	c.line(cx - 9, cy - 5, cx - 3, cy - 6, HR[2]); c.line(cx + 3, cy - 6, cx + 9, cy - 5, HR[2])
	for s in (-1, 1):
		ox = cx + s * 6
		c.rect(ox - 2, cy - 3, ox + 1, cy - 3, SK[3]); c.rect(ox - 2, cy - 2, ox + 1, cy, WHITE)
		c.rect(ox - 1, cy - 2, ox + 1, cy, EYE); c.paint(ox, cy - 1, (56, 44, 40, 255)); c.paint(ox - 1, cy - 2, WHITE)
	c.paint(cx - 1, cy + 1, SK[1]); c.paint(cx - 1, cy + 3, SK[0]); c.paint(cx + 1, cy + 3, SK[3])
	c.line(cx - 3, cy + 8, cx + 3, cy + 8, MOUTH); c.paint(cx - 4, cy + 7, MOUTH); c.paint(cx + 4, cy + 7, MOUTH)
	# hair
	c.ellipse(cx, cy - 11, 15, 10, HR[2], fill=True)
	c.rect(cx - 15, cy - 11, cx - 11, cy + 5, HR[2]); c.rect(cx + 11, cy - 11, cx + 15, cy + 5, HR[3])
	c.ellipse(cx - 8, cy - 10, 5, 4, HR[2], fill=True); c.ellipse(cx, cy - 9, 5, 4, HR[2], fill=True); c.ellipse(cx + 8, cy - 10, 5, 4, HR[2], fill=True)
	c.rect(cx - 10, cy - 7, cx + 9, cy - 6, HR[3]); c.ellipse(cx + 8, cy - 11, 7, 9, HR[3], fill=True)
	c.ellipse(cx - 5, cy - 15, 8, 3, HR[1], fill=True); c.line(cx - 10, cy - 16, cx + 1, cy - 17, HR[0])
	c.line(cx - 4, cy - 16, cx - 6, cy - 7, HR[4]); c.line(cx + 4, cy - 15, cx + 3, cy - 7, HR[4])

def _head_side(c, cx, cy):
	# neck — a short, sturdy column tucked UNDER the skull (not craned forward),
	# leaning a touch forward into the shoulders the way a real neck does.
	c.rect(cx - 3, cy + 12, cx + 3, cy + 22, SK[3]); c.rect(cx - 3, cy + 12, cx - 2, cy + 22, SK[4])
	c.rect(cx + 2, cy + 12, cx + 3, cy + 22, SK[2])                 # lit front of throat
	# skull — centered over the spine; only the FACE profile reads forward.
	c.ellipse(cx, cy, 11, 13, SK[2], fill=True)
	c.ellipse(cx + 2, cy + 1, 8, 10, SK[1], fill=True)             # lit cheek
	# face profile: forehead -> brow -> nose -> lip -> chin, gently stepped
	c.rect(cx + 8, cy - 3, cx + 10, cy + 7, SK[1])                 # forehead/cheek plane
	c.paint(cx + 11, cy + 2, SK[1]); c.paint(cx + 11, cy + 3, SK[2]); c.paint(cx + 10, cy + 4, SK[3])  # nose tip
	c.paint(cx + 8, cy + 5, SK[2])                                 # philtrum, receding under the nose
	c.ellipse(cx + 3, cy + 11, 6, 3, SK[2], fill=True)            # chin/jaw mass (set back from the nose)
	c.paint(cx + 6, cy + 10, SK[3]); c.paint(cx + 7, cy + 9, SK[3])                                     # jaw shade
	c.ellipse(cx - 3, cy + 1, 2, 3, SK[2], fill=True); c.paint(cx - 3, cy + 1, SK[3])                   # ear, set back
	c.paint(cx + 7, cy + 6, BLUSH); c.paint(cx + 8, cy + 6, BLUSH)
	c.line(cx + 5, cy - 1, cx + 8, cy - 2, HR[2])                  # brow
	c.rect(cx + 6, cy + 1, cx + 8, cy + 2, WHITE); c.paint(cx + 8, cy + 1, EYE); c.paint(cx + 7, cy + 1, (56, 44, 40, 255))
	c.line(cx + 6, cy + 8, cx + 9, cy + 8, MOUTH); c.paint(cx + 7, cy + 9, (196, 124, 112, 255))
	# hair — crown, back fall, forward sweep over the brow
	c.ellipse(cx, cy - 11, 12, 9, HR[2], fill=True); c.rect(cx - 12, cy - 11, cx - 7, cy + 8, HR[3])
	c.ellipse(cx + 6, cy - 10, 6, 5, HR[2], fill=True); c.paint(cx + 9, cy - 6, HR[3]); c.paint(cx + 10, cy - 5, HR[4])
	c.ellipse(cx - 3, cy - 15, 7, 3, HR[1], fill=True); c.line(cx - 9, cy - 16, cx + 2, cy - 17, HR[0])
	c.rect(cx - 12, cy - 11, cx - 11, cy + 4, HR[1])

# ============================================================================
# Apparel layers — garments that ride the same joints. (Novice outfit for now.)
# ============================================================================

def garment_trousers(c, J, view, ramp):
	for side in ("l", "r"):
		hip = J["hip_%s" % side]; foot = J["foot_%s" % side]
		lit = (side == "r")
		r = ramp if (lit or view == "front") else [ramp[1], ramp[2], ramp[3], ramp[4], ramp[4]]
		_limb(c, (hip[0], hip[1]), (foot[0], foot[1] - 6), 4, r)
	px, py = J["pelvis"]
	c.rect(px - 9, py - 3, px + 9, py + 6, ramp[1]); c.rect(px - 9, py - 3, px - 7, py + 6, ramp[0])
	c.rect(px + 7, py - 3, px + 9, py + 6, ramp[2]); c.rect(px - 9, py + 5, px + 9, py + 6, ramp[3])

def garment_boots(c, J, view, ramp):
	for side in ("l", "r"):
		foot = J["foot_%s" % side]; fx, fy = foot
		c.rect(fx - 5, fy - 14, fx + 5, fy, ramp[1]); c.rect(fx - 5, fy - 14, fx - 3, fy, ramp[0])
		c.rect(fx + 3, fy - 12, fx + 6, fy, ramp[2]); c.rect(fx - 6, fy - 2, fx + 7, fy, ramp[3])
		c.line(fx - 3, fy - 7, fx + 3, fy - 7, ramp[3])

def _sleeve(c, J, view, side, ramp):
	"""Full sleeve shoulder->wrist with a leather glove at the hand."""
	sh = J["shoulder_%s" % side]; hand = J["hand_%s" % side]
	r = ramp if (side == "r" or view == "front") else [ramp[1], ramp[2], ramp[3], ramp[4], ramp[4]]
	_limb(c, sh, (hand[0], hand[1] - 4), 3, r)
	c.line(sh[0], sh[1] + 2, sh[0], sh[1] + 7, r[2])               # shoulder seam fold
	c.rect(hand[0] - 4, hand[1] - 4, hand[0] + 4, hand[1] - 2, LEA[2])   # cuff
	c.ellipse(hand[0], hand[1], 4, 4, LEA[1], fill=True)          # glove
	c.paint(hand[0] - 2, hand[1] - 1, LEA[0]); c.paint(hand[0] + 2, hand[1] + 1, LEA[3])

def garment_tunic(c, J, view, ramp):
	cx, cy = J["chest"]; px, py = J["pelvis"]
	sl = J["shoulder_l"]; sr = J["shoulder_r"]
	# far sleeve first (behind the body)
	_sleeve(c, J, view, "l", ramp)
	if view == "side":
		c.ellipse(cx, cy + 3, 11, 18, ramp[1], fill=True)
		c.rect(cx - 7, sl[1], cx + 8, py + 3, ramp[1])
		c.rect(cx - 7, sl[1], cx - 5, py + 3, ramp[3]); c.rect(cx + 6, sl[1], cx + 8, py + 3, ramp[0])
		c.rect(cx - 7, py + 1, cx + 8, py + 3, ramp[3])
		for i in range(18): c.paint(cx + 6 - i // 3, sl[1] + i, LEA[2])     # satchel strap
	else:
		hw = (sr[0] - sl[0]) // 2 + 2
		c.ellipse(cx, cy + 4, hw, 19, ramp[1], fill=True)
		c.rect(sl[0] - 2, sl[1], sr[0] + 2, py + 3, ramp[1])
		c.rect(sl[0] - 2, sl[1], sl[0] + 1, py + 3, ramp[0]); c.rect(sr[0] - 1, sl[1], sr[0] + 2, py + 3, ramp[2])
		c.rect(sl[0] - 2, py + 1, sr[0] + 2, py + 3, ramp[3])
		c.line(cx - 7, cy - 4, cx - 5, cy + 6, ramp[2]); c.line(cx + 6, cy - 2, cx + 4, cy + 8, ramp[2])  # folds
		if view == "front":
			c.rect(cx - 4, sl[1] - 3, cx + 4, sl[1] + 2, CLOTH["cream"][1])    # collar
			c.rect(cx - 4, sl[1] - 3, cx - 2, sl[1] + 2, CLOTH["cream"][0])
			i = 0                                                              # satchel strap
			while sl[1] + 2 + i < py:
				c.paint(cx - 11 + i, sl[1] + 2 + i, LEA[2]); c.paint(cx - 10 + i, sl[1] + 2 + i, LEA[3]); i += 1
		else:
			c.line(cx, sl[1], cx, py, ramp[2])                                 # back seam
	# belt
	c.rect(sl[0] - 2, py - 4, sr[0] + 2, py, LEA[2]); c.rect(sl[0] - 2, py - 4, sr[0] + 2, py - 4, LEA[1])
	c.rect(sl[0] - 2, py, sr[0] + 2, py, LEA[4])
	c.rect(cx - 3, py - 5, cx + 3, py + 1, GOLD[1]); c.paint(cx + 2, py - 1, GOLD[2])
	# near sleeve last (in front)
	_sleeve(c, J, view, "r", ramp)

def held_weapon(c, J, view, kit):
	"""A weapon in the main (near/right) hand — proves gear attaches to a joint."""
	hx, hy = J["hand_r"]; bl = kit["blade"]; hi = kit["hilt"]
	c.rect(hx - 1, hy - 5, hx + 1, hy - 1, hi[1]); c.paint(hx, hy - 6, hi[0])
	c.rect(hx - 4, hy, hx + 4, hy + 1, hi[2])
	for i in range(2, 17):
		w = 2 if i < 13 else (1 if i < 16 else 0)
		c.rect(hx - w, hy + i, hx + w, hy + i, bl[2]); c.paint(hx - w, hy + i, bl[0])
		if w > 1: c.paint(hx + w, hy + i, bl[3])

# ============================================================================
# Compositor
# ============================================================================

NOVICE = {"tunic": CLOTH["green"], "trousers": CLOTH["slate"], "boots": CLOTH["brown"]}

def compose(view, phase, dressed=True, weapon=None):
	c = Canvas(FW, FH)
	J = resolve(view, phase)
	# z-order: far limbs -> body -> near limbs -> head -> garments -> weapon
	base_legs(c, J, view)
	base_torso(c, J, view)
	base_arms(c, J, view)
	base_head(c, J, view)
	if dressed:
		garment_trousers(c, J, view, NOVICE["trousers"])
		garment_boots(c, J, view, NOVICE["boots"])
		garment_tunic(c, J, view, NOVICE["tunic"])
	if weapon is not None:
		held_weapon(c, J, view, weapon)
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

def _walk_gif(path, view, dressed):
	comps = []
	for p in [0, 1, 2, 3]:
		m = Canvas(60, 124); m.rect(0, 0, m.w - 1, m.h - 1, (126, 160, 120, 255))
		m.blit(compose(view, p, dressed), (60 - FW) // 2, 124 - FH - 2, mode="over")
		comps.append(m.scaled(3))
	pal, idx = gifutil.quantize(comps)
	gifutil.write_gif(path, pal, idx, comps[0].w, comps[0].h, 12)

def main():
	# turnaround: bare vs dressed, front / side / back / (mirror=left)
	views = ["front", "side", "back"]
	cols = []
	for dressed in (False, True):
		for v in views:
			cols.append(compose(v, 1, dressed))
		cols.append(_mirror(compose("side", 1, dressed)))   # left = mirror
	gap = 6
	m = Canvas((FW + gap) * len(cols) + gap, FH + 16)
	m.rect(0, 0, m.w - 1, m.h - 1, (126, 160, 120, 255))
	for i, col in enumerate(cols):
		m.blit(col, gap + i * (FW + gap), 8, mode="over")
	m.scaled(3).save("/tmp/segment_turn.png")
	_walk_gif("/tmp/segment_walk_front.gif", "front", True)
	_walk_gif("/tmp/segment_walk_side.gif", "side", True)
	print("wrote /tmp/segment_turn.png + walk GIFs")

if __name__ == "__main__":
	main()
