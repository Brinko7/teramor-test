#!/usr/bin/env python3
"""Preview the hero's melee swing frames (segment_rig mode="attack") as a strip so
the POSE can be tuned on disk before any engine round-trip. Draws the blade from
the weapon hand outward along the arm so the whole swing reads. Stdlib only."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
import segment_rig as S  # noqa: E402


def draw_sword(c, J, flip=False):
	hx, hy = J["hand_r"]; sx, sy = J["shoulder_r"]
	dx, dy = (hx - sx), (hy - sy)
	d = math.hypot(dx, dy) or 1.0
	ux, uy = dx / d, dy / d                 # outward along the arm
	px, py = -uy, ux                        # blade thickness axis
	for i in range(0, 44):
		bx = hx + ux * i; by = hy + uy * i
		w = 2 if i < 36 else (1 if i < 41 else 0)
		for t in range(-w, w + 1):
			col = S.STEEL[1] if t <= 0 else S.STEEL[3]
			c.paint(int(round(bx + px * t)), int(round(by + py * t)), col)
	c.disc(int(hx), int(hy), 2, S.GOLD[1])  # guard


def main():
	views = ["front", "side", "back"]
	cw, ch = S.FW, S.FH
	grid = Canvas(cw * 4, ch * len(views))
	grid.rect(0, 0, grid.w - 1, grid.h - 1, (122, 134, 120, 255))
	for r, view in enumerate(views):
		for p in range(4):
			c = S.compose(view, p, None, dressed=True, mode="attack")
			J = S.resolve(view, p, "attack")
			draw_sword(c, J)
			grid.blit(c, p * cw, r * ch, mode="over")
	grid.scaled(3).save("/tmp/attack_preview.png")
	print("wrote /tmp/attack_preview.png (rows: front/side/back, cols: windup/strike/follow/recover)")


if __name__ == "__main__":
	main()
