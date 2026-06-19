extends Node
class_name Stats

## Progression component. Tracks character level, accumulated XP, and the
## derived combat stats that grow with level (max HP, attack, defense). Attach
## as a child of an entity (the player) named "Stats". On every level-up the
## derived stats are recomputed and `Events.player_leveled_up` fires so other
## systems (Health, HUD, FX) can react.

## Emitted on any XP/level change so a local HUD can refresh without polling.
signal stats_changed

## --- Level / XP -------------------------------------------------------------
var level: int = 1
var xp: int = 0
var xp_to_next: int = 0

## --- Base stats at level 1, and per-level growth ----------------------------
@export var base_max_hp: int = 20
@export var base_attack: int = 4
@export var base_defense: int = 0

@export var base_spell_power: int = 3

@export var hp_per_level: int = 6
@export var attack_per_level: int = 2
@export var defense_per_level: int = 1
@export var spell_per_level: int = 1

## --- Derived (recomputed on every level-up) ---------------------------------
var max_hp: int = 0
var attack: int = 0
var defense: int = 0
var spell: int = 0

func _ready() -> void:
	add_to_group("persistent")
	_recompute_derived()
	xp_to_next = _xp_required(level)

## XP needed to advance FROM the given level to the next one. Quadratic growth
## keeps early levels quick and later levels meaningfully slower:
##   xp_to_next = 50 + level^2 * 10
func _xp_required(for_level: int) -> int:
	return 50 + for_level * for_level * 10

func _recompute_derived() -> void:
	var grown: int = level - 1
	max_hp = base_max_hp + hp_per_level * grown
	attack = base_attack + attack_per_level * grown
	defense = base_defense + defense_per_level * grown
	spell = base_spell_power + spell_per_level * grown

## Accumulate XP and resolve any number of level-ups in one pass.
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		_recompute_derived()
		xp_to_next = _xp_required(level)
		Events.player_leveled_up.emit(level)
	stats_changed.emit()

## Death penalty: forfeit progress toward the current level (never drops a
## level). A soft cost that stings without erasing earned power.
func apply_death_penalty() -> void:
	xp = 0
	stats_changed.emit()

func attack_power() -> int:
	return attack

func defense_power() -> int:
	return defense

## Bonus magnitude added to elemental ability power, scaling with level.
func spell_power() -> int:
	return spell

## Fraction (0..1) toward the next level, for HUD bars.
func xp_progress() -> float:
	if xp_to_next <= 0:
		return 0.0
	return clampf(float(xp) / float(xp_to_next), 0.0, 1.0)

## --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "player_stats"

func save_state() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
	}

func load_state(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	_recompute_derived()
	xp_to_next = _xp_required(level)
	stats_changed.emit()
