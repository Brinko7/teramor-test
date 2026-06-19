extends Node

## Autoload `Story`. Owns global narrative state: a bag of named boolean/string
## flags plus a coarse story `stage`. Systems read flags to gate dialogue,
## quests, and events without holding references to one another. Implements the
## SaveManager "persistent" contract so the story survives save/load.
##
## The opening beat ("Zayn's father Elkar walked into the Deepwood and never came
## back") is seeded by `start_new_game()` when a fresh run enters the world.

signal flag_changed(flag: StringName, value: Variant)
signal stage_changed(stage: int)

## Coarse acts. Finer beats live in flags.
enum Stage { PROLOGUE, SEARCHING, DEEPWOOD, AWAKENING }

## The id of the main story quest seeded at the start of a run.
const MAIN_QUEST_PATH := "res://resources/quests/find_elkar.tres"

var _flags: Dictionary = {}
var stage: int = Stage.PROLOGUE

func _ready() -> void:
	add_to_group("persistent")

# --- Flags ------------------------------------------------------------------

func set_flag(flag: StringName, value: Variant = true) -> void:
	if _flags.get(flag) == value:
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)

func has_flag(flag: StringName) -> bool:
	return bool(_flags.get(flag, false))

func get_flag(flag: StringName, default: Variant = null) -> Variant:
	return _flags.get(flag, default)

func clear_flag(flag: StringName) -> void:
	if _flags.has(flag):
		_flags.erase(flag)
		flag_changed.emit(flag, false)

func set_stage(new_stage: int) -> void:
	if new_stage == stage:
		return
	stage = new_stage
	stage_changed.emit(stage)

# --- New-game seed ----------------------------------------------------------

## Seed the opening situation for a brand-new run. Called by GameManager when a
## freshly-created character enters the world. Idempotent within a run.
func start_new_game() -> void:
	_flags.clear()
	stage = Stage.PROLOGUE
	set_flag(&"father_missing", true)
	stage_changed.emit(stage)
	var quest := load(MAIN_QUEST_PATH) as Quest
	if quest != null:
		QuestManager.start_quest(quest)

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "story"

func save_state() -> Dictionary:
	var flags_out: Dictionary = {}
	for key: Variant in _flags.keys():
		flags_out[String(key)] = _flags[key]
	return {"flags": flags_out, "stage": stage}

func load_state(data: Dictionary) -> void:
	_flags.clear()
	var flags_in: Dictionary = data.get("flags", {})
	for key: Variant in flags_in.keys():
		_flags[StringName(key)] = flags_in[key]
	stage = int(data.get("stage", Stage.PROLOGUE))
	stage_changed.emit(stage)
