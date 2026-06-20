extends Enemy
class_name EnemyBear

## A big, slow brown bear — Beast faction. Normally placid: it has a SHORT calm
## detection range, so the player can pass at a distance without a fight (this is
## what makes the wilds feel "semi-peaceful"). But provoke it — strike it, or
## threaten a cub (a hurt cub calls `provoke()` on nearby bears) — and it
## ENRAGES: its detection range balloons and it charges faster for a while. This
## is the "bear protecting its young" beat from the encounter design.

## Detection range while calm (small — you can skirt it).
@export var calm_detect_range: float = 64.0
## Detection range once enraged (it hunts you down).
@export var enraged_detect_range: float = 220.0
## How long a rage lasts after the last provocation (seconds).
@export var enrage_duration: float = 8.0
## Speed multiplier applied while enraged and chasing.
@export var charge_multiplier: float = 1.7

var _enrage_timer: float = 0.0
var _base_speed: float = 0.0

func _ready() -> void:
	super._ready()
	_base_speed = speed
	detect_range = calm_detect_range

## Drive the bear into a rage. Called when struck and by a threatened cub.
func provoke() -> void:
	_enrage_timer = enrage_duration
	detect_range = enraged_detect_range

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, from_player: bool = false) -> void:
	super.take_damage(amount, knockback, from_player)
	provoke()

func _decide_input(delta: float) -> Vector2:
	if _enrage_timer > 0.0:
		_enrage_timer -= delta
		if _enrage_timer <= 0.0:
			detect_range = calm_detect_range
	if _target != null and is_instance_valid(_target):
		var to_target: Vector2 = _target.global_position - global_position
		if to_target.length() <= detect_range:
			speed = _base_speed * charge_multiplier if _enrage_timer > 0.0 else _base_speed
			return to_target.normalized()
	speed = _base_speed
	return _wander(delta)
