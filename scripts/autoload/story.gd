extends Node

## Autoload `Story`. Two jobs:
##  1. A bag of named flags + a coarse `stage` that other systems read to gate
##     dialogue, quests and events without referencing each other.
##  2. The main-questline DIRECTOR: it loads StoryChapter resources, starts the
##     current chapter's quest, and when that quest completes applies the
##     chapter's flags/rewards, shows a banner, and starts the next chapter.
##
## Story beats (STORY quest objectives) advance when world events fire `beat()` —
## visiting a location, entering the wilds, or an NPC dialogue topic. Implements
## the SaveManager "persistent" contract.

signal flag_changed(flag: StringName, value: Variant)
signal stage_changed(stage: int)
signal chapter_changed(chapter: StringName)

## Coarse acts. Finer beats live in flags/chapters.
enum Stage { PROLOGUE, SEARCHING, DEEPWOOD, AWAKENING }

const CHAPTERS_DIR := "res://resources/story/chapters/"
## Where the main line begins on a new game.
const FIRST_CHAPTER := &"ch1_first_lesson"

var _flags: Dictionary = {}
var stage: int = Stage.PROLOGUE
var _current_chapter: StringName = &""

## id -> StoryChapter
var _chapters: Dictionary = {}

func _ready() -> void:
	add_to_group("persistent")
	_load_chapters()
	# These autoloads are registered before Story (see project.godot order).
	QuestManager.quest_completed.connect(_on_quest_completed)
	WorldMap.location_discovered.connect(_on_location_discovered)
	TravelManager.area_entered.connect(_on_area_entered)

func _load_chapters() -> void:
	var dir := DirAccess.open(CHAPTERS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean: String = file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var chapter := load(CHAPTERS_DIR + clean) as StoryChapter
				if chapter != null and chapter.id != &"":
					_chapters[chapter.id] = chapter
		file_name = dir.get_next()
	dir.list_dir_end()

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

func get_current_chapter() -> StoryChapter:
	return _chapters.get(_current_chapter, null)

# --- Story beats ------------------------------------------------------------

## Fire a narrative beat: advance any matching STORY quest objective and record a
## flag so the moment is remembered. Called by world triggers and NPC topics.
func beat(beat_id: StringName) -> void:
	if beat_id == &"":
		return
	set_flag(StringName("beat_%s" % beat_id))
	QuestManager.advance_story(beat_id)

func _on_location_discovered(location_id: StringName) -> void:
	beat(StringName("visit_%s" % location_id))

func _on_area_entered(_biome_id: StringName) -> void:
	beat(&"enter_wilds")

# --- Chapter flow -----------------------------------------------------------

## Begin a fresh run: reset narrative state and start the first chapter.
func start_new_game() -> void:
	_flags.clear()
	_current_chapter = &""
	set_stage(Stage.PROLOGUE)
	start_chapter(FIRST_CHAPTER)

func start_chapter(chapter_id: StringName) -> void:
	var chapter: StoryChapter = _chapters.get(chapter_id, null)
	if chapter == null:
		return
	_current_chapter = chapter_id
	set_stage(chapter.stage)
	chapter_changed.emit(chapter_id)
	if chapter.quest_path != "" and ResourceLoader.exists(chapter.quest_path):
		var quest := load(chapter.quest_path) as Quest
		if quest != null:
			QuestManager.start_quest(quest)
	if chapter.intro_toast != "":
		UIManager.notify(chapter.title, chapter.intro_toast)

func _on_quest_completed(quest: Quest) -> void:
	var chapter: StoryChapter = get_current_chapter()
	if chapter == null or quest == null:
		return
	# Only advance when the CURRENT chapter's own quest finishes.
	if chapter.quest_path == "" or quest.resource_path != chapter.quest_path:
		return
	for flag in chapter.set_flags:
		set_flag(StringName(flag))
	if chapter.grant_skill_points > 0:
		_grant_skill_points(chapter.grant_skill_points)
	if chapter.completion_toast != "":
		UIManager.notify(chapter.title, chapter.completion_toast)
	if chapter.next_chapter != &"":
		start_chapter(chapter.next_chapter)
	else:
		_current_chapter = &""
		chapter_changed.emit(&"")

func _grant_skill_points(amount: int) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var stats := player.get_node_or_null("Stats") as Stats
	if stats != null:
		stats.skill_points += amount
		stats.skills_changed.emit()

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "story"

func save_state() -> Dictionary:
	var flags_out: Dictionary = {}
	for key: Variant in _flags.keys():
		flags_out[String(key)] = _flags[key]
	return {"flags": flags_out, "stage": stage, "chapter": String(_current_chapter)}

func load_state(data: Dictionary) -> void:
	_flags.clear()
	var flags_in: Dictionary = data.get("flags", {})
	for key: Variant in flags_in.keys():
		_flags[StringName(key)] = flags_in[key]
	stage = int(data.get("stage", Stage.PROLOGUE))
	_current_chapter = StringName(data.get("chapter", ""))
	stage_changed.emit(stage)
	chapter_changed.emit(_current_chapter)
