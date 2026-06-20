extends Node2D
class_name SlashArc

## A short-lived melee swing arc, spawned by CombatFX when a melee attack lands.
## Sweeps a bright crescent across the strike direction, then fades and frees
## itself. Code-built (no .tscn) so it lives entirely on the grounded palette and
## costs nothing to author. Player swings read cool/bright; enemy swings read hot.

## Set before add_child — `_ready` reads them to orient and tint the sweep.
var dir: Vector2 = Vector2.RIGHT
var by_player: bool = true

const RADIUS := 16.0
const SPAN := deg_to_rad(115.0)
const LIFE := 0.16

var _t: float = 0.0
var _color: Color = Color.WHITE

func _ready() -> void:
	z_index = 60
	rotation = dir.angle()
	_color = Color(0.82, 0.95, 1.0, 0.95) if by_player else Color(1.0, 0.55, 0.4, 0.95)
	var tw := create_tween()
	tw.tween_method(_set_t, 0.0, 1.0, LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)

func _set_t(v: float) -> void:
	_t = v
	queue_redraw()

func _draw() -> void:
	var alpha: float = (1.0 - _t) * _color.a
	if alpha <= 0.01:
		return
	var col := Color(_color.r, _color.g, _color.b, alpha)
	# A trailing wedge whose leading edge sweeps across the span as t: 0 -> 1.
	var lead: float = lerpf(-SPAN * 0.5, SPAN * 0.5, _t)
	var tail: float = lead - SPAN * 0.5
	var r: float = lerpf(RADIUS * 0.7, RADIUS * 1.15, _t)
	draw_arc(Vector2.ZERO, r, tail, lead, 12, col, 2.5, true)
