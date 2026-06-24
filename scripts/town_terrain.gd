extends Node2D
## Cleeve's Landing. Paints the town's circulation — a central market plaza with a
## south-north spine avenue, east/west trade streets to the shop & tavern rows, and
## a southern residential street — via RoadPainter onto the `Roads` layer (cobble
## plaza + dirt streets, beneath the y-sorted buildings). Only the streets are
## scripted; the hand-placed buildings stay editable. Also clamps the camera.
##
## Geometry is in the map's own pixel space (1920x1440) and matches the building
## positions under Entities — keep them in sync when you move a building.

@export var map_size: Vector2i = Vector2i(1920, 1440)

func _ready() -> void:
	# Tag this scene as the player's current world location for the map/fast travel.
	# claim_arrival honours a staged journey/fast-travel destination, else this id —
	# so the same town scene can stand in for more than one place on the map.
	WorldMap.claim_arrival(&"cleaves_landing")
	MusicManager.enter_zone(&"town")
	_paint_roads()
	_clamp_camera()

func _paint_roads() -> void:
	var layer := get_node_or_null("Roads") as Node2D
	if layer == null:
		return
	# Cobble market plaza around the well + stalls (centre of town).
	var plazas := [Rect2(700, 640, 520, 260)]
	# Street centre-lines (axis-aligned), matching the buildings under Entities.
	var roads := [
		[Vector2(960, 900), Vector2(960, 1410)],    # spine avenue: plaza -> south gate
		[Vector2(960, 300), Vector2(960, 640)],     # spine avenue: plaza -> north edge
		[Vector2(700, 760), Vector2(300, 760)],     # west trade street -> shop/chapel row
		[Vector2(300, 470), Vector2(300, 760)],     # west stub up to chapel/townhouse
		[Vector2(1220, 760), Vector2(1620, 760)],   # east trade street -> tavern/smith row
		[Vector2(1620, 470), Vector2(1620, 760)],   # east stub up to blacksmith/townhouse
		[Vector2(300, 1120), Vector2(1620, 1120)],  # south residential street
	]
	RoadPainter.paint(layer, plazas, roads)

func _clamp_camera() -> void:
	var cam := get_node_or_null("Entities/Player/Camera2D") as Camera2D
	if cam == null:
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			cam = p.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = map_size.x
		cam.limit_bottom = map_size.y
		CameraFit.fit(cam, map_size)
