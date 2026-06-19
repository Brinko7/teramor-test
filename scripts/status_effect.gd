extends Node
class_name StatusEffect

## A timed status applied to a target by parenting one of these under it. BURN
## ticks damage through the target's take_damage(); SLOW scales the target's
## `speed` and restores it on expiry. Reapplying the same kind refreshes the
## timer instead of stacking. Self-frees when its duration elapses.

enum Kind { NONE, BURN, SLOW }

const TICK_INTERVAL := 0.5

var kind: int = Kind.NONE
var duration: float = 0.0
## BURN: damage dealt per tick. SLOW: unused.
var power: int = 0
## SLOW: speed multiplier in (0,1). BURN: unused.
var magnitude: float = 1.0

var _elapsed: float = 0.0
var _tick: float = 0.0
var _orig_speed: float = -1.0

## Apply `kind` to `target`, refreshing an existing same-kind effect rather than
## stacking. Fields are set before add_child so _ready sees them.
static func apply(target: Node, kind_: int, power_: int, duration_: float, magnitude_: float = 1.0) -> void:
	if kind_ == Kind.NONE or target == null:
		return
	for child: Node in target.get_children():
		if child is StatusEffect and (child as StatusEffect).kind == kind_:
			(child as StatusEffect).refresh(duration_)
			return
	var fx := StatusEffect.new()
	fx.kind = kind_
	fx.power = power_
	fx.duration = duration_
	fx.magnitude = magnitude_
	target.add_child(fx)

func _ready() -> void:
	if kind == Kind.SLOW:
		var t := get_parent()
		if t != null and "speed" in t:
			_orig_speed = t.speed
			t.speed = t.speed * magnitude

func _process(delta: float) -> void:
	_elapsed += delta
	if kind == Kind.BURN:
		_tick += delta
		while _tick >= TICK_INTERVAL:
			_tick -= TICK_INTERVAL
			var t := get_parent()
			if t != null and t.has_method("take_damage"):
				t.take_damage(power)
	if _elapsed >= duration:
		_expire()

func refresh(new_duration: float) -> void:
	_elapsed = 0.0
	duration = maxf(duration, new_duration)

func _expire() -> void:
	if kind == Kind.SLOW and _orig_speed >= 0.0:
		var t := get_parent()
		if t != null and "speed" in t:
			t.speed = _orig_speed
	queue_free()
