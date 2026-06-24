extends Node2D

## A building interior, framed procedurally at remaster scale from `room_size`:
## a tiled wood floor, a wattle-and-daub wall band (taller, visible north wall),
## a plank door centred on the south wall, matching wall colliders, and the player
## camera clamped + fitted to the room. A scene just sets `room_size` and drops its
## furniture under `Entities` (+ lights, a spawn Marker and an ExitDoor zone). The
## warm mood comes from the scene's CanvasModulate + PointLight2Ds — interiors
## ignore the day/night cycle and stay lit when it's dark outside.

@export var room_size: Vector2i = Vector2i(608, 432)

const FLOOR_TEX := preload("res://assets/remaster/world/wood_floor32.png")
const WALL_TEX := preload("res://assets/remaster/world/wall_daub32.png")
const DOOR_TEX := preload("res://assets/remaster/world/door_wood.png")
const NORTH := 56.0   # tall, visible north (top) wall
const SIDE := 22.0    # side + south wall band thickness

func _ready() -> void:
	MusicManager.enter_zone(&"interior")
	_build_room()
	_clamp_camera()

func _build_room() -> void:
	var w := float(room_size.x)
	var h := float(room_size.y)
	# Floor — reuse a "Floor" node the scene kept (so its furniture children ride
	# along), else make one. Tiled wood, behind everything.
	var floor := get_node_or_null("Floor") as Sprite2D
	if floor == null:
		floor = Sprite2D.new()
		floor.name = "Floor"
		add_child(floor)
		move_child(floor, 0)
	floor.texture = FLOOR_TEX
	floor.centered = false
	floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor.region_enabled = true
	floor.region_rect = Rect2(0, 0, w, h)
	floor.position = Vector2.ZERO
	floor.z_index = -10
	# Wall bands (region-repeated daub), then the south door.
	_wall(Vector2(0, 0), Vector2(w, NORTH))
	_wall(Vector2(0, h - SIDE), Vector2(w, SIDE))
	_wall(Vector2(0, 0), Vector2(SIDE, h))
	_wall(Vector2(w - SIDE, 0), Vector2(SIDE, h))
	var door := Sprite2D.new()
	door.name = "Door"
	door.texture = DOOR_TEX
	door.centered = false
	door.offset = Vector2(-28, -70)
	door.position = Vector2(w * 0.5, h)
	door.z_index = -8
	add_child(door)
	# Solid wall colliders just inside the bands.
	var body := StaticBody2D.new()
	body.name = "Bounds"
	add_child(body)
	_collider(body, Vector2(w * 0.5, NORTH * 0.5), Vector2(w, NORTH))
	_collider(body, Vector2(w * 0.5, h - SIDE * 0.5), Vector2(w, SIDE))
	_collider(body, Vector2(SIDE * 0.5, h * 0.5), Vector2(SIDE, h))
	_collider(body, Vector2(w - SIDE * 0.5, h * 0.5), Vector2(SIDE, h))

func _wall(pos: Vector2, size: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = WALL_TEX
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, size.x, size.y)
	s.position = pos
	s.z_index = -9
	add_child(s)

func _collider(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = pos
	body.add_child(cs)

func _clamp_camera() -> void:
	var cam := get_node_or_null("Entities/Player/Camera2D") as Camera2D
	if cam == null:
		var p := get_tree().get_first_node_in_group("player")
		if p:
			cam = p.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = room_size.x
	cam.limit_bottom = room_size.y
	CameraFit.fit(cam, room_size)
	cam.reset_smoothing()
