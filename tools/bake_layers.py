#!/usr/bin/env python3
"""Bake the segment model as SEPARATED, tintable paper-doll layers for the live
game (character creator + player).

Unlike bake_segment.py (which bakes flat composites for previews), this emits the
stackable layers the engine needs to render a *customizable* hero:
  * body_<tone>      — the bare body incl. the face, one full-colour sheet per
                       skin tone (picked, not modulated, so the eyes stay right).
  * hair_<style>     — neutral grey, tinted by hair colour via modulate in-engine.
  * beard_<style>    — neutral grey, tinted likewise.
  * outfit/helm/collar/cloakback_<set> — the gear of each armour set, split so the
                       helm sits over the hair and the cloak hangs behind the body.

4 directions in DirUtil's cardinal row order (down=0, up=1, left=2, right=3),
84x120 cells. Engine stack order, back to front:
  cloakback < body < outfit < beard < hair < helm < collar < (weapon/shield)

Run: python3 tools/bake_layers.py  ->  assets/remaster/char/*.png
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
import segment_rig as S  # noqa: E402
from gen_cast import SKIN  # noqa: E402

FW, FH, COLS = S.FW, S.FH, 4
OUTDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "remaster", "char"))
# DirUtil 4-row cardinal order: down / up / left / right  (left = mirror of side)
LAYOUT = [("front", False), ("back", False), ("side", True), ("side", False)]
# neutral grey hair ramp: modulate by the chosen hair colour reproduces a shaded tint
NEUTRAL_HAIR = [(252, 250, 248, 255), (214, 210, 206, 255), (172, 168, 164, 255), (128, 124, 122, 255), (90, 88, 88, 255)]
SKINS = ("fair", "tan", "brown", "deep")
STYLES = ("short", "long", "spiky", "ponytail", "bun", "bald")
BEARDS = ("stubble", "goatee", "full")


def _mirror(src):
	out = Canvas(src.w, src.h)
	for y in range(src.h):
		for x in range(src.w):
			out.paint(src.w - 1 - x, y, src.at(x, y))
	return out


def bake(name, parts, opts, mode="walk"):
	sheet = Canvas(FW * COLS, FH * 4)
	for r, (view, mir) in enumerate(LAYOUT):
		for p in range(COLS):
			cell = S.compose(view, p, opts, True, mode=mode, parts=parts)
			if mir:
				cell = _mirror(cell)
			sheet.blit(cell, p * FW, r * FH, mode="over")
	os.makedirs(OUTDIR, exist_ok=True)
	sheet.save(os.path.join(OUTDIR, name))
	print("wrote char/%s (%dx%d)" % (name, sheet.w, sheet.h))


def main():
	for tone in SKINS:                                            # body per skin tone (face baked in)
		bake("body_%s.png" % tone, {"body"}, {"skin": SKIN[tone]})
	for st in STYLES:                                             # hair, neutral grey -> tinted in-engine
		bake("hair_%s.png" % st, {"hair"}, {"hair": NEUTRAL_HAIR, "hair_style": st})
	for bd in BEARDS:
		bake("beard_%s.png" % bd, {"beard"}, {"hair": NEUTRAL_HAIR, "beard": bd})
	for a, SET in S.ARMOR.items():                               # gear per armour set
		bake("outfit_%s.png" % a, {"outfit"}, {"armor": a})
		if SET.get("helm", "none") != "none":
			bake("helm_%s.png" % a, {"helm"}, {"armor": a})
		if SET.get("cloak") is not None:
			bake("cloakback_%s.png" % a, {"cloak_back"}, {"armor": a})
			bake("collar_%s.png" % a, {"cloak_collar"}, {"armor": a})


if __name__ == "__main__":
	main()
