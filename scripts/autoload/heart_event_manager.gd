extends Node

## Autoload `HeartEventManager`. Plays authored relationship cutscenes (HeartEvent
## resources in resources/heart_events/) when an NPC's friendship crosses a
## threshold — the social→story payoff that bonds the player to the camp.
##
## It listens on `Relationships.hearts_changed`. The threshold is usually crossed
## *inside* a conversation (a gift, some small talk), so the event is queued and
## played once that conversation closes (via the dialogue's `finished` signal),
## never interrupting it. Rewards (a Story flag, a keepsake in the stash) apply the
## moment the event becomes eligible; the lines play when the stage is free.
##
## Implements the SaveManager "persistent" contract (which events have been seen).

const EVENTS_DIR := "res://resources/heart_events/"

var _events: Array = []        # all HeartEvent, load order
var _queue: Array = []         # eligible HeartEvent waiting to play
var _seen: Dictionary = {}     # event id (String) -> true

func _ready() -> void:
	add_to_group("persistent")
	_load_events()
	Relationships.hearts_changed.connect(_on_hearts_changed)
	UIManager.dialogue.finished.connect(_on_dialogue_finished)

func _load_events() -> void:
	var dir := DirAccess.open(EVENTS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean: String = file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var ev := load(EVENTS_DIR + clean) as HeartEvent
				if ev != null and ev.id != &"":
					_events.append(ev)
		file_name = dir.get_next()
	dir.list_dir_end()

func _on_hearts_changed(npc_id: StringName, hearts: int) -> void:
	for ev: HeartEvent in check_and_apply(npc_id, hearts):
		_queue.append(ev)
	_try_play()

## Mark + apply any events this NPC's heart count newly unlocks, returning them.
## Rewards (flag, keepsake) land here; the lines are queued separately. Split out
## from playback so it's testable without the dialogue UI.
func check_and_apply(npc_id: StringName, hearts: int) -> Array:
	var fired: Array = []
	for ev: HeartEvent in _events:
		if ev.npc_id != npc_id or hearts < ev.hearts or _seen.has(String(ev.id)):
			continue
		_seen[String(ev.id)] = true
		if ev.set_flag != &"":
			Story.set_flag(ev.set_flag)
		if ev.reward_item != "":
			var item := load(ev.reward_item) as Item
			if item != null:
				StorageManager.stash.add_item(item, maxi(1, ev.reward_count))
		fired.append(ev)
	return fired

func has_seen(event_id: StringName) -> bool:
	return _seen.has(String(event_id))

## Play the next queued event if the dialogue stage is free; otherwise wait for the
## current conversation to close.
func _try_play() -> void:
	if _queue.is_empty():
		return
	if UIManager.dialogue.is_active():
		return
	var ev: HeartEvent = _queue.pop_front()
	UIManager.dialogue.start(ev.lines, ev.speaker, UIManager.dialogue.portrait_for(ev.npc_id))

func _on_dialogue_finished() -> void:
	# A conversation (or a prior heart event) just ended — chain the next.
	_try_play.call_deferred()

# --- New game ---------------------------------------------------------------

func reset() -> void:
	_seen.clear()
	_queue.clear()

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "heart_events"

func save_state() -> Dictionary:
	return {"seen": _seen.keys()}

func load_state(data: Dictionary) -> void:
	_seen.clear()
	for id: Variant in data.get("seen", []):
		_seen[String(id)] = true
