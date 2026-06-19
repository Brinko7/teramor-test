#!/usr/bin/env python3
"""Procedural pixel-art generator for Teramor's elemental abilities pillar.

Effect sprites are white/greyscale so AbilityData.tint multiplies them into any
element colour at runtime (so they get NO dark outline). Hotbar icons are full
colour and get a crisp outline.

  orb.png            16x16  tintable projectile bead (Fireball / Frost Shard)
  nova_ring.png      32x32  tintable expanding shock ring (Stone Nova)
  ability_fire.png   16x16  Fireball hotbar icon
  ability_frost.png  16x16  Frost Shard hotbar icon
  ability_stone.png  16x16  Stone Nova hotbar icon
  ability_heal.png   16x16  Healing Light hotbar icon
"""

import math

from gen_farm import Canvas


def disc(c, cx, cy, r, color):
    r2 = r * r
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            if dx * dx + dy * dy <= r2:
                c.put(x, y, color)


def ring(c, cx, cy, r_out, r_in, color):
    ro2 = r_out * r_out
    ri2 = r_in * r_in
    for y in range(int(cy - r_out) - 1, int(cy + r_out) + 2):
        for x in range(int(cx - r_out) - 1, int(cx + r_out) + 2):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            d2 = dx * dx + dy * dy
            if ri2 <= d2 <= ro2:
                c.put(x, y, color)


# --- tintable effect sprites (no outline) ------------------------------------
def gen_orb():
    c = Canvas(16, 16)
    cx, cy = 8.0, 8.0
    disc(c, cx, cy, 6.0, (255, 255, 255, 55))
    disc(c, cx, cy, 5.0, (255, 255, 255, 120))
    disc(c, cx, cy, 4.0, (246, 248, 255, 210))
    disc(c, cx, cy, 3.0, (255, 255, 255, 255))
    disc(c, 7.0, 7.0, 1.6, (255, 255, 255, 255))  # bright hotspot
    c.save("orb.png")


def gen_nova_ring():
    c = Canvas(32, 32)
    cx, cy = 16.0, 16.0
    ring(c, cx, cy, 15.5, 10.5, (255, 255, 255, 70))
    ring(c, cx, cy, 14.5, 11.5, (255, 255, 255, 170))
    ring(c, cx, cy, 14.0, 12.5, (255, 255, 255, 255))
    c.save("nova_ring.png")


# --- hotbar icons (full colour, outlined) ------------------------------------
FIRE_O = (240, 120, 40)
FIRE_OD = (198, 78, 24)
FIRE_Y = (250, 210, 80)
FIRE_W = (255, 250, 214)


def gen_icon_fire():
    c = Canvas(16, 16)
    c.rect(5, 12, 10, 13, FIRE_OD)         # rounded base
    c.rect(5, 9, 10, 12, FIRE_O)
    c.rect(6, 6, 9, 9, FIRE_O)
    c.rect(7, 3, 8, 6, FIRE_O)
    c.put(7, 2, FIRE_O)
    c.rect(6, 10, 9, 12, FIRE_Y)           # inner glow
    c.rect(7, 6, 8, 10, FIRE_Y)
    c.rect(7, 10, 8, 12, FIRE_W)           # white core
    c.outline()
    c.save("ability_fire.png")


FROST_B = (120, 200, 240)
FROST_BD = (66, 150, 210)
FROST_BL = (206, 240, 255)


def gen_icon_frost():
    c = Canvas(16, 16)
    c.rect(6, 3, 9, 4, FROST_B)            # crystal: wide top, tapered point
    c.rect(5, 5, 10, 8, FROST_B)
    c.rect(6, 9, 9, 10, FROST_B)
    c.rect(7, 11, 8, 12, FROST_B)
    c.put(7, 13, FROST_B)
    c.rect(6, 4, 6, 9, FROST_BL)           # left highlight
    c.rect(7, 3, 7, 4, FROST_BL)
    c.rect(9, 5, 9, 9, FROST_BD)           # right shadow
    c.outline()
    c.save("ability_frost.png")


ROCK = (150, 120, 86)
ROCK_D = (110, 84, 56)
ROCK_L = (184, 156, 116)


def gen_icon_stone():
    c = Canvas(16, 16)
    c.shade(5, 6, 10, 11, ROCK_L, ROCK, ROCK_D)   # central boulder
    c.put(5, 6, (0, 0, 0, 0))
    c.put(10, 6, (0, 0, 0, 0))
    c.put(5, 11, (0, 0, 0, 0))
    c.put(10, 11, (0, 0, 0, 0))
    c.rect(6, 8, 9, 8, ROCK_D)                     # crack
    for (x, y) in [(1, 4), (13, 4), (2, 12), (12, 12)]:  # scattered debris
        c.rect(x, y, x + 1, y + 1, ROCK)
    c.outline()
    c.save("ability_stone.png")


HEAL_G = (110, 210, 120)
HEAL_GD = (58, 158, 80)
HEAL_GL = (184, 250, 184)
HEAL_GOLD = (250, 222, 112)


def gen_icon_heal():
    c = Canvas(16, 16)
    c.rect(6, 3, 9, 12, HEAL_G)            # plus: vertical + horizontal
    c.rect(3, 6, 12, 9, HEAL_G)
    c.rect(6, 3, 7, 12, HEAL_GL)           # highlight
    c.rect(3, 6, 12, 7, HEAL_GL)
    c.rect(9, 6, 9, 9, HEAL_GD)            # shadow
    c.rect(6, 9, 9, 9, HEAL_GD)
    for (x, y) in [(2, 2), (13, 3), (3, 13), (13, 12)]:  # gold sparkles
        c.put(x, y, HEAL_GOLD)
    c.outline()
    c.save("ability_heal.png")


def main():
    gen_orb()
    gen_nova_ring()
    gen_icon_fire()
    gen_icon_frost()
    gen_icon_stone()
    gen_icon_heal()


if __name__ == "__main__":
    main()
