extends Node
class_name PlayerBuffs

## Timed combat buffs from food (and anything else that wants one). Each buff boosts
## a derived stat for a duration; the player folds bonus(stat) into its combat math
## and REGEN heals over time. Reapplying the same stat refreshes to the stronger
## amount and the longer remaining time (no stacking). Emits `changed` so the player
## can recompute its HP pool and the HUD can react. Buffs are transient (not saved).

signal changed

enum Stat { MELEE, RANGED, SPELL, DEFENSE, MAX_HP, SPEED, REGEN }

# Each entry: {"stat": int, "amount": int, "remaining": float}
var _active: Array = []
var _regen_accum: float = 0.0

## Apply (or refresh) a buff. amount is the stat bonus; REGEN's amount is HP/second.
func apply(stat: int, amount: int, duration: float) -> void:
	if stat < 0 or amount == 0 or duration <= 0.0:
		return
	for b in _active:
		if b["stat"] == stat:
			b["amount"] = maxi(b["amount"], amount)
			b["remaining"] = maxf(b["remaining"], duration)
			changed.emit()
			return
	_active.append({"stat": stat, "amount": amount, "remaining": duration})
	changed.emit()

## Total active bonus for a stat.
func bonus(stat: int) -> int:
	var total := 0
	for b in _active:
		if b["stat"] == stat:
			total += int(b["amount"])
	return total

## True if any buff is active (for HUD gating).
func has_any() -> bool:
	return not _active.is_empty()

## A copy of the active buff list ({stat, amount, remaining}) for the HUD to render.
func get_active() -> Array:
	return _active.duplicate(true)

func _process(delta: float) -> void:
	if _active.is_empty():
		return
	var expired := false
	for b in _active:
		b["remaining"] = float(b["remaining"]) - delta
		if b["remaining"] <= 0.0:
			expired = true
	# REGEN ticks whole HP as it accumulates.
	var rps := bonus(Stat.REGEN)
	if rps > 0:
		_regen_accum += float(rps) * delta
		if _regen_accum >= 1.0:
			var whole := int(_regen_accum)
			_regen_accum -= float(whole)
			var p := get_parent()
			if p != null and p.has_node("Health"):
				(p.get_node("Health") as Health).heal(whole)
	if expired:
		_active = _active.filter(func(b): return float(b["remaining"]) > 0.0)
		changed.emit()
