extends Resource
class_name Item

## Base data for any item that can live in an inventory. Subclasses
## (WeaponItem, ArmorItem, ConsumableItem) add behavior-specific fields.

@export var id: StringName = &""
@export var name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var value: int = 0

func is_weapon() -> bool:
	return self is WeaponItem

func is_armor() -> bool:
	return self is ArmorItem

func is_consumable() -> bool:
	return self is ConsumableItem
