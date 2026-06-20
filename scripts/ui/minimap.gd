extends Control

## Compact corner minimap for vast wild areas. The procedural-area generator calls
## configure(world_size, blips) after it lays out the space; we draw a scaled box
## with the player's live position plus feature/exit blips so roaming has a sense of
## place. Purely cosmetic — reads positions, owns no state.

const MARGIN := 8.0
const MAX_W := 96.0

var _world: Vector2 = Vector2(1280, 960)
var _blips: Array = []  # [{pos: Vector2, color: Color}]

func _ready() -> void:
	add_to_group("minimap")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_relayout()
	set_process(true)

func configure(world_size: Vector2, blips: Array) -> void:
	_world = world_size
	_blips = blips
	_relayout()
	queue_redraw()

func _relayout() -> void:
	var aspect: float = _world.x / maxf(1.0, _world.y)
	size = Vector2(MAX_W, MAX_W / maxf(0.1, aspect))
	var view: Vector2 = get_viewport_rect().size
	position = Vector2(view.x - size.x - MARGIN, MARGIN)

func _process(_delta: float) -> void:
	queue_redraw()

func _to_map(world_pos: Vector2) -> Vector2:
	return Vector2(
		clampf(world_pos.x / maxf(1.0, _world.x), 0.0, 1.0) * size.x,
		clampf(world_pos.y / maxf(1.0, _world.y), 0.0, 1.0) * size.y
	)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.07, 0.06, 0.05, 0.7), true)
	draw_rect(r, Color(0.78, 0.69, 0.52, 0.9), false, 1.0)
	for b: Dictionary in _blips:
		draw_circle(_to_map(b["pos"]), 1.8, b["color"])
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var p := _to_map((player as Node2D).global_position)
		draw_circle(p, 2.6, Color(0.1, 0.08, 0.06, 0.9))
		draw_circle(p, 1.8, Color(1.0, 0.96, 0.86))
