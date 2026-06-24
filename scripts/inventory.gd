extends Node
class_name Inventory

## Slot-based bag. Each slot is a Dictionary {item: Item, count: int}.
## Stacks identical items up to item.max_stack. Emits `changed` on any edit.

signal changed

@export var capacity: int = 24

## Stable key under which SaveManager persists this bag. The player's bag keeps
## the default; other bags (e.g. a storage chest's stash) must set a unique key.
@export var save_key: String = "player_inventory"

## Whether adding items announces `Events.item_collected` (which drives "collect
## N" quests). The player's bag should; a storage stash should not — depositing
## into a chest is not "collecting".
@export var announce_collection: bool = true

var slots: Array[Dictionary] = []

func _ready() -> void:
	slots.resize(capacity)
	add_to_group("persistent")

## Add `count` of `item`. Returns the number that did NOT fit.
func add_item(item: Item, count: int = 1) -> int:
	if item == null or count <= 0:
		return count
	var remaining: int = count
	# Fill existing stacks of the same item first.
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot: Dictionary = slots[i]
		if not slot.is_empty() and slot["item"] == item:
			var space: int = item.max_stack - int(slot["count"])
			var moved: int = mini(space, remaining)
			slot["count"] = int(slot["count"]) + moved
			remaining -= moved
	# Then open empty slots.
	for i in range(slots.size()):
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var moved: int = mini(item.max_stack, remaining)
			slots[i] = {"item": item, "count": moved}
			remaining -= moved
	var added: int = count - remaining
	if added > 0:
		changed.emit()
		if announce_collection:
			Events.item_collected.emit(item.id, added)
	return remaining

## Remove `count` from the slot at `index`. Returns how many were removed.
func remove_at(index: int, count: int = 1) -> int:
	if index < 0 or index >= slots.size() or slots[index].is_empty():
		return 0
	var slot: Dictionary = slots[index]
	var removed: int = mini(int(slot["count"]), count)
	var left: int = int(slot["count"]) - removed
	if left <= 0:
		slots[index] = {}
	else:
		slot["count"] = left
	changed.emit()
	return removed

func get_item(index: int) -> Item:
	if index < 0 or index >= slots.size() or slots[index].is_empty():
		return null
	return slots[index]["item"]

func get_count(index: int) -> int:
	if index < 0 or index >= slots.size() or slots[index].is_empty():
		return 0
	return int(slots[index]["count"])

## --- Crafting support -------------------------------------------------------

## Total quantity of an item (matched by Item.id) across all stacks.
func count_of(item_id: StringName) -> int:
	var total: int = 0
	for slot in slots:
		if not slot.is_empty() and (slot["item"] as Item).id == item_id:
			total += int(slot["count"])
	return total

func has_items(item_id: StringName, count: int) -> bool:
	return count_of(item_id) >= count

## Remove `count` of an item (by id) from any stacks. Returns true if the full
## amount was removed; false (and removes nothing) if there wasn't enough.
func consume_items(item_id: StringName, count: int) -> bool:
	if not has_items(item_id, count):
		return false
	var remaining: int = count
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot: Dictionary = slots[i]
		if slot.is_empty() or (slot["item"] as Item).id != item_id:
			continue
		var taken: int = mini(int(slot["count"]), remaining)
		remaining -= taken
		var left: int = int(slot["count"]) - taken
		if left <= 0:
			slots[i] = {}
		else:
			slot["count"] = left
	changed.emit()
	return true

## --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return save_key

func save_state() -> Dictionary:
	var entries: Array = []
	for slot in slots:
		if slot.is_empty():
			entries.append(null)
		else:
			var it := slot["item"] as Item
			# A rolled instance has no resource_path of its own — persist the base
			# path so load can reload it and re-apply the rolled stats.
			var path: String = it.base_path if it.rolled and it.base_path != "" else it.resource_path
			var entry := {
				"path": path,
				"count": int(slot["count"]),
			}
			# Rolled drops are unique instances — store their stats by value so the
			# roll survives a save/load (reloading the base .tres would lose it).
			if it.rolled:
				entry["rolled"] = {
					"name": it.name, "rarity": int(it.rarity),
					"melee": it.bonus_melee, "ranged": it.bonus_ranged, "spell": it.bonus_spell,
					"hp": it.bonus_max_hp, "defense": it.bonus_defense, "lifesteal": it.lifesteal,
					"oh_kind": it.on_hit_status, "oh_power": it.on_hit_power,
					"oh_dur": it.on_hit_duration, "oh_chance": it.on_hit_chance, "oh_mag": it.on_hit_magnitude,
				}
			entries.append(entry)
	return {"slots": entries}

func load_state(data: Dictionary) -> void:
	var entries: Array = data.get("slots", [])
	slots.clear()
	slots.resize(capacity)
	for i in range(mini(entries.size(), capacity)):
		var entry: Variant = entries[i]
		if entry == null:
			continue
		var item := load(entry["path"]) as Item
		if item != null:
			if entry.has("rolled"):
				item = _restore_rolled(item, entry["rolled"])
			slots[i] = {"item": item, "count": int(entry["count"])}
	changed.emit()

## Rebuild a rolled drop from its saved-by-value stats on top of the base item.
func _restore_rolled(base: Item, r: Dictionary) -> Item:
	var item := base.duplicate(true) as Item
	if item == null:
		return base
	item.name = String(r.get("name", base.name))
	item.rarity = int(r.get("rarity", base.rarity)) as Item.Rarity
	item.bonus_melee = int(r.get("melee", 0))
	item.bonus_ranged = int(r.get("ranged", 0))
	item.bonus_spell = int(r.get("spell", 0))
	item.bonus_max_hp = int(r.get("hp", 0))
	item.bonus_defense = int(r.get("defense", 0))
	item.lifesteal = float(r.get("lifesteal", 0.0))
	item.on_hit_status = int(r.get("oh_kind", 0))
	item.on_hit_power = int(r.get("oh_power", 0))
	item.on_hit_duration = float(r.get("oh_dur", 0.0))
	item.on_hit_chance = float(r.get("oh_chance", 0.0))
	item.on_hit_magnitude = float(r.get("oh_mag", 1.0))
	item.rolled = true
	item.base_path = base.resource_path
	return item
