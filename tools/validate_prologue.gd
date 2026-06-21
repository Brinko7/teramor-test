extends SceneTree

## Headless check for the opening (the Elkar prologue):
##   1. A new game opens on the prologue, not the camp (GameManager.PROLOGUE).
##   2. The prologue scene carries the player, the two practice foes, Elkar, and an
##      onward exit to Cleeve's Landing (the wilds' edge, his last lesson).
##   3. Elkar resolves as an NPC with a baked portrait.
##   4. The lesson is chapter 1's quest — defeat 2 foes — wiring the ch1 -> ch2 beat.
##
## Pure text scan + resource loads (frame-0 safe).
##
## Run: godot --headless -s tools/validate_prologue.gd

const SCENE := "res://scenes/world/prologue.tscn"

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

	var text := FileAccess.get_file_as_string(SCENE)
	if text.is_empty():
		_err("cannot read %s" % SCENE)
		_finish()
		return

	# --- 2. Scene carries the opening cast ----------------------------------
	if text.contains("res://scenes/entities/player.tscn"):
		_ok("prologue places the player")
	else:
		_err("prologue has no player")
	var wolves: int = text.count("node name=\"Wolf")
	if text.contains("res://scenes/entities/enemy_wolf.tscn") and wolves >= 2:
		_ok("prologue stages the two practice foes (%d wolves)" % wolves)
	else:
		_err("prologue needs 2 practice foes for the lesson (found %d)" % wolves)
	if text.contains("res://resources/npcs/elkar.tres"):
		_ok("Elkar is present in the prologue")
	else:
		_err("Elkar is not in the prologue")
	if text.contains("res://scenes/world/town.tscn") and text.contains("from_road"):
		_ok("an exit leads onward to Cleeve's Landing")
	else:
		_err("prologue has no onward exit to Cleeve's Landing")

	# --- 3. Elkar resolves + has a portrait ---------------------------------
	var elkar := load("res://resources/npcs/elkar.tres") as NpcData
	if elkar != null and elkar.id == &"elkar":
		_ok("Elkar NpcData loads (id=elkar)")
	else:
		_err("Elkar NpcData failed to load / wrong id")
	for suffix: String in ["", "_happy"]:
		var p: String = "res://assets/placeholder/portraits/portrait_elkar%s.png" % suffix
		if ResourceLoader.exists(p):
			_ok("Elkar portrait%s exists" % suffix)
		else:
			_err("missing %s (run python3 tools/gen_portraits.py)" % p)

	# --- 1. A new game opens on the prologue --------------------------------
	var gm = get_root().get_node_or_null("GameManager")
	if gm != null and gm.PROLOGUE == SCENE and ResourceLoader.exists(SCENE):
		_ok("a new game opens on the prologue")
	else:
		_err("GameManager.PROLOGUE does not point at the prologue scene")

	# --- 4. The lesson is ch1's quest: defeat 2 -----------------------------
	var ch1 := load("res://resources/story/chapters/ch1_first_lesson.tres") as StoryChapter
	if ch1 == null:
		_err("ch1_first_lesson failed to load")
	else:
		var q := load(ch1.quest_path) as Quest
		if q != null and q.required_count == 2:
			_ok("the lesson quest is 'defeat 2 foes' (ch1 -> ch2 beat)")
		else:
			_err("ch1's quest is not the defeat-2 lesson")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - the Elkar prologue opens the game and teaches the lesson")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
