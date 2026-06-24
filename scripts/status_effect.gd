extends Node
class_name StatusEffect

## A timed status applied to a target by parenting one of these under it.
##   BURN / POISON / BLEED — damage-over-time, ticking through take_damage() (each
##     tick pops a damage number, which is the on-screen tell).
##   SLOW  — scales the target's `speed` by `magnitude` in (0,1), restored on expiry.
##   STUN  — roots the target (speed 0) and reads as stunned via is_stunned(), so
##     enemies stop moving and can't wind up an attack until it lifts.
## Reapplying the same kind refreshes the timer instead of stacking. Self-frees when
## its duration elapses.

enum Kind { NONE, BURN, SLOW, POISON, BLEED, STUN }

const TICK_INTERVAL := 0.5
## The kinds that deal damage over time.
const DOT_KINDS := [Kind.BURN, Kind.POISON, Kind.BLEED]
## Kinds that zero the target's speed for their duration.
const ROOT_KINDS := [Kind.STUN]

var kind: int = Kind.NONE
var duration: float = 0.0
## DoT kinds: damage per tick. Others: unused.
var power: int = 0
## SLOW: speed multiplier in (0,1). Others: unused.
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

## True while `target` is under a rooting status (e.g. STUN) — used by AI to halt.
static func is_stunned(target: Node) -> bool:
	if target == null:
		return false
	for child: Node in target.get_children():
		if child is StatusEffect and (child as StatusEffect).kind in ROOT_KINDS:
			return true
	return false

func _ready() -> void:
	if kind == Kind.SLOW or kind in ROOT_KINDS:
		var t := get_parent()
		if t != null and "speed" in t:
			_orig_speed = t.speed
			t.speed = t.speed * (0.0 if kind in ROOT_KINDS else magnitude)

func _process(delta: float) -> void:
	_elapsed += delta
	if kind in DOT_KINDS:
		_tick += delta
		while _tick >= TICK_INTERVAL:
			_tick -= TICK_INTERVAL
			var t := get_parent()
			if t != null and t.has_method("take_damage"):
				t.take_damage(power, Vector2.ZERO, true)
	if _elapsed >= duration:
		_expire()

func refresh(new_duration: float) -> void:
	_elapsed = 0.0
	duration = maxf(duration, new_duration)

func _expire() -> void:
	if _orig_speed >= 0.0:
		var t := get_parent()
		if t != null and "speed" in t:
			t.speed = _orig_speed
	queue_free()
