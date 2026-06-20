extends Node2D
class_name DustPuff

## A small kick of dust at an actor's feet, spawned by CombatFX on footsteps (and
## reusable for any "feet hit the ground" beat). A handful of earthy motes drift
## outward and fade. Code-built and palette-grounded; cheap enough to fire on a
## footstep cadence.

const COUNT := 5
const LIFE := 0.34

var _t: float = 0.0
var _motes: Array[Vector2] = []

func _ready() -> void:
	z_index = 4
	for i in COUNT:
		_motes.append(Vector2.from_angle(randf() * TAU) * randf_range(2.0, 5.0))
	var tw := create_tween()
	tw.tween_method(_set_t, 0.0, 1.0, LIFE)
	tw.tween_callback(queue_free)

func _set_t(v: float) -> void:
	_t = v
	queue_redraw()

func _draw() -> void:
	var alpha: float = (1.0 - _t) * 0.5
	if alpha <= 0.01:
		return
	var col := Color(0.74, 0.68, 0.58, alpha)
	for m in _motes:
		draw_circle(m * (0.5 + _t * 1.6), lerpf(2.0, 0.6, _t), col)
