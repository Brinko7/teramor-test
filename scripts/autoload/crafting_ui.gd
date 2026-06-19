extends CanvasLayer

## Autoload `CraftingUI`. A crafting screen toggled with the "crafting" action.
## Loads every Recipe under res://resources/recipes/, lists them with their
## ingredient requirements, and marks each craftable when the bound player's
## Inventory satisfies all ingredients (Inventory.has_items). Crafting consumes
## each ingredient (Inventory.consume_items) then produces the result via
## Inventory.add_item and announces it on Events.item_crafted.

const RECIPES_DIR := "res://resources/recipes/"

@onready var _panel: PanelContainer = $Panel
@onready var _list: VBoxContainer = $Panel/Margin/VBox/List

var _player: Node = null
var _inventory: Inventory = null
var _recipes: Array[Recipe] = []
var _open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_panel.visible = false
	_load_recipes()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crafting"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if _open:
		_close()
	else:
		_open_screen()

func _open_screen() -> void:
	_bind_player()
	if _inventory == null:
		return
	_open = true
	_panel.visible = true
	if not _inventory.changed.is_connected(_refresh):
		_inventory.changed.connect(_refresh)
	_refresh()
	get_tree().paused = true

func _close() -> void:
	_open = false
	_panel.visible = false
	if _inventory != null and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	get_tree().paused = false

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_inventory = null
		return
	_inventory = _player.get_node_or_null("Inventory") as Inventory

func _load_recipes() -> void:
	_recipes.clear()
	var dir := DirAccess.open(RECIPES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean: String = file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var recipe := load(RECIPES_DIR + clean) as Recipe
				if recipe != null:
					_recipes.append(recipe)
		file_name = dir.get_next()
	dir.list_dir_end()

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	if _inventory == null:
		return
	for recipe in _recipes:
		_list.add_child(_make_recipe_row(recipe))

func _make_recipe_row(recipe: Recipe) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var craftable: bool = _can_craft(recipe)

	var label := Label.new()
	var result_name: String = recipe.result.name if recipe.result != null else "?"
	label.text = "%s x%d  [%s]" % [result_name, recipe.result_count, _ingredients_text(recipe)]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var settings := LabelSettings.new()
	settings.font_size = 10
	settings.font_color = Color(0.913725, 0.886275, 0.831373, 1) if craftable else Color(0.6, 0.55, 0.5, 1)
	label.label_settings = settings
	row.add_child(label)

	var btn := Button.new()
	btn.text = "Craft"
	btn.disabled = not craftable
	btn.pressed.connect(_on_craft_pressed.bind(recipe))
	row.add_child(btn)
	return row

func _ingredients_text(recipe: Recipe) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for ingredient in recipe.get_ingredients():
		var have: int = _inventory.count_of(ingredient["item_id"]) if _inventory != null else 0
		parts.append("%s %d/%d" % [String(ingredient["item_id"]), have, int(ingredient["count"])])
	return ", ".join(parts)

func _can_craft(recipe: Recipe) -> bool:
	if _inventory == null or recipe.result == null:
		return false
	for ingredient in recipe.get_ingredients():
		if not _inventory.has_items(ingredient["item_id"], int(ingredient["count"])):
			return false
	return true

func _on_craft_pressed(recipe: Recipe) -> void:
	if not _can_craft(recipe):
		return
	for ingredient in recipe.get_ingredients():
		_inventory.consume_items(ingredient["item_id"], int(ingredient["count"]))
	_inventory.add_item(recipe.result, recipe.result_count)
	Events.item_crafted.emit(recipe.result.id)
	_refresh()
