extends Node
class_name Mana

## Reusable mana component, modelled on Health. Add as a child of a caster and
## call spend()/restore(). Regenerates slowly over time. Emits mana_changed on
## any change so a HUD bar can refresh without polling.

signal mana_changed(mana: int, max_mana: int)

@export var max_mana: int = 30
## Mana regained per second while not full (fractional; accumulated to whole pts).
@export var regen_per_sec: float = 2.0

var mana: int = 0
var _regen_accum: float = 0.0

func _ready() -> void:
	mana = max_mana
	# Defer so listeners connecting in their own _ready get the initial value.
	call_deferred("emit_signal", "mana_changed", mana, max_mana)

func _process(delta: float) -> void:
	if mana >= max_mana:
		_regen_accum = 0.0
		return
	_regen_accum += regen_per_sec * delta
	if _regen_accum >= 1.0:
		var whole: int = int(_regen_accum)
		_regen_accum -= whole
		mana = clampi(mana + whole, 0, max_mana)
		mana_changed.emit(mana, max_mana)

func has_mana(amount: int) -> bool:
	return mana >= amount

## Spend mana if affordable. Returns false (and spends nothing) if too low.
func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if mana < amount:
		return false
	mana -= amount
	mana_changed.emit(mana, max_mana)
	return true

func restore(amount: int) -> void:
	if amount <= 0:
		return
	mana = clampi(mana + amount, 0, max_mana)
	mana_changed.emit(mana, max_mana)
