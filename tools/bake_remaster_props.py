#!/usr/bin/env python3
"""Bake remaster world props + NPCs as individual FOOT-ANCHORED sprites for the
in-engine vertical slice.

Each prop is drawn into a tight canvas with its visual base near the bottom, so
the slice scene can place it with `offset = (-anchor_x, -anchor_y)` and y-sort it
against the player by its feet (the foot-anchoring convention in CLAUDE.md). The
draw routines are reused from gen_world (cottage / tree) and gen_cast (NPCs) so
the slice matches the composed mockup exactly. Stdlib only.

Run:  python3 tools/bake_remaster_props.py  ->  assets/remaster/{cottage,tree,
      npc_bram,npc_wrenna}.png  (+ prints each sprite's foot-anchor)
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
import gen_world as W  # noqa: E402  (cottage / tree / palettes)
from gen_cast import draw_character, INK  # noqa: E402

OUTDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "remaster"))

# Each entry: (filename, canvas_w, canvas_h, anchor_x, anchor_y, draw_fn)
# anchor = the pixel that should land on the node origin (bottom-centre of the base).

def _tree(c):
    W.tree(c, 46, 126)
    c.outline(INK, diagonal=False)

def _cottage(c):
    W.cottage(c, 15, 180)
    c.outline(INK, diagonal=False)

def _npc(opts):
    def f(c):
        draw_character(c, 42, opts)   # draw_character already outlines
    return f

PROPS = [
    ("tree.png",    92, 128, 46, 126, _tree),
    ("cottage.png", 150, 185, 75, 180, _cottage),
    ("npc_bram.png", 84, 120, 42, 112, _npc({
        "skin": "tan", "hair": "brown", "hair_style": "short", "tunic": "mustard",
        "trouser": "brown", "apron": "brown", "freckles": True})),
    ("npc_wrenna.png", 84, 120, 42, 112, _npc({
        "skin": "fair", "hair": "red", "hair_style": "long", "cloak": "green",
        "tunic": "green", "trouser": "brown", "freckles": True})),
]

def main():
    os.makedirs(OUTDIR, exist_ok=True)
    for name, w, h, ax, ay, fn in PROPS:
        c = Canvas(w, h)
        fn(c)
        path = os.path.join(OUTDIR, name)
        c.save(path)
        print("wrote %s (%dx%d, foot-anchor offset = Vector2(%d, %d))"
              % (path, w, h, -ax, -ay))

if __name__ == "__main__":
    main()
