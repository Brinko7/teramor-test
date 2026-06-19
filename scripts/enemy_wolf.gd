extends Enemy
class_name EnemyWolf

## Fast, fragile pack hunter. Low HP and low XP, but quick and twitchy: when it
## spots the player it lunges in short bursts (brief speed spikes with small
## pauses), making it dangerous in numbers despite its frailty.

## Multiplier applied to `speed` during a lunge burst.
@export var lunge_multiplier: float = 1.8
## How long a single lunge burst lasts (seconds).
@export var lunge_duration: float = 0.45
## Cooldown between lunges while chasing (seconds).
@export var lunge_cooldown: float = 0.6

var _lunge_timer: float = 0.0
var _lunge_cd: float = 0.0
var _base_speed: float = 0.0

func _ready() -> void:
	super._ready()
	_base_speed = speed

func _decide_input(delta: float) -> Vector2:
	_lunge_cd = maxf(0.0, _lunge_cd - delta)
	_lunge_timer = maxf(0.0, _lunge_timer - delta)

	if _player != null and is_instance_valid(_player):
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() <= detect_range:
			if _lunge_timer <= 0.0 and _lunge_cd <= 0.0:
				_lunge_timer = lunge_duration
				_lunge_cd = lunge_duration + lunge_cooldown
			speed = _base_speed * lunge_multiplier if _lunge_timer > 0.0 else _base_speed
			return to_player.normalized()

	speed = _base_speed
	return _wander(delta)
