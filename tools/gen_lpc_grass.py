#!/usr/bin/env python3
"""A clean, seamless 32x32 grass fill tile in LPC tones (the LPC base grass.png has
no seamless interior cell, so its crop bands when tiled). Utility fill — detail
tufts/flowers come from real LPC decals on top. Stdlib (pixelforge)."""
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "lpc", "tiles", "grass_clean.png"))
BASE = (96, 142, 62, 255); MID = (80, 124, 52, 255); DARK = (64, 104, 44, 255); LITE = (124, 168, 86, 255)


def main():
	c = Canvas(32, 32)
	rnd = random.Random(11)
	for y in range(32):
		for x in range(32):
			r = rnd.random()
			c.paint(x, y, BASE if r < 0.6 else (MID if r < 0.85 else DARK))
	for _ in range(46):                       # little grass blades (1-2px), wrap-safe
		x = rnd.randrange(32); y = rnd.randrange(32)
		col = LITE if rnd.random() < 0.55 else DARK
		c.paint(x, y, col)
		if rnd.random() < 0.6:
			c.paint(x, (y - 1) % 32, col)
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	c.save(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()
