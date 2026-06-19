extends Resource
class_name Item

## Base data for any item that can live in an inventory. Subclasses
## (WeaponItem, ArmorItem, ConsumableItem) add behavior-specific fields.
##
## Equippable items (weapons/armor) may also carry a `rarity` and affix bonuses
## that apply while equipped — the Equipment component aggregates them and the
## combat code folds them in. Consumables ignore the affix fields.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [
	Color(0.82, 0.82, 0.82),  # Common
	Color(0.45, 0.78, 0.35),  # Uncommon
	Color(0.35, 0.6, 0.92),   # Rare
	Color(0.72, 0.45, 0.92),  # Epic
	Color(0.96, 0.66, 0.26),  # Legendary
]

@export var id: StringName = &""
@export var name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var value: int = 0

## --- Rarity & affixes (equippable items) ------------------------------------
@export var rarity: Rarity = Rarity.COMMON
@export var bonus_melee: int = 0
@export var bonus_ranged: int = 0
@export var bonus_spell: int = 0
@export var bonus_max_hp: int = 0
@export var bonus_defense: int = 0
## Fraction of melee damage dealt that is returned to the wielder as health.
@export_range(0.0, 1.0) var lifesteal: float = 0.0

func is_weapon() -> bool:
	return self is WeaponItem

func is_armor() -> bool:
	return self is ArmorItem

func is_consumable() -> bool:
	return self is ConsumableItem

func rarity_name() -> String:
	return RARITY_NAMES[rarity]

func rarity_color() -> Color:
	return RARITY_COLORS[rarity]

## True if this item carries any equip affix (for tooltip rendering).
func has_affixes() -> bool:
	return bonus_melee != 0 or bonus_ranged != 0 or bonus_spell != 0 \
		or bonus_max_hp != 0 or bonus_defense != 0 or lifesteal > 0.0

## Affix bonuses as ready-made "+N Melee" style lines for tooltips.
func affix_lines() -> Array:
	var lines: Array = []
	if bonus_melee != 0:
		lines.append("+%d Melee" % bonus_melee)
	if bonus_ranged != 0:
		lines.append("+%d Ranged" % bonus_ranged)
	if bonus_spell != 0:
		lines.append("+%d Spell" % bonus_spell)
	if bonus_max_hp != 0:
		lines.append("+%d Max HP" % bonus_max_hp)
	if bonus_defense != 0:
		lines.append("+%d Defense" % bonus_defense)
	if lifesteal > 0.0:
		lines.append("%d%% Lifesteal" % int(round(lifesteal * 100.0)))
	return lines
