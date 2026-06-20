#!/usr/bin/env python3
"""Shop OPEN/CLOSED placard for Teramor.

A small wooden counter sign on a stand whose card flips colour with business
hours: a green card means the keeper is in and trading; a red card means the
shop is shut. No lettering (the pixel toolkit has no font) — the green/red card
is the universal cue, kept a touch more saturated than the world palette because
a status sign is a deliberate, eye-catching accent.

Baked as a 2-frame horizontal sheet for a Sprite2D with hframes=2:
  frame 0 = OPEN (green)   frame 1 = CLOSED (red)

  shop_sign.png   48x18   (two 24x18 frames)

Run:  python3 tools/gen_shopsign.py
"""

from pixelforge import Canvas, P, asset, rgb

FW = 24
FH = 18

OPEN_CARD = rgb(96, 150, 80)
OPEN_LIGHT = rgb(128, 182, 106)
CLOSED_CARD = rgb(168, 62, 50)
CLOSED_LIGHT = rgb(202, 92, 72)


def draw_sign(c, ox, card, card_light):
    # Stand legs (an A-frame footing) first, so the board overlaps their tops.
    c.vline(ox + 8, 12, 16, P.WOOD[3])
    c.vline(ox + 15, 12, 16, P.WOOD[3])
    c.paint(ox + 8, 16, P.WOOD[2])
    c.paint(ox + 15, 16, P.WOOD[2])
    # Wooden board.
    c.rect(ox + 5, 2, ox + 18, 13, P.WOOD[2])
    c.frame(ox + 5, 2, ox + 18, 13, P.WOOD[3])
    c.hline(ox + 5, ox + 18, 2, P.WOOD[1])      # lit top edge
    # The status card inset in the board.
    c.rect(ox + 7, 4, ox + 16, 11, card)
    c.hline(ox + 7, ox + 16, 4, card_light)      # top sheen
    c.paint(ox + 8, 5, card_light)
    # A little metal peg the card hangs from.
    c.paint(ox + 11, 1, P.METAL[1])
    c.paint(ox + 12, 1, P.METAL[1])


def gen_shop_sign(name="shop_sign.png"):
    c = Canvas(FW * 2, FH)
    draw_sign(c, 0, OPEN_CARD, OPEN_LIGHT)
    draw_sign(c, FW, CLOSED_CARD, CLOSED_LIGHT)
    c.outline()
    c.drop_shadow()
    c.save(asset(name))
    print("generated", name, "(%dx%d, 2 frames)" % (FW * 2, FH))


def main():
    gen_shop_sign()


if __name__ == "__main__":
    main()
