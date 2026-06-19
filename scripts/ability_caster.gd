extends Node
class_name AbilityCaster

## The player's spellbook + hotbar. The authored `hotbar` array is treated as the
## full catalog of elemental abilities; which of them are actually castable is
## driven by the skill tree via set_unlocked(). Casts by slot, gated on cooldown
## and the sibling Mana component. Adding a spell = author an AbilityData .tres,
## drop it in the catalog, and point a SkillNode's unlock_ability_id at it.

const PROJECTILE_SCENE := preload("res://scenes/entities/ability_projectile.tscn")
const NOVA_SCENE := preload("res://scenes/entities/ability_nova.tscn")

## Authored in the editor: the catalog of all elemental abilities the player can
## ever learn. The active hotbar is rebuilt from this by set_unlocked().
@export var hotbar: Array[AbilityData] = []

## Emitted whenever a cast succeeds (for FX/SFX hooks).
signal ability_cast(slot: int, ability: AbilityData)
## Emitted when any cooldown advances, so the hotbar HUD can refresh.
signal cooldowns_changed

var _cooldowns: Array[float] = []
## id -> AbilityData and the authored order, captured from the catalog at _ready.
var _catalog: Dictionary = {}
var _catalog_order: Array[StringName] = []

@onready var _mana: Mana = get_parent().get_node_or_null("Mana")
@onready var _stats: Stats = get_parent().get_node_or_null("Stats")

func _ready() -> void:
	for ability in hotbar:
		if ability != null:
			_catalog[ability.id] = ability
			_catalog_order.append(ability.id)
	# Nothing is castable until the skill tree unlocks it.
	hotbar.clear()
	_cooldowns.clear()

## Rebuild the active hotbar from the catalog for the given unlocked ability ids,
## preserving the authored order so slots stay stable.
func set_unlocked(ids: Array) -> void:
	var bar: Array[AbilityData] = []
	for cid in _catalog_order:
		if ids.has(cid) and _catalog.has(cid):
			bar.append(_catalog[cid])
	hotbar = bar
	_cooldowns.resize(hotbar.size())
	_cooldowns.fill(0.0)
	cooldowns_changed.emit()

func _process(delta: float) -> void:
	var changed: bool = false
	for i in range(_cooldowns.size()):
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
			changed = true
	if changed:
		cooldowns_changed.emit()

func slot_count() -> int:
	return hotbar.size()

func get_ability(slot: int) -> AbilityData:
	if slot < 0 or slot >= hotbar.size():
		return null
	return hotbar[slot]

## Remaining cooldown as a 0..1 fraction (1 = just cast), for the HUD overlay.
func cooldown_ratio(slot: int) -> float:
	var a := get_ability(slot)
	if a == null or a.cooldown <= 0.0 or slot >= _cooldowns.size():
		return 0.0
	return clampf(_cooldowns[slot] / a.cooldown, 0.0, 1.0)

func can_cast(slot: int) -> bool:
	var a := get_ability(slot)
	if a == null:
		return false
	if slot < _cooldowns.size() and _cooldowns[slot] > 0.0:
		return false
	if _mana != null and not _mana.has_mana(a.mana_cost):
		return false
	return true

## Try to cast slot `slot` from `origin` aimed along `aim`. Returns whether it
## fired (false if on cooldown, unaffordable, or empty).
func cast(slot: int, origin: Vector2, aim: Vector2) -> bool:
	if not can_cast(slot):
		return false
	var a := get_ability(slot)
	if _mana != null and not _mana.spend(a.mana_cost):
		return false
	if slot < _cooldowns.size():
		_cooldowns[slot] = a.cooldown
		cooldowns_changed.emit()
	_execute(a, origin, aim)
	ability_cast.emit(slot, a)
	return true

func _execute(a: AbilityData, origin: Vector2, aim: Vector2) -> void:
	var power: int = a.power + _spell_power()
	match a.behavior:
		AbilityData.Behavior.PROJECTILE:
			var p := PROJECTILE_SCENE.instantiate() as AbilityProjectile
			p.global_position = origin + aim * 8.0
			_world().add_child(p)
			p.setup(aim, power, a.projectile_speed, a.cast_range, a.tint,
				a.status_kind, a.status_power, a.status_duration, a.status_magnitude)
		AbilityData.Behavior.NOVA:
			var n := NOVA_SCENE.instantiate() as AbilityNova
			n.global_position = origin
			_world().add_child(n)
			n.setup(power, a.radius, a.tint,
				a.status_kind, a.status_power, a.status_duration, a.status_magnitude)
		AbilityData.Behavior.HEAL:
			var hp := get_parent().get_node_or_null("Health") as Health
			if hp != null:
				hp.heal(power)

func _spell_power() -> int:
	return _stats.spell_power() if _stats != null else 0

## Where spawned effects live: the player's parent (the world), matching how the
## player spawns arrows.
func _world() -> Node:
	return get_parent().get_parent()
