extends Node

## Autoload `Relationships`. Tracks how close the player is to each NPC.
##
## Friendship is stored as raw points; every `POINTS_PER_HEART` points is one
## heart, up to `MAX_HEARTS`. NPCs the player has spoken to at least once are
## "known" and appear in the relationships panel (toggle with the `relationships`
## action). Talking and gift-giving are limited per in-game day; `advance_day()`
## (called by the future sleep/camp system) resets those limits.
##
## Implements the SaveManager "persistent" contract.

signal points_changed(npc_id: StringName, points: int)
signal hearts_changed(npc_id: StringName, hearts: int)
signal npc_met(npc_id: StringName, display_name: String)

const POINTS_PER_HEART := 100
const MAX_HEARTS := 10
const MAX_POINTS := POINTS_PER_HEART * MAX_HEARTS

## Per-day affinity caps / amounts (Stardew-flavoured).
const TALK_POINTS := 15

## npc_id -> int points
var _points: Dictionary = {}
## npc_id -> display name (for the panel)
var _names: Dictionary = {}
## npc_id -> true if talked to since last day reset
var _talked_today: Dictionary = {}
## npc_id -> true if gifted since last day reset
var _gifted_today: Dictionary = {}
var _day: int = 1

var _panel_layer: CanvasLayer = null
var _list: VBoxContainer = null
var _open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("persistent")
	_build_panel()

# --- Queries ----------------------------------------------------------------

func get_points(npc_id: StringName) -> int:
	return int(_points.get(npc_id, 0))

func get_hearts(npc_id: StringName) -> int:
	return get_points(npc_id) / POINTS_PER_HEART

func is_known(npc_id: StringName) -> bool:
	return _names.has(npc_id)

func has_talked_today(npc_id: StringName) -> bool:
	return bool(_talked_today.get(npc_id, false))

func has_gifted_today(npc_id: StringName) -> bool:
	return bool(_gifted_today.get(npc_id, false))

# --- Mutations --------------------------------------------------------------

## Record that the player has met an NPC so it shows up in the panel.
func meet(npc_id: StringName, display_name: String) -> void:
	if _names.has(npc_id):
		return
	_names[npc_id] = display_name
	if not _points.has(npc_id):
		_points[npc_id] = 0
	npc_met.emit(npc_id, display_name)
	_refresh_panel()

## Add (or subtract) friendship points, clamped to [0, MAX_POINTS]. Emits
## points_changed always and hearts_changed when the heart count crosses.
func add_points(npc_id: StringName, amount: int) -> void:
	var before_hearts: int = get_hearts(npc_id)
	var updated: int = clampi(get_points(npc_id) + amount, 0, MAX_POINTS)
	_points[npc_id] = updated
	points_changed.emit(npc_id, updated)
	var after_hearts: int = updated / POINTS_PER_HEART
	if after_hearts != before_hearts:
		hearts_changed.emit(npc_id, after_hearts)
	_refresh_panel()

## Apply the once-per-day talk bonus. Returns true if it was awarded.
func try_talk(npc_id: StringName) -> bool:
	if has_talked_today(npc_id):
		return false
	_talked_today[npc_id] = true
	add_points(npc_id, TALK_POINTS)
	return true

## Mark a gift as given for the day. Caller applies the point change.
func mark_gifted(npc_id: StringName) -> void:
	_gifted_today[npc_id] = true

func advance_day() -> void:
	_day += 1
	_talked_today.clear()
	_gifted_today.clear()

## Wipe all relationship state for a brand-new game.
func reset() -> void:
	_points.clear()
	_names.clear()
	_talked_today.clear()
	_gifted_today.clear()
	_day = 1
	_refresh_panel()

func get_day() -> int:
	return _day

# --- Relationships panel ----------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("relationships"):
		_set_open(not _open)
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()

func _set_open(open: bool) -> void:
	_open = open
	if _panel_layer != null:
		_panel_layer.visible = open
	if open:
		_refresh_panel()

func _build_panel() -> void:
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 90
	_panel_layer.visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_layer.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.164706, 0.12549, 0.094118, 0.964706)
	style.set_border_width_all(1)
	style.border_color = Color(0.482353, 0.337255, 0.188235, 1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.custom_minimum_size = Vector2(220, 0)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Relationships"
	var title_settings := LabelSettings.new()
	title_settings.font_size = 12
	title_settings.font_color = Color(0.85, 0.78, 0.55, 1)
	title.label_settings = title_settings
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	vbox.add_child(_list)

	var prompt := Label.new()
	prompt.text = "[L] Close"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var prompt_settings := LabelSettings.new()
	prompt_settings.font_size = 9
	prompt_settings.font_color = Color(0.611765, 0.541176, 0.439216, 1)
	prompt.label_settings = prompt_settings
	vbox.add_child(prompt)

	add_child(_panel_layer)

func _refresh_panel() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		child.queue_free()
	if _names.is_empty():
		_list.add_child(_make_label("You haven't met anyone yet.", Color(0.7, 0.7, 0.7, 1)))
		return
	for npc_id: Variant in _names.keys():
		var hearts: int = get_hearts(npc_id)
		var bar: String = "%s%s" % ["♥".repeat(hearts), "♡".repeat(MAX_HEARTS - hearts)]
		var row: String = "%s   %s" % [String(_names[npc_id]), bar]
		_list.add_child(_make_label(row, Color(0.913725, 0.886275, 0.831373, 1)))

func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font_size = 11
	settings.font_color = color
	label.label_settings = settings
	return label

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "relationships"

func save_state() -> Dictionary:
	var points_out: Dictionary = {}
	for key: Variant in _points.keys():
		points_out[String(key)] = int(_points[key])
	var names_out: Dictionary = {}
	for key: Variant in _names.keys():
		names_out[String(key)] = String(_names[key])
	return {"points": points_out, "names": names_out, "day": _day}

func load_state(data: Dictionary) -> void:
	_points.clear()
	_names.clear()
	_talked_today.clear()
	_gifted_today.clear()
	var points_in: Dictionary = data.get("points", {})
	for key: Variant in points_in.keys():
		_points[StringName(key)] = int(points_in[key])
	var names_in: Dictionary = data.get("names", {})
	for key: Variant in names_in.keys():
		_names[StringName(key)] = String(names_in[key])
	_day = int(data.get("day", 1))
	_refresh_panel()
