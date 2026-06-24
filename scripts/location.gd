extends Node2D
class_name LocationScene

## Generic root for a hand-built named location scene (a town, a capital, a
## landmark). Handles the boilerplate so the .tscn is just its ground + the
## buildings/props you drag around: on load it claims its map id (honouring a
## staged journey/fast-travel), sizes the tiled ground, frames the map with
## perimeter walls, and clamps the player camera to `map_size`.
##
## Author a new place by setting `location_id` + `map_size` on the root, pointing
## the `Ground` sprite at a texture (tint it via the sprite's modulate), and
## dropping building/prop instances under `Entities`. See tools/gen_locations.py
## for the starter scaffolds — but after that, just edit the scene in the editor.

@export var location_id: StringName = &""
@export var map_size: Vector2i = Vector2i(960, 720)
## Wall thickness for the auto-built perimeter frame.
const WALL := 16.0

func _ready() -> void:
	if location_id != &"":
		# Honours a staged journey/fast-travel destination, else tags itself.
		WorldMap.claim_arrival(location_id)
	MusicManager.enter_zone(_music_zone())
	_frame_ground()
	_build_walls()
	_build_roads()
	_dress_edges()
	_clamp_camera()

## Buildings (by instanced scene) a town's streets should connect.
const _BUILDINGS := ["cabin", "shop", "tavern", "chapel", "blacksmith",
		"townhouse", "well", "market_stall"]

## Derive a street network from wherever the buildings actually sit, so hand-edited
## and scaffolded layouts both get circulation with no per-scene authoring: a cobble
## plaza at the building centroid, a spine to the player spawn, and an L-road from
## the plaza out to each building. Wilderness locations (no buildings) get nothing.
func _build_roads() -> void:
	var ents := get_node_or_null("Entities")
	if ents == null:
		return
	var pts: Array[Vector2] = []
	for c in ents.get_children():
		var sp: String = (c as Node).scene_file_path
		if sp == "" or not (c is Node2D):
			continue
		for b in _BUILDINGS:
			if sp.ends_with("/%s.tscn" % b):
				pts.append((c as Node2D).position)
				break
	if pts.size() < 2:
		return
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= float(pts.size())
	var layer := Node2D.new()
	layer.name = "Roads"
	add_child(layer)
	move_child(layer, ents.get_index())   # below the y-sorted Entities, above Ground
	var roads := []
	var spawn_y := float(map_size.y) - 80.0
	for n in ents.get_children():
		if n is Marker2D and (n as Node).is_in_group("spawn"):
			spawn_y = (n as Marker2D).position.y
			break
	roads.append([Vector2(cen.x, cen.y), Vector2(cen.x, spawn_y)])   # spine to spawn
	for p in pts:                                                     # L-road to each building
		roads.append([Vector2(cen.x, cen.y), Vector2(p.x, cen.y)])
		roads.append([Vector2(p.x, cen.y), Vector2(p.x, p.y)])
	RoadPainter.paint(layer, [Rect2(cen.x - 130, cen.y - 90, 260, 180)], roads)

## Frame wooded places with a perimeter tree-line for depth (skip plains/desert).
func _dress_edges() -> void:
	var loc := WorldMap.get_location(location_id)
	if loc == null or not (loc.region == &"hollenmark" or loc.region == &"cursed_wilds"):
		return
	var ents := get_node_or_null("Entities")
	if ents == null:
		return
	var avoid: Array = []
	for c in ents.get_children():
		if c is Node2D:
			avoid.append((c as Node2D).position)
	EdgeDressing.plant_treeline(ents, map_size, int(hash(location_id)), avoid)


## Pick a music zone from this place's authored kind/region (camp/town/wild/cursed)
## so each named location carries the mood of where it sits in the world.
func _music_zone() -> StringName:
	var loc := WorldMap.get_location(location_id)
	if loc == null:
		return &"town"
	if loc.region == &"cursed_wilds":
		return &"cursed"
	match loc.kind:
		&"camp":
			return &"camp"
		&"wild", &"frontier":
			return &"wild"
		_:
			return &"town"

func _frame_ground() -> void:
	var g := get_node_or_null("Ground") as Sprite2D
	if g == null:
		return
	g.centered = false
	g.region_enabled = true
	g.region_rect = Rect2(0, 0, map_size.x, map_size.y)

## A perimeter wall frame from map_size, so the player can't walk off the ground.
func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Bounds"
	add_child(body)
	var w := float(map_size.x)
	var h := float(map_size.y)
	_wall(body, Vector2(w * 0.5, WALL * 0.5), Vector2(w, WALL))
	_wall(body, Vector2(w * 0.5, h - WALL * 0.5), Vector2(w, WALL))
	_wall(body, Vector2(WALL * 0.5, h * 0.5), Vector2(WALL, h))
	_wall(body, Vector2(w - WALL * 0.5, h * 0.5), Vector2(WALL, h))

func _wall(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = pos
	body.add_child(cs)

func _clamp_camera() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam := (player as Node).get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = map_size.x
		cam.limit_bottom = map_size.y
		CameraFit.fit(cam, map_size)
