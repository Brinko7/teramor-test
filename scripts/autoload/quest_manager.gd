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
## Implements the SaveManager "persistent" contract. This is a pure data manager;
## the player menu (UIManager.menu) renders the quest list from its accessors and
## refreshes on the signals below.

signal quest_started(quest: Quest)
signal quest_progressed(quest: Quest, current: int)
signal quest_completed(quest: Quest)

## Active quests by id -> {quest: Quest, progress: int}.
var _active: Dictionary = {}
## Completed quest ids (StringName).
var _completed: Array[StringName] = []

func _ready() -> void:
	add_to_group("persistent")
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.item_collected.connect(_on_item_collected)

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
	return true

func is_active(quest_id: StringName) -> bool:
	return _active.has(quest_id)

func is_completed(quest_id: StringName) -> bool:
	return _completed.has(quest_id)

func get_progress(quest_id: StringName) -> int:
	if _active.has(quest_id):
		return int((_active[quest_id] as Dictionary)["progress"])
	return 0

## Active quests as an Array of {quest: Quest, progress: int}, for the menu.
func get_active_quests() -> Array:
	var out: Array = []
	for quest_id in _active.keys():
		var entry: Dictionary = _active[quest_id]
		out.append({"quest": entry["quest"], "progress": int(entry["progress"])})
	return out

func get_completed_count() -> int:
	return _completed.size()

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

func _complete(quest: Quest) -> void:
	_active.erase(quest.id)
	if not quest.repeatable and not _completed.has(quest.id):
		_completed.append(quest.id)
	_grant_rewards(quest)
	quest_completed.emit(quest)
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
