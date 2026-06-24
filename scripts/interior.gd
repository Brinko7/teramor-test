extends Node2D

## A furnished building interior (the player's cabin). Frames the small room by
## zooming the local player camera in and clamping it to the room bounds so the
## void never shows. The warm, hearth-lit mood comes from this scene's
## CanvasModulate + PointLight2Ds rather than the day/night cycle — interiors
## stay lit when it's dark outside.

@export var room_size: Vector2i = Vector2i(320, 224)
## NOTE: interiors still hold OLD-SCALE placeholder room art (320x224, 16px era).
## At the hi-fi 1280x720 base this zoom keeps the small room filling the screen so no
## void shows around it; the trade is the new 84x120 hero reads large in here. Proper
## fix is migrating the interior art to the 32px / remaster scale (a follow-up), after
## which this drops back toward ~1.5. Keep it high enough that room_size*zoom >= viewport.
@export var camera_zoom: float = 4.0

func _ready() -> void:
	MusicManager.enter_zone(&"interior")
	var cam := get_node_or_null("Entities/Player/Camera2D") as Camera2D
	if cam == null:
		var p := get_tree().get_first_node_in_group("player")
		if p:
			cam = p.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.zoom = Vector2(camera_zoom, camera_zoom)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = room_size.x
	cam.limit_bottom = room_size.y
	cam.reset_smoothing()
