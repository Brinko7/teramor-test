extends Node

## Autoload `QuestManager`. Tracks active and completed quests with per-objective
## progress, advancing objectives from the global Events bus:
##   - KILL objectives count Events.enemy_killed whose enemy_id matches the
##     objective target (an empty target counts any kill).
##   - COLLECT objectives advance when Events.item_collected matches the target.
##   - STORY objectives advance when the Story system calls advance_story().
##
## A quest completes once every objective is met. If it `requires_turn_in`, it
## instead becomes "ready" and must be turned in to its giver NPC (see turn_in).
## On completion it grants rewards: XP to the player's Stats, coin to the Wallet,
## items to the player's Inventory. Repeatable quests (monster contracts) can be
## re-accepted instead of being stored as completed.
##
## One quest at a time is "tracked" for the on-screen tracker HUD. This is a pure
## data manager — the player menu and tracker render from its accessors and the
## signals below. Implements the SaveManager "persistent" contract.

signal quest_started(quest: Quest)
signal quest_progressed(quest: Quest)
signal quest_ready(quest: Quest)
signal quest_completed(quest: Quest)
## Emitted when the tracked quest changes; `quest` is null when nothing is tracked.
signal tracked_changed(quest: Quest)

## Active quests by id -> {quest: Quest, progress: Array[int], ready: bool}.
var _active: Dictionary = {}
## Completed quest ids (StringName).
var _completed: Array[StringName] = []
## Id of the quest shown in the on-screen tracker (&"" for none).
var _tracked_id: StringName = &""

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
	_active[quest.id] = {
		"quest": quest,
		"progress": _zeros(quest.get_objectives().size()),
		"ready": false,
	}
	quest_started.emit(quest)
	if _tracked_id == &"":
		set_tracked(quest.id)
	return true

## Turn in a quest that is ready (all objectives met, requires_turn_in). Returns
## true if it was completed.
func turn_in(quest_id: StringName) -> bool:
	if not is_ready(quest_id):
		return false
	_complete(_active[quest_id]["quest"])
	return true

func is_active(quest_id: StringName) -> bool:
	return _active.has(quest_id)

func is_completed(quest_id: StringName) -> bool:
	return _completed.has(quest_id)

func is_ready(quest_id: StringName) -> bool:
	return _active.has(quest_id) and bool(_active[quest_id]["ready"])

## Legacy single-objective progress (objective 0), kept for the contract board.
func get_progress(quest_id: StringName) -> int:
	if _active.has(quest_id):
		var p: Array = _active[quest_id]["progress"]
		return int(p[0]) if not p.is_empty() else 0
	return 0

## Per-objective progress counts for a quest, as an Array[int].
func get_objective_progress(quest_id: StringName) -> Array:
	if _active.has(quest_id):
		return (_active[quest_id]["progress"] as Array).duplicate()
	return []

## Active quests as an Array of {quest: Quest, progress: Array[int], ready: bool}.
func get_active_quests() -> Array:
	var out: Array = []
	for quest_id in _active.keys():
		var entry: Dictionary = _active[quest_id]
		out.append({
			"quest": entry["quest"],
			"progress": (entry["progress"] as Array).duplicate(),
			"ready": bool(entry["ready"]),
		})
	return out

## Quests ready to be turned in to the given NPC giver id.
func get_turn_in_quests(giver_id: StringName) -> Array:
	var out: Array = []
	for quest_id in _active.keys():
		var entry: Dictionary = _active[quest_id]
		if bool(entry["ready"]) and (entry["quest"] as Quest).giver_id == giver_id:
			out.append(entry["quest"])
	return out

func get_completed_count() -> int:
	return _completed.size()

## --- Tracking ---------------------------------------------------------------

func set_tracked(quest_id: StringName) -> void:
	_tracked_id = quest_id
	tracked_changed.emit(get_tracked())

func get_tracked_id() -> StringName:
	return _tracked_id

