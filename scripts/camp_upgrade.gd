extends Resource
class_name CampUpgrade

## A purchasable camp improvement, bought with goods from the shared stash. Pure
## data: `CampManager` loads the catalog from resources/camp/upgrades/, tracks
## which are owned, and reads `effect`/`amount` to derive camp capabilities.
##
## Adding an upgrade is "author one .tres" — no code, as long as `effect` is one
## CampManager already understands (see CampManager.EFFECT_* / its accessors).

@export var id: StringName = &""
@export var display_name: String = "Improvement"
@export_multiline var description: String = ""

## Cost in stash goods: {item_id (StringName) -> count}.
@export var cost: Dictionary = {}

## What the upgrade grants. Known effects:
##   &"recruit_slots"      raise the roster cap by `amount`
##   &"plots_per_farmhand" each farmhand tends `amount` more plots a night
##   &"yield"              foragers/woodcutters bring `amount` more of each good
@export var effect: StringName = &""
@export var amount: int = 1

## Optional ordering hint for the menu (lower shows first).
@export var sort: int = 0

## Human-readable cost line, e.g. "12 Wood, 6 Stone", resolving item names lazily.
func cost_text() -> String:
	var parts: Array = []
	for item_id: Variant in cost:
		parts.append("%d %s" % [int(cost[item_id]), String(item_id).capitalize()])
	return ", ".join(parts)
