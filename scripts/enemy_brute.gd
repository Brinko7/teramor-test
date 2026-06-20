extends Enemy
class_name EnemyBrute

## Slow, tanky bruiser. High HP, heavy contact damage, and a big XP payout, but
## lumbering: it has a longer detection range (it notices you from afar) yet
## telegraphs by pausing briefly before each lurch forward, so a nimble player
## can kite it. Worth the effort for the loot.

## Pause (seconds) between forward lurches while chasing.
@export var lurch_pause: float = 0.5
## Duration (seconds) of each forward lurch.
@export var lurch_duration: float = 1.1

var _phase_timer: float = 0.0
var _lurching: bool = false

func _ready() -> void:
	super._ready()
	_lurching = true
	_phase_timer = lurch_duration

func _decide_input(delta: float) -> Vector2:
	if _target != null and is_instance_valid(_target):
		var to_target: Vector2 = _target.global_position - global_position
		if to_target.length() <= detect_range:
			_advance_lurch(delta)
			if _lurching:
				return to_target.normalized()
			return Vector2.ZERO

	# Out of range: behave like a normal wandering enemy.
	_lurching = true
	_phase_timer = lurch_duration
	return _wander(delta)

func _advance_lurch(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_lurching = not _lurching
		_phase_timer = lurch_duration if _lurching else lurch_pause