func get_tracked() -> Quest:
	if _active.has(_tracked_id):
		return _active[_tracked_id]["quest"]
	return null

func _auto_track() -> void:
	set_tracked(_active.keys()[0] if not _active.is_empty() else &"")

## --- Objective tracking -----------------------------------------------------

func _on_enemy_killed(enemy_id: StringName, _xp_reward: int, _position: Vector2) -> void:
	for quest_id in _active.keys():
		_advance_kind(quest_id, QuestObjective.Kind.KILL, enemy_id, 1)

func _on_item_collected(item_id: StringName, count: int) -> void:
	for quest_id in _active.keys():
		_advance_kind(quest_id, QuestObjective.Kind.COLLECT, item_id, count)

## Advance STORY objectives matching `beat_id`. Called by narrative scripting.
func advance_story(beat_id: StringName, amount: int = 1) -> void:
	for quest_id in _active.keys():
		_advance_kind(quest_id, QuestObjective.Kind.STORY, beat_id, amount)

## Advance every matching objective of one quest, then check for completion.
func _advance_kind(quest_id: StringName, kind: int, target_id: StringName, amount: int) -> void:
	var entry: Dictionary = _active[quest_id]
	if bool(entry["ready"]):
		return
	var quest: Quest = entry["quest"]
	var objectives: Array = quest.get_objectives()
	var progress: Array = entry["progress"]
	var changed: bool = false
	for i in range(objectives.size()):
		var obj: QuestObjective = objectives[i]
		if obj.kind != kind:
			continue
		# KILL with an empty target matches any creature; otherwise the id must match.
		if kind == QuestObjective.Kind.KILL:
			if obj.target_id != &"" and obj.target_id != target_id:
				continue
		elif obj.target_id != target_id:
			continue
		if int(progress[i]) >= obj.required_count:
			continue
		progress[i] = mini(int(progress[i]) + amount, obj.required_count)
		changed = true
	if not changed:
		return
	quest_progressed.emit(quest)
	if _objectives_done(quest, progress):
		_reach_completion(quest, entry)

func _objectives_done(quest: Quest, progress: Array) -> bool:
	var objectives: Array = quest.get_objectives()
	for i in range(objectives.size()):
		if int(progress[i]) < (objectives[i] as QuestObjective).required_count:
			return false
	return true

func _reach_completion(quest: Quest, entry: Dictionary) -> void:
	if quest.requires_turn_in:
		entry["ready"] = true
		quest_ready.emit(quest)
	else:
		_complete(quest)

func _complete(quest: Quest) -> void:
	_active.erase(quest.id)
	if not quest.repeatable and not _completed.has(quest.id):
		_completed.append(quest.id)
	_grant_rewards(quest)
	quest_completed.emit(quest)
	if _tracked_id == quest.id:
		_auto_track()
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

func _zeros(n: int) -> Array:
	var out: Array = []
	out.resize(n)
	out.fill(0)
	return out

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
		active_data.append({
			"path": (entry["quest"] as Quest).resource_path,
			"progress": (entry["progress"] as Array).duplicate(),
			"ready": bool(entry["ready"]),
		})
	var completed_data: Array = []
	for cid in _completed:
		completed_data.append(String(cid))
	return {"active": active_data, "completed": completed_data, "tracked": String(_tracked_id)}

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
		if quest == null:
			continue
		var count: int = quest.get_objectives().size()
		var progress: Array = _zeros(count)
		var saved: Variant = entry.get("progress", null)
		if saved is Array:
			for i in range(mini((saved as Array).size(), count)):
				progress[i] = int((saved as Array)[i])
		elif saved != null and count > 0:
			progress[0] = int(saved)  # legacy single-int progress
		_active[quest.id] = {"quest": quest, "progress": progress, "ready": bool(entry.get("ready", false))}
	_tracked_id = StringName(data.get("tracked", ""))
	tracked_changed.emit(get_tracked())
