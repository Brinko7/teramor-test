#!/usr/bin/env python3
"""Layered GEAR overlays for the remaster hero — the art half of visible gear.

The walking-hero body sheet (bake_player.py) is one layer; equipped weapons and
armour are SEPARATE overlay sheets with the *same* geometry (84x120 frames, 8
facings x 4 walk phases, foot-anchored), drawn only where the gear sits and
transparent everywhere else. Stacked over the body and synced to the same frame
index, they let the hero visibly "level up" through gear — matching the engine's
existing ArmorItem.overlay_sheet / WeaponItem contract, now in the new style.

Alignment is exact because the overlays are placed at the SAME per-frame hand /
shoulder / torso anchors the body rig uses (single source of truth: the rig's
own phase constants, re-derived here in `*_anchor`).

Run:  python3 tools/gen_player_gear.py  ->  assets/remaster/{weapon_*,armor_*}.png
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
import gen_player_anim as fa  # noqa: E402  (front rig + PHASES)
import gen_player_dirs as d   # noqa: E402  (side / back rigs)

FW, FH, COLS, ROWS = 84, 120, 4, 8
OUTDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "remaster"))

# ---- gear palettes (light -> dark) ----
STEEL   = [(218,226,234,255),(176,188,202,255),(126,140,158,255),(84,98,118,255)]
IRON    = [(176,182,190,255),(140,148,158,255),(104,112,124,255),(70,78,90,255)]
LEATHER = [(176,128,80,255),(146,102,60,255),(114,78,44,255),(84,56,30,255)]
GOLD    = [(248,214,134,255),(222,172,94,255),(168,122,60,255)]
WOOD    = [(150,116,80,255),(120,88,56,255),(92,66,40,255)]
EMBER   = [(255,224,150,255),(255,170,70,255),(232,104,48,255),(170,56,30,255)]

# ============================================================================
# Per-frame anchors — re-derived from each rig's own phase constants so an
# overlay lands exactly where the body draws the hand / shoulders / chest.
# Returns dict: hand (main), offhand, shoulders (l,r), chest (cx,cy).
# ============================================================================

def front_anchor(phase):
	ll, rl, bob, swing = fa.PHASES[phase]; cx = 42
	return {
		"hand": (cx + 19, 83 + swing - bob),
		"offhand": (cx - 19, 83 - swing - bob),
		"sh_r": (cx + 17, 47 - bob), "sh_l": (cx - 17, 47 - bob),
		"chest": (cx, 54 - bob), "view": "front",
	}

def side_anchor(phase):
	bob = [0, 1, 0, 1][phase]; swing = [0, 2, 0, -2][phase]; cx = 40
	return {
		"hand": (cx + 6, 79 + swing - bob),
		"offhand": (cx - 6, 79 - swing - bob),
		"sh_r": (cx + 6, 47 - bob), "sh_l": (cx - 4, 49 - bob),
		"chest": (cx, 56 - bob), "view": "side",
	}

def back_anchor(phase):
	ll, rl, bob, swing = fa.PHASES[phase]; cx = 42
	return {
		"hand": (cx + 19, 83 + swing - bob),
		"offhand": (cx - 19, 83 - swing - bob),
		"sh_r": (cx + 17, 47 - bob), "sh_l": (cx - 17, 47 - bob),
		"chest": (cx, 54 - bob), "view": "back",
	}

# ============================================================================
# Weapon overlay — a weapon held in the main hand, blade hanging down-forward.
# kit: {"blade": ramp, "hilt": ramp, "glow": color|None}
# ============================================================================

def draw_weapon(c, a, kit):
	hx, hy = a["hand"]
	bl = kit["blade"]; hi = kit["hilt"]; glow = kit.get("glow")
	# the blade angles slightly outward (away from the body centre) as it falls
	out = 1 if a["view"] != "back" else 1
	# grip + pommel (in the fist)
	c.rect(hx-1, hy-5, hx+1, hy-1, hi[1]); c.paint(hx, hy-6, hi[0])
	# crossguard
	c.rect(hx-4, hy, hx+4, hy+1, hi[2]); c.paint(hx-4, hy, hi[1]); c.paint(hx+4, hy, hi[1])
	# blade, falling ~16px with a slight outward lean + a lit left edge
	for i in range(2, 17):
		bx = hx + (i-2) * out // 6
		w = 2 if i < 13 else (1 if i < 16 else 0)
		c.rect(bx-w, hy+i, bx+w, hy+i, bl[2])
		c.paint(bx-w, hy+i, bl[0])           # lit edge
		if w > 1: c.paint(bx+w, hy+i, bl[3])  # shaded edge
		if glow and i % 2 == 0:
			c.paint(bx, hy+i, glow)
	if glow:                                  # ember halo at the tip
		for (ex, ey) in ((hx+1, hy+18), (hx-1, hy+16), (hx+2, hy+14)):
			c.over(ex, ey, (glow[0], glow[1], glow[2], 120))

# ============================================================================
# Armour overlay — pauldrons (shoulder caps) + a chest plate band over the
# tunic. kit: {"metal": ramp, "trim": ramp, "rivets": bool}
# ============================================================================

def draw_armor(c, a, kit):
	m = kit["metal"]; tr = kit["trim"]
	cx, cy = a["chest"]; view = a["view"]
	if view == "side":
		# a single fore-facing breastplate + near pauldron
		c.rect(cx-2, cy-4, cx+7, cy+12, m[1]); c.rect(cx-2, cy-4, cx, cy+12, m[0])
		c.rect(cx+5, cy-4, cx+7, cy+12, m[2]); c.rect(cx-2, cy+11, cx+7, cy+12, m[3])
		sx, sy = a["sh_r"]; c.ellipse(sx, sy, 5, 4, m[1], fill=True)
		c.ellipse(sx-1, sy-1, 3, 2, m[0], fill=True); c.paint(sx+3, sy+1, m[3])
		c.rect(cx-2, cy+3, cx+7, cy+4, tr[1])
	else:
		# breastplate over the chest (front + back read the same band)
		c.rect(cx-13, cy-4, cx+13, cy+13, m[1])
		c.rect(cx-13, cy-4, cx-10, cy+13, m[0]); c.rect(cx+10, cy-4, cx+13, cy+13, m[2])
		c.rect(cx-13, cy+12, cx+13, cy+13, m[3])
		c.line(cx, cy-4, cx, cy+12, m[2])               # centre seam
		c.rect(cx-13, cy+3, cx+13, cy+4, tr[1])         # trim band
		if kit.get("rivets"):
			for rx in (cx-10, cx+9):
				c.paint(rx, cy-2, tr[0]); c.paint(rx, cy+9, tr[0])
		# pauldrons
		for key, lit in (("sh_l", m[0]), ("sh_r", m[0])):
			sx, sy = a[key]
			c.ellipse(sx, sy, 6, 4, m[1], fill=True)
			c.ellipse(sx-1, sy-1, 4, 2, lit, fill=True)
			c.paint(sx+4 if key == "sh_r" else sx-4, sy+1, m[3])

# ============================================================================
# Bake — same 4 cols x 8 rows layout + west-mirror scheme as bake_player.
# ============================================================================

def _mirror(src):
	out = Canvas(src.w, src.h)
	for y in range(src.h):
		for x in range(src.w):
			out.paint(src.w-1-x, y, src.at(x, y))
	return out

def _overlay_cell(row, phase, draw_fn, kit):
	c = Canvas(FW, FH)
	if row == 0:                anc = front_anchor(phase)
	elif row in (1, 2, 3):      anc = side_anchor(phase)
	elif row == 4:              anc = back_anchor(phase)
	else:                       anc = side_anchor(phase)   # west rows: draw right, mirror below
	draw_fn(c, anc, kit)
	return _mirror(c) if row >= 5 else c

def bake_overlay(name, draw_fn, kit):
	sheet = Canvas(FW*COLS, FH*ROWS)
	for r in range(ROWS):
		for p in range(COLS):
			sheet.blit(_overlay_cell(r, p, draw_fn, kit), p*FW, r*FH, mode="over")
	path = os.path.join(OUTDIR, name)
	sheet.save(path)
	print("wrote %s (%dx%d)" % (path, sheet.w, sheet.h))

WEAPONS = {
	"weapon_sword.png": {"blade": STEEL, "hilt": GOLD, "glow": None},
	"weapon_ember.png": {"blade": EMBER, "hilt": GOLD, "glow": (255, 196, 96, 255)},
}
ARMORS = {
	"armor_leather.png": {"metal": LEATHER, "trim": WOOD, "rivets": False},
	"armor_plate.png":   {"metal": STEEL, "trim": GOLD, "rivets": True},
}

def main():
	os.makedirs(OUTDIR, exist_ok=True)
	for name, kit in WEAPONS.items():
		bake_overlay(name, draw_weapon, kit)
	for name, kit in ARMORS.items():
		bake_overlay(name, draw_armor, kit)

if __name__ == "__main__":
	main()
