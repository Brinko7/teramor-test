extends Enemy
class_name EnemyBearCub

## A bear cub — Beast faction, but a NON-COMBATANT. It never attacks (contact
## damage is suppressed) and never hunts: it ambles, and when hurt it FLEES from
## the nearest threat while raising the alarm — calling `provoke()` on every adult
## bear within `alarm_radius`. Hurting a cub is what turns a calm clearing into a
## furious mother bear. Authored beside an EnemyBear in the "protect the young"
## encounter, but harmless on its own.

## Speed while fleeing a threat.
@export var flee_speed: float = 70.0
## How long the cub keeps fleeing after being hurt (seconds).
@export var flee_duration: float = 3.0
## Bears within this distance are enraged when the cub is struck.
@export var alarm_radius: float = 260.0

var _flee_timer: float = 0.0
var _threat: Node2D = null

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, from_player: bool = false) -> void:
	super.take_damage(amount, knockback, from_player)
	_flee_timer = flee_duration
	_threat = get_tree().get_first_node_in_group("player") as Node2D
	_alarm_bears()

func _alarm_bears() -> void:
	for other in get_tree().get_nodes_in_group("enemy"):
		if other is EnemyBear and is_instance_valid(other):
			if global_position.distance_to((other as EnemyBear).global_position) <= alarm_radius:
				(other as EnemyBear).provoke()

## Cubs are harmless — never deal contact damage.
func _check_touch() -> void:
	pass

func _decide_input(delta: float) -> Vector2:
	if _flee_timer > 0.0:
		_flee_timer -= delta
		if _threat != null and is_instance_valid(_threat):
			speed = flee_speed
			return (global_position - _threat.global_position).normalized()
	return _wander(delta)
