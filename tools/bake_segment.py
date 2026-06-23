#!/usr/bin/env python3
"""Bake the segment-rig model into game-ready 4-direction walk sheets.

The new modular character MODEL (segment_rig.py) baked to sheets the engine can
slice: 4 columns (walk phases) x 4 rows (facings down / side-right / up /
side-left=mirror). Produces the bare BASE mannequin and the novice-DRESSED
composite — both from the same joints, proving "dress = stack layers".

This is the 4-dir successor to bake_player.py's 8-dir sheet; it is ADDITIVE
(new assets), leaving the existing remaster slice untouched until the migration.

Run:  python3 tools/bake_segment.py  ->  assets/remaster/seg_*.png

Bakes the bare base, the default (ranger) walk, and one sheet per equippable
ARMOUR set (iron / plate / robe) — the wardrobe, ready to swap in-engine.
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
import segment_rig as S  # noqa: E402

FW, FH, COLS, ROWS = S.FW, S.FH, 4, 4
OUTDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "remaster"))
# row -> (view, mirror)
LAYOUT = [("front", False), ("side", False), ("back", False), ("side", True)]

def _mirror(src):
	out = Canvas(src.w, src.h)
	for y in range(src.h):
		for x in range(src.w):
			out.paint(src.w - 1 - x, y, src.at(x, y))
	return out

def bake(name, dressed=True, opts=None):
	sheet = Canvas(FW * COLS, FH * ROWS)
	for r, (view, mir) in enumerate(LAYOUT):
		for p in range(COLS):
			cell = S.compose(view, p, opts, dressed)
			if mir:
				cell = _mirror(cell)
			sheet.blit(cell, p * FW, r * FH, mode="over")
	os.makedirs(OUTDIR, exist_ok=True)
	path = os.path.join(OUTDIR, name)
	sheet.save(path)
	print("wrote %s (%dx%d, 4 dirs x 4 phases)" % (path, sheet.w, sheet.h))

def main():
	bake("seg_base.png", dressed=False)
	bake("seg_walk.png")                                  # default ranger kit
	for a in ("iron", "plate", "robe"):                   # the equippable wardrobe
		bake("seg_%s.png" % a, opts={"armor": a})

if __name__ == "__main__":
	main()
