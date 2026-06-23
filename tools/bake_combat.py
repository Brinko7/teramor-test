#!/usr/bin/env python3
"""Combat-animation art for the remaster hero — a real swinging ARM + scaled
weapons, so an attack reads as the *character* striking, not a floating icon.

All oriented +X (along the aim direction) so player_visuals can rotate one pivot
to point/sweep them. Foot of the arm = the shoulder (the rotation point); the
weapon grip sits out at the fist. Sized for the 84x120 hero (the old held sprites
were ~14px — invisible at this scale). Stdlib only.

Run:  python3 tools/bake_combat.py  ->  assets/remaster/combat/{attack_arm,
      sword_hold,bow_hold,arrow}.png
"""

import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
from gen_cast import CLOTH, LEA, GOLD, INK  # noqa: E402

OUTDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "remaster", "combat"))
SLEEVE = CLOTH["green"]                 # ranger sleeve
STEEL = [(228, 234, 244, 255), (196, 204, 218, 255), (150, 160, 178, 255), (104, 114, 134, 255), (72, 80, 96, 255)]
WOOD  = [(166, 126, 84, 255), (138, 100, 62, 255), (110, 78, 46, 255), (82, 56, 32, 255)]
STRING = (228, 224, 212, 255)


def arm():
	"""Sleeved upper+forearm with a gloved fist, +X, pivot at the shoulder (4,9)."""
	c = Canvas(56, 18)
	G, L = SLEEVE, LEA
	c.ellipse(7, 9, 6, 7, G[2], fill=True)                       # shoulder/pauldron
	c.ellipse(6, 8, 4, 5, G[1], fill=True)
	c.rect(5, 5, 27, 13, G[2]); c.rect(5, 5, 27, 6, G[1]); c.rect(5, 12, 27, 13, G[3])   # upper arm
	c.ellipse(27, 9, 5, 5, G[2], fill=True)                      # elbow
	c.rect(27, 6, 41, 12, G[2]); c.rect(27, 6, 41, 7, G[1]); c.rect(27, 11, 41, 12, G[3])  # forearm
	c.rect(40, 5, 44, 13, L[3])                                  # glove cuff
	c.ellipse(48, 9, 6, 6, L[2], fill=True)                      # fist
	c.ellipse(47, 8, 4, 4, L[1], fill=True); c.paint(45, 7, L[0])
	c.outline(INK, diagonal=False)
	c.save(os.path.join(OUTDIR, "attack_arm.png"))
	print("wrote combat/attack_arm.png (56x18, pivot offset (-4,-9))")


def sword():
	"""A blade, +X, grip at the left (in the fist), tip at the right."""
	c = Canvas(64, 16); S, G = STEEL, GOLD
	c.rect(0, 6, 9, 10, LEA[3]); c.rect(0, 6, 9, 7, LEA[2])      # wrapped grip
	c.disc(1, 8, 2, G[1]); c.paint(0, 7, G[0])                   # pommel
	c.rect(9, 3, 12, 13, G[1]); c.rect(9, 3, 12, 4, G[0])        # crossguard
	tip = 60
	for i in range(12, tip):
		t = (i - 12) / (tip - 12)
		half = max(0, int(round(4 * (1 - t))))
		if half < 1:
			c.paint(i, 8, S[1]); continue
		c.rect(i, 8 - half, i, 8 + half, S[2])
		c.paint(i, 8 - half, S[0])                               # lit top edge
		c.paint(i, 8 + half, S[3])                               # shaded underside
	for i in range(13, tip - 4, 2):
		c.paint(i, 8, S[1])                                      # fuller sheen
	c.outline(INK, diagonal=False)
	c.save(os.path.join(OUTDIR, "sword_hold.png"))
	print("wrote combat/sword_hold.png (64x16, grip-centre offset (0,-8))")


def bow():
	"""A recurve bow, belly facing +X, limbs vertical; grip centred at (8,28)."""
	c = Canvas(24, 58); W = WOOD
	for y in range(4, 53):
		t = (y - 4) / 48.0
		bx = 5 + int(round(9 * math.sin(math.pi * t)))           # belly bulges +X
		c.paint(bx, y, W[1]); c.paint(bx + 1, y, W[0]); c.paint(bx - 1, y, W[2])
	c.line(5, 6, 5, 50, STRING)                                  # string (rest, near side)
	c.rect(5, 24, 9, 33, W[2]); c.rect(5, 24, 6, 33, W[1])       # grip wrap
	c.paint(5, 4, W[3]); c.paint(5, 52, W[3])                    # limb tips (nocks)
	c.outline(INK, diagonal=False)
	c.save(os.path.join(OUTDIR, "bow_hold.png"))
	print("wrote combat/bow_hold.png (24x58, grip-centre offset (-8,-28))")


def arrow():
	"""A flighted arrow, +X, ~30px — the loosed projectile, scaled to the hero."""
	c = Canvas(34, 10)
	c.rect(2, 4, 26, 5, WOOD[1]); c.rect(2, 5, 26, 6, WOOD[2])   # shaft
	c.line(26, 1, 32, 5, STEEL[1]); c.line(26, 8, 32, 5, STEEL[1])  # head
	c.line(27, 2, 32, 5, STEEL[0]); c.paint(32, 5, STEEL[0])
	for fx in (2, 5):                                            # fletching
		c.line(fx, 1, fx + 4, 4, CLOTH["rust"][1]); c.line(fx, 9, fx + 4, 6, CLOTH["rust"][2])
	c.outline(INK, diagonal=False)
	c.save(os.path.join(OUTDIR, "arrow.png"))
	print("wrote combat/arrow.png (34x10, mid offset (-16,-5))")


def main():
	os.makedirs(OUTDIR, exist_ok=True)
	arm(); sword(); bow(); arrow()


if __name__ == "__main__":
	main()
