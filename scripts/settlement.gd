extends Node2D

## Clamps the follow-camera to the map bounds so the world edge / void
## never shows. Map is the grass ground area (in pixels).
@export var map_size: Vector2i = Vector2i(640, 480)

func _ready() -> void:
	# Tag this scene as the player's current world location for the map/fast travel.
	WorldMap.discover(&"settlement_camp")
	WorldMap.set_current(&"settlement_camp")
	var cam := get_node_or_null("Entities/Player/Camera2D") as Camera2D
	if cam == null:
		var p := get_tree().get_first_node_in_group("player")
		if p:
			cam = p.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = map_size.x
		cam.limit_bottom = map_size.y
