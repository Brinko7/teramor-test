extends Item
class_name ArmorItem

## Wearable gear. One item per slot; total defense reduces incoming damage.

enum ArmorSlot { HEAD, BODY, FEET, OFFHAND, LEGS }

@export var armor_slot: ArmorSlot = ArmorSlot.BODY
@export var defense: int = 1
## 64x128 sheet matching the player's 4x4 layout, drawn over the body and
## synced to the body's animation frame. Used by BODY/HEAD/FEET pieces.
@export var overlay_sheet: Texture2D
## In-hand sprite for OFFHAND items (shields). Drawn pointing along +X.
@export var hold_texture: Texture2D
## Damage absorbed per hit while actively blocking with this off-hand item.
## A value > 0 marks the item as a shield.
@export var block: int = 0

func is_shield() -> bool:
	return armor_slot == ArmorSlot.OFFHAND and block > 0
