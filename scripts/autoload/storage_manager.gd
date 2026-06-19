extends Node

## Autoload `StorageManager`. Owns the camp storage chest's shared stash.
##
## The stash is a full `Inventory` living as a child of this always-in-tree
## autoload, so SaveManager (which only walks nodes currently in the tree) never
## drops it when the player saves from a different scene — the same reason the
## farm state lives in FarmManager. Every chest prop is just a view onto this one
## stash, so items deposited at the camp are available from any chest.

## Holds more than the player's 24-slot bag so the camp reads as bulk storage.
const STASH_CAPACITY := 30

var stash: Inventory

func _ready() -> void:
	stash = Inventory.new()
	stash.name = "Stash"
	stash.capacity = STASH_CAPACITY
	stash.save_key = "camp_storage"
	stash.announce_collection = false
	add_child(stash)

## Clear the stash for a brand-new game (mirrors FarmManager.reset()).
func reset() -> void:
	if stash == null:
		return
	stash.slots.clear()
	stash.slots.resize(stash.capacity)
	stash.changed.emit()
