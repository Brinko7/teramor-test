extends SceneTree

## Headless check for the secret camp + recruitment slice (PR B of the opening):
##   1. The Children of Tera camp is a SECRET — not discovered by default.
##   2. A tavern contact (Sorrel) in Cleeve's Landing reveals the hidden trail.
##   3. Town carries a flag-gated journey zone (the hidden trail) to the camp, and
##      the open road to the camp stays sealed until the camp is discovered.
##   4. Elder Maelon recruits the player into the Children of Tera at the camp.
##   5. The chapter chain routes ch2 -> ch3_children (seek the camp) -> ch3_awakening,
##      and the seek quest completes on the `joined_children` beat.
##   6. Continue reloads the last location (SaveManager.peek + a camp scene_path).
##
## Pure text scans + resource loads (frame-0 safe).
##
## Run: godot --headless -s tools/validate_recruitment.gd

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _ok(m: String) -> void:
	print("  ok: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _topic_with(npc: NpcData, key: String, value: String) -> bool:
	if npc == null:
		return false
	for topic: Dictionary in npc.topics:
		if String(topic.get(key, "")) == value:
			return true
	return false

func _run() -> void:
	await process_frame
	await process_frame

	# --- 1. The camp is a secret -------------------------------------------
	var camp := load("res://resources/world/locations/settlement_camp.tres") as WorldLocation
	if camp != null and not camp.discovered_by_default:
		_ok("the camp is hidden (not discovered by default)")
	else:
		_err("settlement_camp must not be discovered_by_default")
	if camp != null and not camp.scene_path.is_empty():
		_ok("the camp has a scene_path (Continue can reload it)")
	else:
		_err("settlement_camp has no scene_path")

	# --- 2. Sorrel reveals the hidden trail --------------------------------
	var sorrel := load("res://resources/npcs/sorrel.tres") as NpcData
	if sorrel != null and sorrel.id == &"sorrel":
		_ok("Sorrel (the tavern contact) loads")
	else:
		_err("Sorrel NpcData failed to load")
	if _topic_with(sorrel, "set_flag", "trail_revealed"):
		_ok("Sorrel's topic reveals the trail (sets trail_revealed)")
	else:
		_err("Sorrel has no topic that sets trail_revealed")
	if ResourceLoader.exists("res://assets/placeholder/portraits/portrait_sorrel.png"):
		_ok("Sorrel has a baked portrait")
	else:
		_err("missing Sorrel portrait (run gen_portraits.py)")
	var tavern := FileAccess.get_file_as_string("res://scenes/world/tavern_interior.tscn")
	if tavern.contains("res://resources/npcs/sorrel.tres"):
		_ok("Sorrel is placed in the tavern")
	else:
		_err("Sorrel is not in the tavern scene")

	# --- 3. The hidden trail (gated) + the sealed road ---------------------
	var town := FileAccess.get_file_as_string("res://scenes/world/town.tscn")
	if town.contains("journey_to = &\"settlement_camp\"") and town.contains("require_flag = &\"trail_revealed\""):
		_ok("town carries a flag-gated journey trail to the camp")
	else:
		_err("town has no gated hidden-trail journey to the camp")
	var road := FileAccess.get_file_as_string("res://scenes/world/road.tscn")
	if road.contains("require_flag = &\"beat_visit_settlement_camp\""):
		_ok("the open road to the camp is sealed until discovery")
	else:
		_err("road's ExitToSettlement is not gated behind discovery")

	# --- 4. Maelon recruits at the camp ------------------------------------
	var maelon := load("res://resources/npcs/elder_maelon.tres") as NpcData
	if _topic_with(maelon, "story_beat", "joined_children") and _topic_with(maelon, "require_flag", "trail_revealed"):
		_ok("Elder Maelon recruits you into the Children of Tera")
	else:
		_err("Maelon has no gated recruitment topic firing joined_children")

	# --- 5. The chapter chain + seek quest ---------------------------------
	var ch2 := load("res://resources/story/chapters/ch2_missing_father.tres") as StoryChapter
	var ch3 := load("res://resources/story/chapters/ch3_children.tres") as StoryChapter
	if ch2 != null and ch2.next_chapter == &"ch3_children":
		_ok("ch2 routes into ch3_children")
	else:
		_err("ch2 does not route into ch3_children")
	if ch3 != null and ch3.next_chapter == &"ch3_awakening" and ch3.set_flags.has("joined_children_of_tera"):
		_ok("ch3_children seeks the camp then hands off to the awakening")
	else:
		_err("ch3_children is not wired correctly")
	var quest := load("res://resources/quests/q_seek_camp.tres") as Quest
	if quest != null and quest.target_id == &"joined_children":
		_ok("the seek quest completes on the joined_children beat")
	else:
		_err("q_seek_camp does not key off joined_children")

	# --- 6. Continue reloads the last location -----------------------------
	var sm = get_root().get_node_or_null("SaveManager")
	if sm != null and sm.has_method("peek"):
		_ok("SaveManager.peek exists (Continue reads the last location)")
	else:
		_err("SaveManager.peek is missing")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - the camp is a secret found by trekking, then earned by recruitment")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
