extends Node
class_name Health

## Reusable health component. Add as a child of any entity and call
## take_damage()/heal(). Emits health_changed on any change and died once
## when health first reaches 0.

signal health_changed(health: int, max_health: int)
signal died

@export var max_health: int = 10

var health: int = 0
var _dead: bool = false

func _ready() -> void:
	health = max_health
	# Defer so listeners connecting in their own _ready get the initial value.
	call_deferred("emit_signal", "health_changed", health, max_health)

func take_damage(amount: int) -> void:
	if _dead or amount <= 0:
		return
	health = clampi(health - amount, 0, max_health)
	health_changed.emit(health, max_health)
	if health == 0 and not _dead:
		_dead = true
		died.emit()

func heal(amount: int) -> void:
	if _dead or amount <= 0:
		return
	health = clampi(health + amount, 0, max_health)
	health_changed.emit(health, max_health)

## Clears the death flag and restores health (defaults to full). Used by the
## respawn flow, since heal() refuses to act on a dead entity.
func revive(to_health: int = -1) -> void:
	_dead = false
	health = clampi(to_health if to_health > 0 else max_health, 1, max_health)
	health_changed.emit(health, max_health)

func is_dead() -> bool:
	return _dead
