extends Enemy
class_name EnemyArcher

## Ranged kiter. Squishy and weak in melee, but tries to keep the player at a
## preferred distance: it backs off when you close in, holds position at range,
## and looses projectiles on a cooldown. Steady XP, modest loot.

## Distance (px) the archer tries to maintain from the player.
@export var preferred_range: float = 110.0
## Tolerance band (px) around preferred_range where the archer holds still.
@export var range_band: float = 18.0
## Seconds between shots.
@export var fire_cooldown: float = 1.4
## Damage dealt by each projectile.
@export var projectile_damage: int = 2
## Projectile travel speed (px/s).
@export var projectile_speed: float = 170.0

const PROJECTILE_SCENE := preload("res://scenes/entities/enemy_projectile.tscn")

var _fire_timer: float = 0.0

func _decide_input(delta: float) -> Vector2:
	_fire_timer = maxf(0.0, _fire_timer - delta)

	if _target == null or not is_instance_valid(_target):
		return _wander(delta)

	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()
	if dist > detect_range:
		return _wander(delta)

	if dist <= detect_range:
		_try_fire(to_target)

	# Maintain preferred distance: retreat if too close, advance if too far.
	if dist < preferred_range - range_band:
		return -to_target.normalized()
	if dist > preferred_range + range_band:
		return to_target.normalized()
	return Vector2.ZERO

func _try_fire(to_target: Vector2) -> void:
	if _fire_timer > 0.0:
		return
	_fire_timer = fire_cooldown
	var parent := get_parent()
	if parent == null:
		return
	var proj := PROJECTILE_SCENE.instantiate() as EnemyProjectile
	if proj == null:
		return
	proj.global_position = global_position + Vector2(0.0, -8.0)
	proj.setup(to_target.normalized(), projectile_damage, projectile_speed, detect_range + 80.0, faction)
	parent.call_deferred("add_child", proj)
