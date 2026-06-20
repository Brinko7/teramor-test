extends Node2D
class_name TelegraphRing

## The wind-up "tell" for an enemy melee attack, spawned by CombatFX. A ring fills
## clockwise over the wind-up duration; when it completes, the strike lands — so a
## reading player learns to back out of range or block on the full ring. Pairs with
## the warm warn-glow the enemy sprite shows over the same window.

## Set before add_child.
var duration: float = 0.4
var dir: Vector2 = Vector2.DOWN

const RADIUS := 13.0

var _p: float = 0.0
var _col := Color(1.0, 0.5, 0.2, 0.9)

func _ready() -> void:
	z_index = 50
	var tw := create_tween()
	tw.tween_method(_set_p, 0.0, 1.0, maxf(0.05, duration))
	tw.tween_callback(queue_free)

func _set_p(v: float) -> void:
	_p = v
	queue_redraw()

func _draw() -> void:
	# Faint full track, then the filling sweep on top.
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.3), 2.0, true)
	var col := Color(_col.r, _col.g, _col.b, 0.85)
	draw_arc(Vector2.ZERO, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * _p, 24, col, 2.5, true)
	# A small tick that races ahead of the fill points where the blow will fall.
	var tip := Vector2.from_angle(-PI * 0.5 + TAU * _p) * RADIUS
	draw_circle(tip, lerpf(1.5, 2.5, _p), col)
