extends Area2D

## One tile of farmable ground. A thin view over FarmManager: it draws the soil
## and crop from the shared state for `plot_id` and redraws when that state
## changes. Implements the shared INTERACT contract (collision layer 32, the
## "interactable" group, plus `interact(player)`); interacting opens a
## context-sensitive Dialogue menu to till / plant / water / harvest, gated by
## the tools and seeds in the player's bag.
##
## Growth happens in FarmManager on each new day, not here, so a plot keeps
## advancing while you are away and survives a save/load.

const SOIL_UNTILLED := preload("res://assets/placeholder/soil_untilled.png")
const SOIL_TILLED := preload("res://assets/placeholder/soil_tilled.png")
const SOIL_WATERED := preload("res://assets/placeholder/soil_watered.png")

## Globally-unique id for this plot's state. Leave blank to derive a stable id
## from the placement position (fine as long as the plot isn't moved later).
@export var plot_id: String = ""

@onready var _soil: Sprite2D = $Soil
@onready var _crop: Sprite2D = $Crop

var _player: Node = null

func _ready() -> void:
	add_to_group("interactable")
	if plot_id == "":
		plot_id = "plot_%d_%d" % [roundi(global_position.x), roundi(global_position.y)]
	FarmManager.plot_changed.connect(_on_plot_changed)
	_render()

func _on_plot_changed(changed_id: String) -> void:
	if changed_id == plot_id:
		_render()

func _render() -> void:
	if FarmManager.is_watered(plot_id):
		_soil.texture = SOIL_WATERED
	elif FarmManager.is_tilled(plot_id):
		_soil.texture = SOIL_TILLED
	else:
		_soil.texture = SOIL_UNTILLED
	var crop := FarmManager.get_crop(plot_id)
	if crop != null:
		_crop.texture = crop.texture_for_days(FarmManager.get_days(plot_id))
		_crop.visible = _crop.texture != null
	else:
		_crop.visible = false

# --- Interaction ------------------------------------------------------------

func interact(player) -> void:
	_player = player
	UIManager.dialogue.start_conversation([], _build_menu, "Farm Plot")

func _build_menu() -> Dictionary:
	var inv: Inventory = _bag()
	var choices: Array = []
	var status: String = ""

	if not FarmManager.is_tilled(plot_id):
		status = "Bare ground."
		if _has_tool(inv, &"hoe"):
			choices.append({"text": "Till the soil", "effect": _till})
		else:
			status += " You need a hoe to work it."
	elif not FarmManager.has_crop(plot_id):
		status = "Tilled soil, ready to plant."
		if not _seeds_in_bag(inv).is_empty():
			choices.append({"text": "Plant seeds...", "submenu": _build_plant_menu})
		else:
			status += " You have no seeds — buy some in town."
	else:
		var crop := FarmManager.get_crop(plot_id)
		if FarmManager.is_mature(plot_id):
			status = "%s — ready to harvest!" % crop.display_name
			choices.append({
				"text": "Harvest",
				"effect": _harvest,
				"then": ["You gather %d %s." % [crop.produce_count, crop.produce.name]],
			})
		else:
			var day: int = FarmManager.get_days(plot_id)
			status = "%s — growing (day %d of %d)." % [crop.display_name, day, crop.days_to_mature()]
			if FarmManager.is_watered(plot_id):
				status += " Watered for today."
			elif _has_tool(inv, &"watering_can"):
				choices.append({"text": "Water", "effect": _water})
			else:
				status += " It looks dry."

	choices.append({"text": "Leave", "close": true})
	return {"text": status, "choices": choices}

func _build_plant_menu() -> Dictionary:
	var inv: Inventory = _bag()
	var choices: Array = []
	for seed: SeedItem in _seeds_in_bag(inv):
		choices.append({
			"text": "%s (%d)" % [seed.name, inv.count_of(seed.id)],
			"effect": _plant.bind(seed),
			"back": true,
		})
	choices.append({"text": "Back", "back": true})
	return {"text": "Plant which seeds?", "choices": choices}

# --- Effects ----------------------------------------------------------------

func _till() -> void:
	FarmManager.till(plot_id)

func _plant(seed: SeedItem) -> void:
	if seed == null or seed.crop == null:
		return
	if FarmManager.plant(plot_id, seed.crop):
		_bag().consume_items(seed.id, 1)

func _water() -> void:
	FarmManager.water(plot_id)

func _harvest() -> void:
	var crop := FarmManager.harvest(plot_id)
	if crop != null and crop.produce != null:
		_bag().add_item(crop.produce, crop.produce_count)

# --- Helpers ----------------------------------------------------------------

func _bag() -> Inventory:
	return _player.get_node("Inventory") as Inventory

func _has_tool(inv: Inventory, kind: StringName) -> bool:
	if inv == null:
		return false
	for slot: Dictionary in inv.slots:
		if slot.is_empty():
			continue
		var it: Item = slot["item"]
		if it is ToolItem and (it as ToolItem).tool_kind == kind:
			return true
	return false

func _seeds_in_bag(inv: Inventory) -> Array:
	var out: Array = []
	if inv == null:
		return out
	var seen: Dictionary = {}
	for slot: Dictionary in inv.slots:
		if slot.is_empty():
			continue
		var it: Item = slot["item"]
		if it is SeedItem and not seen.has(it.id):
			seen[it.id] = true
			out.append(it)
	return out
