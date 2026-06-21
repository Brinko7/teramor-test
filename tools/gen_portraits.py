#!/usr/bin/env python3
"""Portrait bust generator for Teramor, built on pixelforge.

Bakes head-and-shoulders portraits for the named NPCs — shown beside their lines
in the dialogue box — with a neutral and a happy expression each. Same grounded
palette and upper-left key light as the character sheets (gen_char.py), just at a
portrait scale with real face features. Dependency-free via pixelforge.

  python3 tools/gen_portraits.py     # (re)bake assets/placeholder/portraits/*.png
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas, P, rgb, shade  # noqa: E402

W, H = 44, 48
CX = 22  # horizontal centre
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..",
                                    "assets", "placeholder", "portraits"))

# Grounded identity palettes (skin / hair / collar accent), same family as the
# character sheets so a portrait reads as the same person as the world sprite.
SKIN = {
	"pale": rgb(238, 206, 176), "tan": rgb(214, 168, 126),
	"brown": rgb(158, 108, 74), "deep": rgb(112, 78, 54),
}
HAIR = {
	"black": rgb(54, 46, 44), "brown": rgb(96, 64, 38), "auburn": rgb(132, 64, 40),
	"blonde": rgb(200, 162, 96), "white": rgb(220, 220, 224), "ash": rgb(150, 150, 156),
}
CLOTH = {
	"olive": rgb(96, 110, 74), "green": rgb(78, 116, 82), "rust": rgb(150, 86, 60),
	"brown": rgb(110, 84, 58), "plum": rgb(108, 84, 116), "slate": rgb(92, 100, 112),
}

EYE_WHITE = rgb(232, 228, 220)
PUPIL = rgb(60, 50, 48)


def bust(skin_key, hair_key, style, cloth_key, beard=False, expr="neutral"):
	c = Canvas(W, H)
	sk = SKIN[skin_key]
	sk_hi, sk_sh, sk_sh2 = shade(sk, 1.12), shade(sk, 0.84), shade(sk, 0.72)
	hc = HAIR[hair_key]
	hc_hi, hc_sh, hc_dk = shade(hc, 1.2), shade(hc, 0.78), shade(hc, 0.64)
	cl = CLOTH[cloth_key]
	cl_hi, cl_sh, cl_dk = shade(cl, 1.15), shade(cl, 0.78), shade(cl, 0.6)

	# --- shoulders / chest (a widening trapezoid) ---
	for i, y in enumerate(range(37, H)):
		half = min(20, 11 + i)
		c.rect(CX - half, y, CX + half, y, cl)
	c.rect(CX - 19, 39, CX - 11, 41, cl_hi)     # lit left shoulder
	c.rect(CX + 11, 39, CX + 19, 47, cl_sh)     # right in shadow
	c.line(CX - 5, 37, CX - 1, 42, cl_dk)       # collar V
	c.line(CX + 5, 37, CX + 1, 42, cl_dk)
	c.rect(CX - 1, 38, CX, 41, sk_sh)           # neck shadow inside the collar

	# --- neck ---
	c.rect(CX - 3, 32, CX + 2, 38, sk_sh)
	c.rect(CX - 3, 32, CX - 2, 37, sk)          # lit left edge of neck
	c.rect(CX - 1, 31, CX + 1, 32, sk_sh2)      # under-jaw shadow

	# --- head ---
	c.ellipse(CX, 21, 10, 12, sk)
	c.rect(13, 26, 31, 31, sk)                  # squarer jaw
	c.rect(27, 14, 30, 30, sk_sh)               # right cheek in shadow
	c.rect(28, 17, 30, 29, sk_sh2)
	c.rect(13, 13, 15, 27, sk_hi)               # lit left cheek
	c.rect(16, 11, 27, 12, sk_hi)               # forehead catch-light
	c.rect(12, 20, 13, 24, sk_sh)               # ears
	c.rect(31, 20, 32, 24, sk_sh2)

	# --- hair ---
	if style != "bald":
		c.ellipse(CX, 12, 12, 6, hc)            # rounded top
		c.rect(11, 9, 33, 12, hc)               # crown band
		c.rect(12, 12, 14, 22, hc_sh)           # side strands
		c.rect(30, 12, 32, 22, hc_dk)
		c.rect(14, 9, 21, 10, hc_hi)            # top highlight
		if style == "long":
			c.rect(11, 14, 13, 40, hc)          # curtains to the shoulders
			c.rect(31, 14, 33, 40, hc_dk)
			c.rect(13, 22, 14, 40, hc_sh)
			c.rect(30, 22, 31, 40, hc_dk)
	else:
		c.rect(13, 11, 31, 12, hc_sh)           # thin balding wisp
		c.rect(12, 17, 14, 26, hc_sh)           # hair only at the sides
		c.rect(30, 17, 32, 26, hc_dk)
		c.rect(15, 12, 28, 13, sk_hi)           # bald pate catches the light

	# --- brows ---
	brow = shade(hc, 0.7) if hair_key not in ("white", "ash") else shade(sk, 0.58)
	lift = 1 if expr == "happy" else 0
	c.rect(16, 18 - lift, 19, 18 - lift, brow)
	c.rect(25, 18 - lift, 28, 18 - lift, brow)

	# --- eyes ---
	c.rect(16, 20, 18, 21, EYE_WHITE)
	c.rect(25, 20, 27, 21, EYE_WHITE)
	if expr == "happy":
		c.paint(17, 20, PUPIL)
		c.paint(26, 20, PUPIL)
		c.rect(16, 21, 18, 21, sk_sh)           # cheeks raised under a smile
		c.rect(25, 21, 27, 21, sk_sh)
	else:
		c.paint(17, 21, PUPIL)
		c.paint(26, 21, PUPIL)
		c.paint(18, 20, sk_sh2)
		c.paint(27, 20, sk_sh2)

	# --- nose ---
	c.rect(22, 22, 22, 25, sk_sh)
	c.paint(21, 25, sk_sh2)
	c.paint(22, 26, sk_sh2)

	# --- beard / mouth ---
	if beard:
		c.rect(15, 27, 29, 33, hc)
		c.rect(15, 27, 16, 32, hc_sh)
		c.rect(28, 27, 29, 33, hc_dk)
		c.rect(17, 33, 27, 34, hc_dk)
		mouth = shade(hc, 0.5)
		if expr == "happy":
			c.rect(20, 30, 24, 30, mouth)
			c.paint(19, 29, mouth)
			c.paint(25, 29, mouth)
		else:
			c.rect(20, 30, 24, 30, mouth)
	else:
		mouth = shade(sk, 0.58)
		lip = shade(sk, 0.78)
		if expr == "happy":
			c.rect(19, 29, 25, 29, mouth)
			c.paint(18, 28, mouth)              # upturned corners
			c.paint(26, 28, mouth)
			c.rect(20, 30, 24, 30, shade(sk, 0.5))
		else:
			c.rect(20, 29, 24, 29, mouth)
			c.rect(20, 30, 24, 30, lip)

	c.outline(P.OUTLINE)
	return c


# id, skin, hair, hair style, collar accent, beard — each a recognisable individual.
PORTRAITS = [
	("bram",         "tan",   "brown",  "short", "olive", False),
	("wrenna",       "pale",  "auburn", "long",  "green", False),
	("pell",         "brown", "black",  "short", "rust",  False),
	("hadrin",       "tan",   "black",  "short", "brown", True),
	("mara",         "pale",  "brown",  "long",  "plum",  False),
	("elder_maelon", "pale",  "white",  "bald",  "slate", True),
	("elkar",        "tan",   "ash",    "short", "brown", True),   # weathered ranger, greying
	("sorrel",       "pale",  "black",  "long",  "green", False),  # a Child of Tera, forest-cloaked
]


def bake_all():
	os.makedirs(OUT, exist_ok=True)
	print("gen_portraits: baking -> %s" % OUT)
	for (id_, skin, hair, style, cloth, beard) in PORTRAITS:
		for expr in ("neutral", "happy"):
			c = bust(skin, hair, style, cloth, beard, expr)
			suffix = "" if expr == "neutral" else "_happy"
			c.save(os.path.join(OUT, "portrait_%s%s.png" % (id_, suffix)))
			print("  baked portrait_%s%s" % (id_, suffix))
	print("gen_portraits: done.")


if __name__ == "__main__":
	bake_all()
