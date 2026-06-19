extends Node

## Autoload `QuestManager`. Tracks active and completed quests plus per-quest
## progress, advancing objectives from the global Events bus:
##   - KILL objectives count Events.enemy_killed whose enemy_id matches target_id
##     (an empty target_id counts any kill).
##   - COLLECT objectives advance when Events.item_collected matches target_id.
##
## On completion it grants rewards: XP is applied to the player's Stats, coin to
## the Wallet, and items to the player's Inventory. Repeatable quests (monster
## contracts) can be re-accepted instead of being stored as completed.
## Implements the SaveManager "persistent" contract and owns a Journal
## CanvasLayer toggled with the "journal" action.

signal quest_started(quest: Quest)
signal quest_progressed(quest: Quest, current: int)
signal quest_completed(quest: Quest)

## Active quests by id -> {quest: Quest, progress: int}.
var _active: Dictionary = {}
## Completed quest ids (StringName).
var _completed: Array[StringName] = []

var _journal: CanvasLayer = null
var _journal_list: VBoxContainer = null
var _journal_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("persistent")
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.item_collected.connect(_on_item_collected)
	_build_journal()

## --- Public API -------------------------------------------------------------

func start_quest(quest: Quest) -> bool:
	if quest == null:
		return false
	if _active.has(quest.id):
		return false
	if _completed.has(quest.id) and not quest.repeatable:
		return false
	_active[quest.id] = {"quest": quest, "progress": 0}
	quest_started.emit(quest)
	_refresh_journal()
	return true

func is_active(quest_id: StringName) -> bool:
	return _active.has(quest_id)

func is_completed(quest_id: StringName) -> bool:
	return _completed.has(quest_id)

func get_progress(quest_id: StringName) -> int:
	if _active.has(quest_id):
		return int((_active[quest_id] as Dictionary)["progress"])
	return 0

## --- Objective tracking -----------------------------------------------------

func _on_enemy_killed(enemy_id: StringName, _xp_reward: int, _position: Vector2) -> void:
	for quest_id in _active.keys():
		var entry: Dictionary = _active[quest_id]
		var quest: Quest = entry["quest"]
		if quest.objective != Quest.Objective.KILL:
			continue
		if quest.target_id == &"" or quest.target_id == enemy_id:
			_advance(quest, 1)

func _on_item_collected(item_id: StringName, count: int) -> void:
	for quest_id in _active.keys():
		var entry: Dictionary = _active[quest_id]
		var quest: Quest = entry["quest"]
		if quest.objective == Quest.Objective.COLLECT and quest.target_id == item_id:
			_advance(quest, count)

func _advance(quest: Quest, amount: int) -> void:
	if not _active.has(quest.id):
		return
	var entry: Dictionary = _active[quest.id]
	var progress: int = mini(int(entry["progress"]) + amount, quest.required_count)
	entry["progress"] = progress
	quest_progressed.emit(quest, progress)
	if progress >= quest.required_count:
		_complete(quest)
	else:
		_refresh_journal()

func _complete(quest: Quest) -> void:
	_active.erase(quest.id)
	if not quest.repeatable and not _completed.has(quest.id):
		_completed.append(quest.id)
	_grant_rewards(quest)
	quest_completed.emit(quest)
	_refresh_journal()
	print("[QuestManager] Quest complete: %s" % quest.title)

func _grant_rewards(quest: Quest) -> void:
	if quest.reward_xp > 0:
		var stats: Stats = _find_stats()
		if stats != null:
			stats.add_xp(quest.reward_xp)
	if quest.reward_coin > 0:
		Wallet.add(quest.reward_coin)
	if quest.reward_item != null and quest.reward_item_count > 0:
		var inventory: Inventory = _find_inventory()
		if inventory != null:
			inventory.add_item(quest.reward_item, quest.reward_item_count)
		else:
			push_warning("QuestManager: no player Inventory found to grant reward item")

func _find_inventory() -> Inventory:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("Inventory") as Inventory

func _find_stats() -> Stats:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("Stats") as Stats

## --- Journal UI -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		_toggle_journal()
		get_viewport().set_input_as_handled()
	elif _journal_open and event.is_action_pressed("ui_cancel"):
		_set_journal_open(false)
		get_viewport().set_input_as_handled()

func _toggle_journal() -> void:
	_set_journal_open(not _journal_open)

func _set_journal_open(open: bool) -> void:
	_journal_open = open
	if _journal != null:
		_journal.visible = open
	if open:
		_refresh_journal()

func _build_journal() -> void:
	_journal = CanvasLayer.new()
	_journal.layer = 90
	_journal.visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(0.964706))
	_journal.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.custom_minimum_size = Vector2(220, 0)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Quest Journal"
	var title_settings := LabelSettings.new()
	title_settings.font_size = 12
	title_settings.font_color = UITheme.ACCENT
	title.label_settings = title_settings
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_journal_list = VBoxContainer.new()
	_journal_list.add_theme_constant_override("separation", 6)
	vbox.add_child(_journal_list)

	var prompt := Label.new()
	prompt.text = "[J] Close"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var prompt_settings := LabelSettings.new()
	prompt_settings.font_size = 9
	prompt_settings.font_color = UITheme.TEXT
	prompt.label_settings = prompt_settings
	vbox.add_child(prompt)

	add_child(_journal)

func _refresh_journal() -> void:
	if _journal_list == null:
		return
	for child in _journal_list.get_children():
		child.queue_free()
	if _active.is_empty():
		_journal_list.add_child(_make_entry_label("No active quests.", ""))
		return
	for quest_id in _active.keys():
		var entry: Dictionary = _active[quest_id]
		var quest: Quest = entry["quest"]
		var progress: int = int(entry["progress"])
		var line: String = "%s  %d/%d" % [quest.title, progress, quest.required_count]
		_journal_list.add_child(_make_entry_label(line, quest.description))

func _make_entry_label(text: String, tooltip: String) -> Label:
	var label := Label.new()
	label.text = text
	label.tooltip_text = tooltip
	var settings := LabelSettings.new()
	settings.font_size = 10
	settings.font_color = UITheme.TEXT
	label.label_settings = settings
	return label

## --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "quests"

func save_state() -> Dictionary:
	var active_data: Array = []
	for quest_id in _active.keys():
		var entry: Dictionary = _active[quest_id]
		var quest: Quest = entry["quest"]
		active_data.append({
			"path": quest.resource_path,
			"progress": int(entry["progress"]),
		})
	var completed_data: Array = []
	for cid in _completed:
		completed_data.append(String(cid))
	return {"active": active_data, "completed": completed_data}

func load_state(data: Dictionary) -> void:
	_active.clear()
	_completed.clear()
	var completed_data: Array = data.get("completed", [])
	for cid in completed_data:
		_completed.append(StringName(cid))
	var active_data: Array = data.get("active", [])
	for raw in active_data:
		var entry: Dictionary = raw
		var quest := load(entry.get("path", "")) as Quest
		if quest != null:
			_active[quest.id] = {"quest": quest, "progress": int(entry.get("progress", 0))}
	_refresh_journal()
