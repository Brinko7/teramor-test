#!/usr/bin/env python3
"""Bake the named NPC cast as remaster 4-dir walk sheets (the segment rig).

Every talkable/named NPC becomes a foot-anchored 84x120 sheet, 4 columns (walk
phases) x 4 rows in DirUtil's cardinal order (down / up / left / right), composed
from the SAME segment_rig the live hero uses — so the whole cast is one cohesive,
animated, scale-correct style instead of the old 24x40 villager clones. Each NPC
keeps an armour set's piece styles but recolours them (per-character `cloak/tunic/
trouser` overrides) so they read as individuals.

Run:  python3 tools/bake_remaster_cast.py  ->  assets/remaster/cast/npc_*.png
      (+ a few generic villagers for the cosmetic town crowd)
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
import segment_rig as S  # noqa: E402
from segment_rig import RANGER_CLOAK, ROGUE_CLOAK  # noqa: E402
from gen_cast import SKIN, HAIR, CLOTH  # noqa: E402

FW, FH, COLS = S.FW, S.FH, 4
OUTDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "remaster", "cast"))
# DirUtil 4-row cardinal order: down / up / left / right (left = mirror of side).
LAYOUT = [("front", False), ("back", False), ("side", True), ("side", False)]

# Each NPC: an armour-set silhouette + a recolour + their own face (skin/hair/beard).
# Matches each portrait's identity; cloak=None means a plain working tunic, no cape.
CAST = {
	"elkar":   {"armor": "ranger", "skin": SKIN["tan"],   "hair": HAIR["grey"],  "hair_style": "short", "beard": "full",
	            "cloak": RANGER_CLOAK, "tunic": CLOTH["green"], "trouser": CLOTH["brown"]},
	"bram":    {"armor": "ranger", "skin": SKIN["tan"],   "hair": HAIR["brown"], "hair_style": "short", "beard": "stubble",
	            "cloak": None, "tunic": CLOTH["mustard"], "trouser": CLOTH["brown"], "build": "broad"},
	"wrenna":  {"armor": "ranger", "skin": SKIN["fair"],  "hair": HAIR["red"],   "hair_style": "long",
	            "cloak": RANGER_CLOAK, "tunic": CLOTH["green"], "trouser": CLOTH["brown"]},
	"sorrel":  {"armor": "rogue",  "skin": SKIN["fair"],  "hair": HAIR["black"], "hair_style": "long",
	            "cloak": ROGUE_CLOAK, "tunic": CLOTH["green"]},
	"maelon":  {"armor": "robe",   "skin": SKIN["fair"],  "hair": HAIR["grey"],  "hair_style": "bald",  "beard": "full",
	            "tunic": CLOTH["plum"], "trouser": CLOTH["slate"]},
	"pell":    {"armor": "ranger", "skin": SKIN["brown"], "hair": HAIR["black"], "hair_style": "short", "build": "broad",
	            "cloak": None, "tunic": CLOTH["rust"], "trouser": CLOTH["slate"]},
	"hadrin":  {"armor": "ranger", "skin": SKIN["tan"],   "hair": HAIR["black"], "hair_style": "short", "beard": "full", "build": "broad",
	            "cloak": None, "tunic": CLOTH["brown"], "trouser": CLOTH["slate"]},
	"mara":    {"armor": "ranger", "skin": SKIN["fair"],  "hair": HAIR["brown"], "hair_style": "long",
	            "cloak": None, "tunic": CLOTH["mustard"], "trouser": CLOTH["slate"]},
}

# Cosmetic townsfolk pool (no identity; just varied bodies for the crowd).
VILLAGERS = {
	"villager_a": {"armor": "ranger", "skin": SKIN["fair"],  "hair": HAIR["brown"], "hair_style": "short",
	               "cloak": None, "tunic": CLOTH["blue"],   "trouser": CLOTH["slate"]},
	"villager_b": {"armor": "ranger", "skin": SKIN["brown"], "hair": HAIR["black"], "hair_style": "long",
	               "cloak": None, "tunic": CLOTH["rust"],   "trouser": CLOTH["brown"]},
	"villager_c": {"armor": "ranger", "skin": SKIN["tan"],   "hair": HAIR["blond"], "hair_style": "short", "beard": "goatee",
	               "cloak": None, "tunic": CLOTH["cream"],  "trouser": CLOTH["slate"], "build": "broad"},
}


def _mirror(src):
	out = Canvas(src.w, src.h)
	for y in range(src.h):
		for x in range(src.w):
			out.paint(src.w - 1 - x, y, src.at(x, y))
	return out


def bake(name, opts):
	sheet = Canvas(FW * COLS, FH * 4)
	for r, (view, mir) in enumerate(LAYOUT):
		for p in range(COLS):
			cell = S.compose(view, p, opts, dressed=True)
			if mir:
				cell = _mirror(cell)
			sheet.blit(cell, p * FW, r * FH, mode="over")
	sheet.save(os.path.join(OUTDIR, name))
	print("wrote cast/%s (%dx%d, 4 dirs x 4 phases)" % (name, sheet.w, sheet.h))


def main():
	os.makedirs(OUTDIR, exist_ok=True)
	for cid, opts in CAST.items():
		bake("npc_%s.png" % cid, opts)
	for vid, opts in VILLAGERS.items():
		bake("%s.png" % vid, opts)


if __name__ == "__main__":
	main()
