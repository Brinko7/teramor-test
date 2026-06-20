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
	_frame_ground()
	_build_walls()
	_clamp_camera()

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
