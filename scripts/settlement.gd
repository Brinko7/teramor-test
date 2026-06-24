extends Node2D

## Clamps the follow-camera to the map bounds so the world edge / void
## never shows. Map is the grass ground area (in pixels).
@export var map_size: Vector2i = Vector2i(640, 480)

func _ready() -> void:
	# Tag this scene as the player's current world location for the map/fast travel.
	# claim_arrival honours a staged journey/fast-travel destination, else this id.
	WorldMap.claim_arrival(&"settlement_camp")
	MusicManager.enter_zone(&"camp")
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
	_grow_camp()

const _TENT := preload("res://scenes/entities/props/tent.tscn")
const _WELL := preload("res://scenes/entities/props/well.tscn")
const _RACK := preload("res://scenes/entities/props/market_stall.tscn")
const _SMOKE := preload("res://scenes/entities/props/chimney_smoke.tscn")
## Tent spots a recruited member pitches camp on, in fill order.
const _RECRUIT_SPOTS := [Vector2(420, 150), Vector2(540, 250), Vector2(300, 362), Vector2(540, 400)]

## The camp grows as you play: each bought upgrade raises a structure, and each
## recruited member pitches a tent. A fresh camp shows none of this; a fully
## built-up one bustles — visible progression for the recruit/upgrade loop.
func _grow_camp() -> void:
	var ents := get_node_or_null("Entities")
	if ents == null:
		return
	var show_all := OS.has_environment("CAMP_SHOW_ALL")   # verification helper
	var upgrades := [
		[&"bunkhouse", _TENT, Vector2(500, 175), false],
		[&"longhouse", _TENT, Vector2(255, 250), false],
		[&"irrigation", _WELL, Vector2(72, 266), false],
		[&"smokehouse", _RACK, Vector2(470, 362), true],
	]
	for u in upgrades:
		if not (show_all or CampManager.is_owned(u[0])):
			continue
		var s := (u[1] as PackedScene).instantiate()
		if s is Node2D:
			(s as Node2D).position = u[2]
		ents.add_child(s)
		if u[3]:
			var smoke := _SMOKE.instantiate()
			if smoke is Node2D:
				(smoke as Node2D).position = Vector2(0, -48)
			s.add_child(smoke)
	var active := 0
	for m in CampManager.get_roster():
		if bool(m.get("active", false)):
			active += 1
	var tents: int = _RECRUIT_SPOTS.size() if show_all else mini(active, _RECRUIT_SPOTS.size())
	for i in range(tents):
		var t := _TENT.instantiate()
		if t is Node2D:
			(t as Node2D).position = _RECRUIT_SPOTS[i]
		ents.add_child(t)
