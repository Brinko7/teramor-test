class_name Townsfolk
extends Node2D

## A cosmetic, non-interactive pedestrian — the bodies that make a town read as
## *bustling* rather than a handful of quest-givers standing on markers. Townsfolk
## stroll between shared waypoints, milling a beat at each, then pick a new one, so
## the streets always have movement.
##
## They reuse the same directional walk-sheet animation the talking NPCs use (4
## walk columns x 8 facing rows, see dir_util.gd), so the crowd moves the same way
## — but they carry no dialogue / quest / relationship / gift state and are NOT in
## the "interactable" group, so the player walks right past them. Spawned in bulk by
## townsfolk_crowd.gd; tune the look/speed there.

const DIR_UTIL := preload("res://scripts/dir_util.gd")
const _WALK_FRAMES := [0, 1, 0, 2]
const _ANIM_FPS := 6.0
const _ARRIVE_DIST := 2.0

@export var sprite_texture: Texture2D = null
@export var sprite_tint: Color = Color.WHITE
## Group of Marker2D destinations to stroll between. Defaults to the waypoint
## markers a town already places for its scheduled NPCs.
@export var stroll_group: StringName = &"npc_waypoint"
@export var walk_speed: float = 30.0
@export var pause_min: float = 1.0
@export var pause_max: float = 3.5

var _sprite: Sprite2D = null
var _target: Vector2 = Vector2.ZERO
var _pause: float = 0.0
var _rng := RandomNumberGenerator.new()
var _facing_row: int = 0
var _anim_time: float = 0.0
var _points: Array[Node2D] = []

func _ready() -> void:
	_rng.randomize()
	_sprite = $Sprite2D as Sprite2D
	if _sprite != null:
		if sprite_texture != null:
			_sprite.texture = sprite_texture
		_sprite.modulate = sprite_tint
	for node in get_tree().get_nodes_in_group(stroll_group):
		if node is Node2D:
			_points.append(node as Node2D)
	_target = global_position
	_pause = _rng.randf_range(pause_min, pause_max)

## Drop the pedestrian at a spot and reset its stroll, so a spawner can position it
## after add_child without a one-frame glide back toward the origin.
func place(pos: Vector2) -> void:
	global_position = pos
	_target = pos
	_pause = _rng.randf_range(pause_min, pause_max)

func _process(delta: float) -> void:
	var to_target: Vector2 = _target - global_position
	var dist: float = to_target.length()
	if dist <= _ARRIVE_DIST:
		_animate(delta, false)
		_pause -= delta
		if _pause <= 0.0:
			_pick_destination()
		return
	var dir: Vector2 = to_target / dist
	var step: float = walk_speed * delta
	if step >= dist:
		global_position = _target
	else:
		global_position += dir * step
	if _sprite != null:
		_facing_row = DIR_UTIL.row_for(dir, _sprite.vframes)
	_animate(delta, true)

func _pick_destination() -> void:
	_pause = _rng.randf_range(pause_min, pause_max)
	if _points.is_empty():
		return
	_target = _points[_rng.randi_range(0, _points.size() - 1)].global_position

func _animate(delta: float, moving: bool) -> void:
	if _sprite == null:
		return
	if not moving:
		_anim_time = 0.0
		_sprite.frame = _facing_row * _sprite.hframes
		return
	_anim_time += delta * _ANIM_FPS
	var col: int = _WALK_FRAMES[int(_anim_time) % _WALK_FRAMES.size()]
	_sprite.frame = _facing_row * _sprite.hframes + col
