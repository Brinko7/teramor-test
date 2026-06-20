extends Node2D

## The Great Tree of Tera — the Cursed-Wilds finale landmark. Tags itself as the
## current world location on arrival (so the map/fast-travel stay correct) and
## clamps the follow-camera to the clearing so the void never shows.

@export var map_size: Vector2i = Vector2i(640, 480)

func _ready() -> void:
	WorldMap.claim_arrival(&"the_great_tree")
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
