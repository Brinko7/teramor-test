#!/usr/bin/env python3
"""Scaffold a unique, hand-editable .tscn for each named map location.

Each location gets its own scene under scenes/world/locations/ built on the shared
LocationScene root (scripts/location.gd) — themed ground + a starter layout of
existing building/prop scenes you then drag around in the editor. This is a
*scaffold*: re-running overwrites, so once you start hand-editing a scene, leave it
alone here. Run: python3 tools/gen_locations.py

The point is to turn the rumored, data-only map nodes into real scenes you can edit.
"""

import os
import random
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT_DIR = "scenes/world/locations"

P = "res://scenes/entities/props/"
PATHS = {
	"townhouse": P + "townhouse.tscn", "cabin": P + "cabin.tscn",
	"shop": P + "shop.tscn", "tavern": P + "tavern.tscn",
	"blacksmith": P + "blacksmith.tscn", "chapel": P + "chapel.tscn",
	"well": P + "well.tscn", "stall": P + "market_stall.tscn",
	"lamp": P + "lamp_post.tscn", "sign": P + "signpost.tscn",
	"fence": P + "fence.tscn", "barrel": P + "barrel.tscn",
	"crate": P + "crate.tscn", "tree": P + "tree.tscn",
	"bush": P + "bush.tscn", "rock": P + "rock.tscn",
	"campfire": P + "campfire.tscn", "tent": P + "tent.tscn",
	"flower": P + "flower.tscn",
}
SCRIPT_LOC = "res://scripts/location.gd"
SCRIPT_DAYNIGHT = "res://scripts/day_night.gd"
PLAYER = "res://scenes/entities/player.tscn"
HUD = "res://scenes/ui/world_hud.tscn"


