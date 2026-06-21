class_name Critter
extends Node2D

## A small ambient animal — a chicken pecking in a yard, a dog ambling a street, a
## bird hopping in the plaza. Cosmetic: a Node2D with **no collision** (the player
## walks right through it), driven by a tiny wander/peck loop. It animates off the
## 4x4 directional animal sheet (rows down/up/left/right, the wildlife rig) via
## dir_util, so no physics body is involved.
##
## - `idle_peck` lets it nibble in place while paused instead of freezing.
## - `skittish` critters flee the player within `flush_radius`; a `flyer` also rises
##   and fades as it bolts (a bird taking wing), then reappears near home after a
##   beat. Drop several skittish flyers in a plaza and they scatter as a flock.

const DIR_UTIL := preload("res://scripts/dir_util.gd")
const _WALK_FRAMES := [0, 1, 0, 2]
const _PECK_FRAMES := [0, 2, 0]

@export var move_speed: float = 16.0
@export var wander_radius: float = 26.0
@export var pause_min: float = 0.7
@export var pause_max: float = 2.8
@export var anim_fps: float = 5.0
## Nibble in place (cycle the peck frames) while paused, rather than standing still.
@export var idle_peck: bool = false
@export var idle_fps: float = 2.5
## Flee the player when they come within flush_radius.
@export var skittish: bool = false
@export var flush_radius: float = 30.0
@export var flee_speed: float = 80.0
## On flush, rise and fade out (a bird taking wing) then respawn near home.
@export var flyer: bool = false
@export var respawn_delay: float = 6.0

var _sprite: Sprite2D = null
var _home: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _pause: float = 0.0
var _rng := RandomNumberGenerator.new()
var _facing_row: int = 0
var _anim_time: float = 0.0
var _respawn: float = 0.0
var _player: Node2D = null
var _flushing: bool = false
var _flee_dir: Vector2 = Vector2.UP

func _ready() -> void:
	_rng.randomize()
	_sprite = $Sprite2D as Sprite2D
	_home = global_position
	_target = global_position
	_pause = _rng.randf_range(pause_min, pause_max)

func _process(delta: float) -> void:
	if _respawn > 0.0:
		_respawn -= delta
		if _respawn <= 0.0:
			_reappear()
		return
	# A flyer that's already been spooked commits to taking wing, even after it
	# clears flush_radius — otherwise it would be left half-faded mid-air.
	if _flushing:
		_take_wing(delta)
		return
	if skittish:
		var p := _player_node()
		if p != null and global_position.distance_to(p.global_position) < flush_radius:
			if flyer:
				_flee_dir = (global_position - p.global_position).normalized()
				_flee_dir = (_flee_dir + Vector2(0.0, -1.4)).normalized()   # up and away
				_flushing = true
				_take_wing(delta)
			else:
				_scurry(delta, p)
			return
	_roam(delta)

func _roam(delta: float) -> void:
	var to_target: Vector2 = _target - global_position
	var dist: float = to_target.length()
	if dist <= 2.0:
		_animate_idle(delta)
		_pause -= delta
		if _pause <= 0.0:
			var off := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
			_target = _home + off * wander_radius
			_pause = _rng.randf_range(pause_min, pause_max)
		return
	var dir: Vector2 = to_target / dist
	global_position += dir * minf(move_speed * delta, dist)
	if _sprite != null:
		_facing_row = DIR_UTIL.row_for(dir, _sprite.vframes)
	_animate_walk(delta)

## A grounded skittish critter (a chicken) scurries directly away, no fade.
func _scurry(delta: float, p: Node2D) -> void:
	var away: Vector2 = (global_position - p.global_position).normalized()
	global_position += away * flee_speed * delta
	if _sprite != null:
		_facing_row = DIR_UTIL.row_for(away, _sprite.vframes)
	_animate_walk(delta)

## A flyer takes wing: fly along the spooked direction while fading, then vanish
## and schedule a respawn near home.
func _take_wing(delta: float) -> void:
	global_position += _flee_dir * flee_speed * delta
	if _sprite != null:
		_facing_row = DIR_UTIL.row_for(_flee_dir, _sprite.vframes)
	_animate_walk(delta)
	var a: float = modulate.a - delta * 1.1
	modulate = Color(modulate.r, modulate.g, modulate.b, maxf(0.0, a))
	if modulate.a <= 0.05:
		_vanish()

func _vanish() -> void:
	visible = false
	_flushing = false
	_respawn = respawn_delay

func _reappear() -> void:
	var off := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
	global_position = _home + off * wander_radius
	modulate = Color(modulate.r, modulate.g, modulate.b, 1.0)
	visible = true
	_flushing = false
	_target = global_position
	_pause = _rng.randf_range(pause_min, pause_max)

func _player_node() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player

func _animate_walk(delta: float) -> void:
	if _sprite == null:
		return
	_anim_time += delta * anim_fps
	var col: int = _WALK_FRAMES[int(_anim_time) % _WALK_FRAMES.size()]
	_sprite.frame = _facing_row * _sprite.hframes + col

func _animate_idle(delta: float) -> void:
	if _sprite == null:
		return
	if not idle_peck:
		_anim_time = 0.0
		_sprite.frame = _facing_row * _sprite.hframes
		return
	_anim_time += delta * idle_fps
	var col: int = _PECK_FRAMES[int(_anim_time) % _PECK_FRAMES.size()]
	_sprite.frame = _facing_row * _sprite.hframes + col
