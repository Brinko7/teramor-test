#!/usr/bin/env python3
"""Re-bake the remaster trees with proper proportions — a thick textured trunk at
~1/3 the height and a big LAYERED canopy that towers over the roofs (the earlier
pass made lollipops: a tiny crown on a long thin pole). Dims/foot-anchors match the
scene wiring so no offsets change. Stdlib only.

Run:  python3 tools/bake_trees.py  ->  assets/remaster/world/tree_{a,b,c}.png
"""
import os, sys, random, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
from gen_world import LEAF, BARK, INK  # noqa: E402

OUTDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "remaster", "world"))


def E(c, cx, cy, rx, ry, col): c.ellipse(int(cx), int(cy), int(rx), int(ry), col, fill=True)


def tree(c, bx, by, h, spread, trunk_frac, seed):
	rnd = random.Random(seed)
	tw = max(7, spread // 7)
	trunk_top = by - int(h * trunk_frac)
	# trunk (lit left, shaded right, bark grain)
	c.rect(bx - tw, trunk_top, bx + tw, by, BARK[2])
	c.rect(bx - tw, trunk_top, bx - tw + 3, by, BARK[1])
	c.rect(bx + tw - 3, trunk_top, bx + tw, by, BARK[3])
	for ry in range(trunk_top, by, 10):
		c.line(bx - tw + 2, ry, bx + tw - 2, ry + 3, BARK[3])
	c.rect(bx - tw - 5, by - 6, bx + tw + 5, by, BARK[3])           # root flare
	E(c, bx, by, tw + 7, 4, BARK[3])
	# canopy: a big dark base mass + overlapping lit clumps + speckle
	ctop = by - h + 4
	cbot = trunk_top + 16
	ccy = (ctop + cbot) // 2
	big_ry = (cbot - ctop) // 2
	E(c, bx, ccy, spread, big_ry, LEAF[3])
	clumps = []
	for _ in range(11):
		a = rnd.uniform(0, 6.28); rr = rnd.uniform(0, spread * 0.66)
		ex = bx + rr * math.cos(a); ey = ccy + rr * 0.82 * math.sin(a)
		rx = rnd.randint(spread // 4, spread // 2); ry = rx * 3 // 4
		clumps.append((ex, ey, rx, ry))
	for ex, ey, rx, ry in clumps: E(c, ex, ey, rx, ry, LEAF[3])
	for ex, ey, rx, ry in clumps: E(c, ex - rx // 4, ey - ry // 4, rx * 3 // 4, ry * 3 // 4, LEAF[2])
	for ex, ey, rx, ry in clumps: E(c, ex - rx // 3, ey - ry // 3, rx // 2, ry // 2, LEAF[1])
	for _ in range(int(spread * 2.4)):                              # leaf speckle + top highlights
		a = rnd.uniform(0, 6.28); rr = rnd.uniform(0, spread * 0.95)
		lx = int(bx + rr * math.cos(a)); ly = int(ccy + rr * 0.8 * math.sin(a) - big_ry // 5)
		c.paint(lx, ly, LEAF[0] if rnd.random() < 0.42 else LEAF[4])


def main():
	# (name, w, h, foot_y, spread, trunk_frac, seed) — dims match the scene offsets
	specs = [
		("tree_a.png", 128, 298, 294, 62, 0.32, 11),   # round oak
		("tree_b.png", 100, 284, 280, 44, 0.36, 7),    # narrower
		("tree_c.png", 130, 262, 258, 66, 0.30, 23),   # wide
	]
	os.makedirs(OUTDIR, exist_ok=True)
	for name, w, h, fy, spread, tf, seed in specs:
		c = Canvas(w, h)
		tree(c, w // 2, fy, h - 4, spread, tf, seed)
		c.outline(INK, diagonal=False)
		c.save(os.path.join(OUTDIR, name))
		print("wrote %s (%dx%d, offset Vector2(%d,%d))" % (name, w, h, -(w // 2), -fy))


if __name__ == "__main__":
	main()