def grid(n, w, h, top=120, dx=200, dy=180, margin=90):
	"""Centered rows of `n` big buildings in the interior."""
	cols = max(1, int((w - 2 * margin) // dx))
	out = []
	for i in range(n):
		r, c = divmod(i, cols)
		row_count = min(cols, n - r * cols)
		x0 = w / 2 - (row_count - 1) * dx / 2
		out.append((round(x0 + c * dx), top + r * dy))
	return out


def scatter(rng, n, w, h, margin=56, bottom=150):
	return [(rng.randint(margin, w - margin), rng.randint(margin, h - bottom)) for _ in range(n)]


def border(w, h, spacing=104):
	pts = []
	x = 64
	while x < w - 48:
		pts.append((x, 46)); x += spacing
	y = 130
	while y < h - 130:
		pts.append((40, y)); pts.append((w - 40, y)); y += spacing
	return pts


class Scene:
	def __init__(self, root_name, loc_id, w, h, ground, tint):
		self.root = root_name
		self.loc = loc_id
		self.w, self.h = w, h
		self.ground = ground
		self.tint = tint
		self.ext = {}      # path -> (idname, type)
		self.nodes = []    # text blocks
		self._ext("Script", SCRIPT_LOC)
		self._ext("Texture2D", ground)
		self._ext("PackedScene", PLAYER)
		self._ext("PackedScene", HUD)
		self._ext("Script", SCRIPT_DAYNIGHT)

	def _ext(self, kind, path):
		if path not in self.ext:
			self.ext[path] = ("e%d" % (len(self.ext) + 1), kind)
		return self.ext[path][0]

	def building(self, key, x, y, text=None):
		eid = self._ext("PackedScene", PATHS[key])
		name = "%s%d" % (key.capitalize(), sum(1 for n in self.nodes if n[0] == key) + 1)
		extra = '\ntext = "%s"' % text if text else ""
		self.nodes.append((key, '[node name="%s" parent="Entities" instance=ExtResource("%s")]\nposition = Vector2(%d, %d)%s\n' % (name, eid, x, y, extra)))

	def render(self):
		L = ['[gd_scene load_steps=%d format=3]\n' % (len(self.ext) + 1)]
		for path, (eid, kind) in self.ext.items():
			L.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, eid))
		L.append("")
		c = self.tint
		L.append('[node name="%s" type="Node2D"]' % self.root)
		L.append('script = ExtResource("%s")' % self.ext[SCRIPT_LOC][0])
		L.append('location_id = &"%s"' % self.loc)
		L.append('map_size = Vector2i(%d, %d)\n' % (self.w, self.h))
		L.append('[node name="Ground" type="Sprite2D" parent="."]')
		L.append('texture_repeat = 2')
		L.append('centered = false')
		L.append('texture = ExtResource("%s")' % self.ext[self.ground][0])
		L.append('modulate = Color(%s, %s, %s, 1)\n' % (c[0], c[1], c[2]))
		L.append('[node name="Entities" type="Node2D" parent="."]')
		L.append('y_sort_enabled = true\n')
		spawn = (self.w // 2, self.h - 72)
		L.append('[node name="Player" parent="Entities" instance=ExtResource("%s")]' % self.ext[PLAYER][0])
		L.append('position = Vector2(%d, %d)\n' % spawn)
		for _key, block in self.nodes:
			L.append(block)
		L.append('[node name="Spawns" type="Node2D" parent="."]\n')
		for sp in ("from_road", "spawn", "from_journey"):
			L.append('[node name="%s" type="Marker2D" parent="Spawns" groups=["spawn"]]' % sp)
			L.append('position = Vector2(%d, %d)\n' % spawn)
		L.append('[node name="DayNight" type="CanvasModulate" parent="."]')
		L.append('script = ExtResource("%s")\n' % self.ext[SCRIPT_DAYNIGHT][0])
		L.append('[node name="WorldHUD" parent="." instance=ExtResource("%s")]\n' % self.ext[HUD][0])
		return "\n".join(L)


GRASS = "res://assets/placeholder/grass.png"
DRY = "res://assets/placeholder/grass_dry.png"
DIRT = "res://assets/placeholder/dirt.png"

# id -> (root, w, h, ground, tint, buildings[], decor{key:count}, frame, sign)
SPECS = {
	"hollen": ("Hollen", 1120, 800, GRASS, (0.92, 1.0, 0.92),
		["chapel", "tavern", "blacksmith", "shop", "townhouse", "townhouse", "townhouse", "townhouse", "well", "stall", "stall"],
		{"tree": 6, "lamp": 6, "barrel": 4, "crate": 3}, "tree", "Hollen\nSeat of the Hollenmark"),
	"mirefen": ("Mirefen", 820, 620, DIRT, (0.82, 0.84, 0.72),
		["cabin", "cabin", "cabin", "shop", "well"],
		{"tree": 10, "bush": 8, "fence": 5, "barrel": 3}, "tree", "Mirefen"),
	"plint": ("Plint", 1120, 800, DRY, (1.0, 0.98, 0.8),
		["chapel", "tavern", "shop", "blacksmith", "townhouse", "townhouse", "townhouse", "townhouse", "well", "stall", "stall", "stall"],
		{"tree": 5, "lamp": 8, "flower": 6, "crate": 3}, "tree", "Plint\nCourt of the Wizard King"),
	"kingsford": ("Kingsford", 860, 640, DRY, (1.0, 0.97, 0.82),
		["tavern", "shop", "townhouse", "townhouse", "well", "stall"],
		{"tree": 6, "lamp": 4, "fence": 4, "barrel": 3}, "tree", "Kingsford\non the King's Path"),
	"terakin": ("Terakin", 1120, 800, DIRT, (0.96, 0.85, 0.6),
		["chapel", "blacksmith", "townhouse", "townhouse", "townhouse", "townhouse", "well", "tent", "tent"],
		{"rock": 8, "crate": 6, "barrel": 4, "lamp": 4}, "rock", "Terakin\nthe Iron Crown"),
	"the_holdfast": ("TheHoldfast", 780, 600, DIRT, (0.9, 0.8, 0.58),
		["cabin", "cabin", "blacksmith", "tent", "tent"],
		{"rock": 8, "crate": 6, "fence": 8, "barrel": 3}, "rock", "The Holdfast\ncages in the sand"),
	"the_thornwall": ("TheThornwall", 980, 680, GRASS, (0.5, 0.46, 0.58),
		[],
		{"tree": 22, "bush": 16, "rock": 10}, "tree", "The Thornwall\nturn back if you value your life"),
	"elven_glade": ("ElvenGlade", 920, 720, GRASS, (0.82, 1.0, 0.86),
		["cabin", "cabin", "cabin", "well"],
		{"tree": 16, "flower": 12, "bush": 8}, "tree", "The Elven Glade"),
	# NOTE: the_great_tree is a *bespoke* hand-built finale scene
	# (scenes/world/the_great_tree.tscn, scripts/great_tree.gd) — not scaffolded
	# here, so this generator never overwrites it.
}


def build():
	os.makedirs(os.path.join(ROOT, OUT_DIR), exist_ok=True)
	for loc, (root, w, h, ground, tint, buildings, decor, frame, sign_text) in SPECS.items():
		# Stable per-location seed (Python's hash() is salted per-process), so
		# regenerating is idempotent — no churn unless a spec actually changes.
		rng = random.Random(zlib.crc32(loc.encode()))
		s = Scene(root, loc, w, h, ground, tint)
		# Big buildings on a centered grid.
		for key, (x, y) in zip(buildings, grid(len(buildings), w, h)):
			s.building(key, x, y)
		# A central feature for the landmark scenes (the well/tree/shrine anchor).
		if not buildings:
			s.building(frame, w // 2, h // 2 - 20)
		# Scattered decor.
		for key, count in decor.items():
			for (x, y) in scatter(rng, count, w, h):
				s.building(key, x, y)
		# A framing line of the border prop along top + sides.
		for (x, y) in border(w, h):
			s.building(frame, x, y)
		# A name sign by the entrance.
		s.building("sign", w // 2 + 44, h - 120, text=sign_text)
		path = os.path.join(ROOT, OUT_DIR, "%s.tscn" % loc)
		with open(path, "w") as f:
			f.write(s.render())
		print("generated %s/%s.tscn" % (OUT_DIR, loc))


if __name__ == "__main__":
	build()
	print("gen_locations: done.")
