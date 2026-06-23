#!/usr/bin/env python3
"""Per-weapon ATTACK OVERLAY sheets that ride the hero's hands.

11-column / 4-row layout matching the body layers (cols 0-3 walk, 4-7 melee swing,
8-10 bow draw — all transparent except this weapon's own frames). Stacked over the
body and synced to the frame index, so the blade sweeps with the swinging hand and
the bow + drawn string + nocked arrow ride the draw — no floating sprites. Stdlib.

Run:  python3 tools/bake_weapon_overlay.py
      -> assets/remaster/char/{weapon_sword_atk, weapon_bow_draw}.png
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
import segment_rig as S  # noqa: E402

FW, FH = S.FW, S.FH
WALK_COLS, ATK_COLS, DRAW_COLS = 4, 4, 3
COLS = WALK_COLS + ATK_COLS + DRAW_COLS
LAYOUT = [("front", False), ("back", False), ("side", True), ("side", False)]
OUTDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "remaster", "char"))
STEEL = S.STEEL; GOLD = S.GOLD; INK = S.INK; WOOD = S.LEA
STRING = (230, 226, 214, 255); SHAFT = (158, 120, 82, 255)
AIM = {"front": (0, 1), "side": (1, 0), "back": (0, -1)}


def _mirror(src):
	out = Canvas(src.w, src.h)
	for y in range(src.h):
		for x in range(src.w):
			out.paint(src.w - 1 - x, y, src.at(x, y))
	return out


def draw_blade(c, J, _aim=None, length=44):
	"""A sword in the weapon fist, blade extending out along the arm direction."""
	import math
	hx, hy = J["hand_r"]; sx, sy = J["shoulder_r"]
	dx, dy = (hx - sx), (hy - sy); d = math.hypot(dx, dy) or 1.0
	ux, uy = dx / d, dy / d; px, py = -uy, ux
	for t in range(-3, 4):
		c.paint(int(round(hx + px * t)), int(round(hy + py * t)), GOLD[1] if abs(t) < 3 else GOLD[2])
	c.disc(int(round(hx - ux * 3)), int(round(hy - uy * 3)), 1, GOLD[0])
	for i in range(2, length):
		bx = hx + ux * i; by = hy + uy * i
		w = 2 if i < length - 7 else (1 if i < length - 3 else 0)
		for t in range(-w, w + 1):
			c.paint(int(round(bx + px * t)), int(round(by + py * t)), STEEL[1] if t <= 0 else STEEL[3])
		if w > 0:
			c.paint(int(round(bx + px * -w)), int(round(by + py * -w)), STEEL[0])


def draw_bow(c, J, aim):
	"""A recurve bow in the bow hand, string drawn back to the off hand + nocked arrow."""
	hx, hy = J["hand_r"]; lx, ly = J["hand_l"]
	ux, uy = aim; px, py = -uy, ux
	t1 = (hx + px * 14 + ux * 3, hy + py * 14 + uy * 3)
	t2 = (hx - px * 14 + ux * 3, hy - py * 14 + uy * 3)
	for tx, ty in (t1, t2):                                         # limbs (2px, bowing toward the aim)
		mx, my = (hx + tx) / 2 + ux * 5, (hy + ty) / 2 + uy * 5
		for ax, ay, bx2, by2 in ((hx, hy, mx, my), (mx, my, tx, ty)):
			c.line(int(ax), int(ay), int(bx2), int(by2), WOOD[2])
			c.line(int(ax) + 1, int(ay), int(bx2) + 1, int(by2), WOOD[1])
	c.line(int(t1[0]), int(t1[1]), int(lx), int(ly), STRING)        # drawn string (V to off hand)
	c.line(int(t2[0]), int(t2[1]), int(lx), int(ly), STRING)
	tip = (hx + ux * 24, hy + uy * 24)                              # arrow: nock at string, out past the bow
	c.line(int(lx), int(ly), int(tip[0]), int(tip[1]), SHAFT)
	c.line(int(lx) + 1, int(ly), int(tip[0]) + 1, int(tip[1]), (120, 88, 56, 255))
	c.disc(int(tip[0]), int(tip[1]), 1, STEEL[1])


def bake(name, col_start, n_cols, mode, draw_fn):
	sheet = Canvas(FW * COLS, FH * 4)
	for r, (view, mir) in enumerate(LAYOUT):
		for p in range(n_cols):
			c = Canvas(FW, FH)
			draw_fn(c, S.resolve(view, p, mode), AIM[view])
			c.outline(INK, diagonal=False)
			if mir:
				c = _mirror(c)
			sheet.blit(c, (col_start + p) * FW, r * FH, mode="over")
	os.makedirs(OUTDIR, exist_ok=True)
	sheet.save(os.path.join(OUTDIR, name))
	print("wrote char/%s (%dx%d)" % (name, sheet.w, sheet.h))


def main():
	bake("weapon_sword_atk.png", WALK_COLS, ATK_COLS, "attack", draw_blade)
	bake("weapon_bow_draw.png", WALK_COLS + ATK_COLS, DRAW_COLS, "draw", draw_bow)


if __name__ == "__main__":
	main()
