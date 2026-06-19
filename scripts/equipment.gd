extends Node
class_name Equipment

## Tracks the player's equipped weapon and armor pieces. Emits `changed`
## whenever a slot is swapped so combat/UI can react.

signal changed

var weapon: WeaponItem = null
var armor: Dictionary = {}  ## ArmorItem.ArmorSlot -> ArmorItem

func _ready() -> void:
	add_to_group("persistent")

## Equip a weapon. Returns the previously equipped weapon (or null).
func equip_weapon(item: WeaponItem) -> WeaponItem:
	var prev: WeaponItem = weapon
	weapon = item
	changed.emit()
	return prev

func unequip_weapon() -> WeaponItem:
	return equip_weapon(null)

## Equip armor into its slot. Returns whatever was in that slot before.
func equip_armor(item: ArmorItem) -> ArmorItem:
	if item == null:
		return null
	var prev: ArmorItem = armor.get(item.armor_slot, null)
	armor[item.armor_slot] = item
	changed.emit()
	return prev

func unequip_armor(slot: int) -> ArmorItem:
	var prev: ArmorItem = armor.get(slot, null)
	if prev != null:
		armor.erase(slot)
		changed.emit()
	return prev

func get_weapon() -> WeaponItem:
	return weapon

func get_armor(slot: int) -> ArmorItem:
	return armor.get(slot, null)

func get_shield() -> ArmorItem:
	var off: ArmorItem = armor.get(ArmorItem.ArmorSlot.OFFHAND, null)
	return off if off != null and off.is_shield() else null

func get_body() -> ArmorItem:
	return armor.get(ArmorItem.ArmorSlot.BODY, null)

func total_defense() -> int:
	var total: int = 0
	for piece in armor.values():
		total += (piece as ArmorItem).defense
	# Affix defense from any equipped piece (armor or weapon).
	total += _affix_sum(&"bonus_defense")
	return total

# --- Affix aggregation ------------------------------------------------------

## Sum an affix field across every equipped item (weapon + all armor).
func _affix_sum(field: StringName) -> int:
	var total: int = 0
	if weapon != null:
		total += int(weapon.get(field))
	for piece in armor.values():
		total += int((piece as Item).get(field))
	return total

func bonus_melee() -> int:
	return _affix_sum(&"bonus_melee")

func bonus_ranged() -> int:
	return _affix_sum(&"bonus_ranged")

func bonus_spell() -> int:
	return _affix_sum(&"bonus_spell")

func bonus_max_hp() -> int:
	return _affix_sum(&"bonus_max_hp")

## Highest lifesteal fraction among equipped items (they don't stack).
func lifesteal() -> float:
	var best: float = 0.0
	if weapon != null:
		best = maxf(best, weapon.lifesteal)
	for piece in armor.values():
		best = maxf(best, (piece as Item).lifesteal)
	return best

## --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "player_equipment"

func save_state() -> Dictionary:
	var armor_paths: Dictionary = {}
	for slot in armor:
		armor_paths[str(slot)] = (armor[slot] as ArmorItem).resource_path
	return {
		"weapon": weapon.resource_path if weapon != null else "",
		"armor": armor_paths,
	}

func load_state(data: Dictionary) -> void:
	var weapon_path: String = data.get("weapon", "")
	weapon = load(weapon_path) as WeaponItem if not weapon_path.is_empty() else null
	armor.clear()
	var armor_paths: Dictionary = data.get("armor", {})
	for key in armor_paths:
		var piece := load(armor_paths[key]) as ArmorItem
		if piece != null:
			armor[int(key)] = piece
	changed.emit()
