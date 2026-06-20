extends SceneTree

## Headless check for authored relationship cutscenes (HeartEventManager):
##   1. An event fires only at/above its heart threshold, exactly once, and its
##      rewards (Story flag + a keepsake in the stash) apply.
##   2. The live Relationships.hearts_changed signal drives it end to end.
##   3. Seen-events survive a save/load round-trip.
##
## Run: godot --headless -s tools/validate_heart_events.gd

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _ok(m: String) -> void:
	print("  ok: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	var hearts = get_root().get_node_or_null("HeartEventManager")
	var rel = get_root().get_node_or_null("Relationships")
	var story = get_root().get_node_or_null("Story")
	var storage = get_root().get_node_or_null("StorageManager")
	if hearts == null or rel == null or story == null or storage == null:
		_err("a required autoload is missing")
		_finish()
		return

	# --- 1. Threshold + reward + one-shot (direct, no UI) -------------------
	hearts.reset()
	storage.reset()
	var herb := load("res://resources/items/herb.tres") as Item
	if hearts.check_and_apply(&"bram", 3).size() != 0:
		_err("event fired below its heart threshold")
	else:
		_ok("event withheld below threshold")
	var fired: Array = hearts.check_and_apply(&"bram", 4)
	if fired.size() == 1 and story.has_flag(&"bram_heart_4") and storage.stash.count_of(herb.id) >= 5:
		_ok("event fired at threshold; flag + keepsake applied")
	else:
		_err("event did not fire/apply at threshold (fired=%d, flag=%s, herb=%d)" % [fired.size(), story.has_flag(&"bram_heart_4"), storage.stash.count_of(herb.id)])
	if hearts.check_and_apply(&"bram", 5).is_empty():
		_ok("event is one-shot (does not re-fire)")
	else:
		_err("event fired more than once")

	# --- 2. Live signal path -----------------------------------------------
	hearts.reset()
	storage.reset()
	rel.meet(&"wrenna", "Wrenna")
	rel.add_points(&"wrenna", 400)  # 0 -> 4 hearts, emits hearts_changed
	await process_frame
	if hearts.has_seen(&"wrenna_4") and story.has_flag(&"wrenna_heart_4"):
		_ok("Relationships.hearts_changed drove the event end to end")
	else:
		_err("live signal did not trigger the heart event")

	# --- 3. Persistence round-trip -----------------------------------------
	hearts.reset()
	hearts.check_and_apply(&"bram", 4)
	var snap: Dictionary = hearts.save_state()
	hearts.reset()
	if hearts.has_seen(&"bram_4"):
		_err("reset did not clear seen events")
	hearts.load_state(snap)
	if hearts.has_seen(&"bram_4"):
		_ok("seen events survived a save/load round-trip")
	else:
		_err("save/load did not restore seen events")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - heart events fire once at threshold, reward, and persist")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
