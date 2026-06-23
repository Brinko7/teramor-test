#!/usr/bin/env python3
"""Preview the hero's BOW DRAW (segment_rig mode="draw") with a bow + drawn string +
nocked arrow, so the pose can be tuned on disk. Rows: front/side/back; cols: nock,
full-draw, loose. Stdlib only."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
import segment_rig as S  # noqa: E402

AIM = {"front": (0, 1), "side": (1, 0), "back": (0, -1)}
STRING = (230, 226, 214, 255)
SHAFT = (158, 120, 82, 255)


def draw_bow(c, J, aim):
	hx, hy = J["hand_r"]; lx, ly = J["hand_l"]
	ux, uy = aim; px, py = -uy, ux                 # perp = limb axis
	W = S.LEA
	t1 = (hx + px * 13 + ux * 3, hy + py * 13 + uy * 3)
	t2 = (hx - px * 13 + ux * 3, hy - py * 13 + uy * 3)
	for tx, ty in (t1, t2):                         # two limbs, bowing toward the aim
		mx, my = (hx + tx) / 2 + ux * 4, (hy + ty) / 2 + uy * 4
		c.line(int(hx), int(hy), int(mx), int(my), W[2]); c.line(int(mx), int(my), int(tx), int(ty), W[2])
		c.line(int(hx) + 1, int(hy), int(mx) + 1, int(my), W[1])
	c.line(int(t1[0]), int(t1[1]), int(lx), int(ly), STRING)   # drawn string (a V to the off hand)
	c.line(int(t2[0]), int(t2[1]), int(lx), int(ly), STRING)
	tip = (hx + ux * 22, hy + uy * 22)              # arrow: nocked at the string, out past the bow
	c.line(int(lx), int(ly), int(tip[0]), int(tip[1]), SHAFT)
	c.disc(int(tip[0]), int(tip[1]), 1, S.STEEL[1])


def main():
	views = ["front", "side", "back"]
	cw, ch = S.FW, S.FH
	grid = Canvas(cw * 3, ch * len(views))
	grid.rect(0, 0, grid.w - 1, grid.h - 1, (122, 134, 120, 255))
	for r, view in enumerate(views):
		for p in range(3):
			c = S.compose(view, p, None, dressed=True, mode="draw")
			draw_bow(c, S.resolve(view, p, "draw"), AIM[view])
			grid.blit(c, p * cw, r * ch, mode="over")
	grid.scaled(3).save("/tmp/bow_preview.png")
	print("wrote /tmp/bow_preview.png (rows front/side/back, cols nock/draw/loose)")


if __name__ == "__main__":
	main()
