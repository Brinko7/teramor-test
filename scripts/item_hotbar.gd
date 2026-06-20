extends Node
class_name ItemHotbar

## The quick-access item bar: a thin selector over the first SIZE slots of the
## sibling Inventory, bound to keyboard keys 1–0 (and the mouse wheel). It owns
## no items of its own — slot N here IS inventory slot N — so picking things up,
## reordering the bag, or using an item all flow through naturally. `use_active`
## drinks a consumable in the selected slot; selecting a non-usable item (gear,
## seed, tool) just makes it the "held" item for the HUD to highlight.

## How many quick slots: keys 1..9 then 0 = ten slots over inventory[0..9].
const SIZE := 10

## Emitted when the highlighted slot changes (the HUD listens to re-draw).
signal selection_changed(index: int)

var selected: int = 0

@onready var _inv: Inventory = get_parent().get_node_or_null("Inventory")

## Point the highlight at slot `index` (clamped to the bar). Idempotent — re-
## selecting the active slot still emits so a double-tap can feel responsive.
func select(index: int) -> void:
	selected = clampi(index, 0, SIZE - 1)
	selection_changed.emit(selected)

## Step the selection by `dir` (+1 / -1) with wrap-around, for the mouse wheel.
func cycle(dir: int) -> void:
	select(posmod(selected + dir, SIZE))

## The Item in the selected slot, or null if it's empty.
func active_item() -> Item:
	if _inv == null:
		return null
	return _inv.get_item(selected)

## Use the selected item. Consumables are drunk and one is removed from the
## stack; anything else is a no-op for now (gear is equipped from the menu,
## seeds/tools are spent through the farm-plot prompt). Returns whether it fired.
func use_active(user: Node) -> bool:
	var item: Item = active_item()
	if item == null:
		return false
	if item is ConsumableItem:
		if (item as ConsumableItem).use(user):
			_inv.remove_at(selected, 1)
			return true
	return false
