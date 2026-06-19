extends Node

## Autoload `GameManager`. Owns high-level game flow: starting a new game,
## continuing from a save, returning to the menu, and the death -> game-over ->
## respawn loop. The game-over screen is built in code as an always-processing
## CanvasLayer so its buttons stay responsive while the rest of the tree is
## paused.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const CHARACTER_CREATION := "res://scenes/ui/character_creation.tscn"
const WORLD := "res://scenes/world/settlement.tscn"

var _layer: CanvasLayer
var _panel: Control
var _button_box: VBoxContainer
var _sleeping: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()

# --- Flow transitions -------------------------------------------------------

## Start a fresh run: pick identity first, then drop into the world. Leaves any
## existing save file untouched until the player chooses to save over it.
func new_game() -> void:
	_dismiss()
	get_tree().change_scene_to_file(CHARACTER_CREATION)

## Called by the character-creation screen once the player confirms their look.
## Seeds a fresh narrative state before dropping into the world.
func enter_world() -> void:
	_dismiss()
	Relationships.reset()
	Wallet.reset()
	TimeManager.reset()
	FarmManager.reset()
	StorageManager.reset()
	WorldMap.reset()
	Story.start_new_game()
	get_tree().change_scene_to_file(WORLD)

## Load the world, then restore the saved snapshot once it is in the tree.
func continue_game() -> void:
	_dismiss()
	get_tree().change_scene_to_file(WORLD)
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.load_all()

func to_menu() -> void:
	_dismiss()
	get_tree().change_scene_to_file(MAIN_MENU)

# --- Sleep / day advance ----------------------------------------------------

## Sleep until 06:00 the next morning. Fades out, advances the clock and the
## relationship/gift day, restores the player to full health, autosaves, then
## fades back in. Called by the bed prop once the player confirms.
func sleep_until_morning() -> void:
	if _sleeping:
		return
	_sleeping = true
	await SceneManager.fade_to_black()
	TimeManager.sleep()
	Relationships.advance_day()
	_heal_player_full()
	SaveManager.save_all()
	await get_tree().create_timer(0.5).timeout
	await SceneManager.fade_from_black()
	_sleeping = false

func _heal_player_full() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var health: Node = player.get_node_or_null("Health")
	if health != null and health.has_method("heal"):
		health.call("heal", health.get("max_health"))

# --- Death / respawn --------------------------------------------------------

func player_died() -> void:
	_refresh_buttons()
	_panel.visible = true
	get_tree().paused = true
	if _button_box.get_child_count() > 0:
		(_button_box.get_child(0) as Button).grab_focus()

func respawn() -> void:
	_dismiss()
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("revive"):
		player.call("revive")

func _load_save() -> void:
	_dismiss()
	SaveManager.load_all()
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("revive"):
		# load_state restores HP, but if it was saved at 0 keep them alive.
		var health: Node = player.get_node_or_null("Health")
		if health != null and health.call("is_dead"):
			player.call("revive")

func _dismiss() -> void:
	get_tree().paused = false
	_panel.visible = false

# --- Game-over overlay ------------------------------------------------------

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "You Died"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", UITheme.DANGER)
	box.add_child(title)

	_button_box = VBoxContainer.new()
	_button_box.add_theme_constant_override("separation", 8)
	box.add_child(_button_box)

func _refresh_buttons() -> void:
	for child in _button_box.get_children():
		child.queue_free()

	_add_button("Respawn", respawn)
	if SaveManager.has_save():
		_add_button("Load Last Save", _load_save)
	_add_button("Quit to Menu", to_menu)

func _add_button(text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 0)
	button.pressed.connect(handler)
	_button_box.add_child(button)
