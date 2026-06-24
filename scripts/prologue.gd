extends Node2D

## The opening scene — the wilds' edge, where your father Elkar gives his last
## lesson before riding for his Cleeve's Landing contract, and then is gone. A new
## game starts *here*, not at the camp: the Children of Tera are a secret you don't
## yet know exists. The lesson teaches the verbs diegetically (Elkar's words, not
## pop-ups) and the two wolves at the treeline are the ch1 "defeat 2 foes" beat.
##
## This is a bespoke first scene (the player is authored in it), so it just clamps
## the follow-camera to the clearing and sets the warm, bittersweet mood. It does
## not claim a world-map location — the prologue isn't a place you return to.

@export var map_size: Vector2i = Vector2i(480, 320)

func _ready() -> void:
	MusicManager.enter_zone(&"camp")  # warm home theme for the last morning together
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
		CameraFit.fit(cam, map_size)
