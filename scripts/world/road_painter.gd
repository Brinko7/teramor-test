extends RefCounted
class_name RoadPainter

## Paints a town's circulation — plazas and streets — as flat tiled decals onto a
## layer that sits above the ground but below the y-sorted Entities, so the player
## and buildings walk *on* the roads. Cobble `plaza32` for open squares, `path32`
## for streets. Roads are axis-aligned rectangles (a grid of H/V segments), which
## covers town/road layouts cleanly and tiles seamlessly at junctions.
##
## Reusable across the hand-built towns (town_terrain.gd), the LocationScene
## scaffolds, and the procedural generator — feed it a layer node + the geometry.

const PATH_TEX := preload("res://assets/remaster/world/path32.png")
const PLAZA_TEX := preload("res://assets/remaster/world/plaza32.png")

## plazas: Array[Rect2] (world space). roads: Array of [Vector2 a, Vector2 b] centre-
## lines, each axis-aligned (same x → vertical, same y → horizontal). road_w in px.
static func paint(layer: Node2D, plazas: Array, roads: Array, road_w: float = 72.0) -> void:
	if layer == null:
		return
	for seg in roads:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var r: Rect2
		if absf(a.x - b.x) < 0.5:                       # vertical street
			r = Rect2(a.x - road_w * 0.5, minf(a.y, b.y), road_w, absf(b.y - a.y))
		else:                                            # horizontal street
			r = Rect2(minf(a.x, b.x), a.y - road_w * 0.5, absf(b.x - a.x), road_w)
		_tile(layer, PATH_TEX, r)
	for rect in plazas:                                  # plazas drawn last (over road seams)
		_tile(layer, PLAZA_TEX, rect)

static func _tile(layer: Node2D, tex: Texture2D, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, rect.size.x, rect.size.y)
	s.position = rect.position
	layer.add_child(s)
