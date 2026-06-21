extends SceneTree

## Headless check for dialogue portraits:
##   1. Every authored NPC (resources/npcs/*.tres) has a baked bust — both the
##      neutral and the happy expression — at the convention path. A typo'd or
##      missing portrait is the silent-path failure this guards.
##   2. Dialogue.portrait_for resolves those by id, falls back happy -> neutral,
##      and returns null (gracefully) for an empty/unknown id.
##
## Run: godot --headless -s tools/validate_portraits.gd

const NPC_DIR := "res://resources/npcs/"
const PORTRAIT_DIR := "res://assets/placeholder/portraits/"

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

	# --- gather authored NPC ids --------------------------------------------
	var ids: Array = []
	var dir := DirAccess.open(NPC_DIR)
	if dir == null:
		_err("could not open %s" % NPC_DIR)
		_finish()
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean: String = file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var npc := load(NPC_DIR + clean) as NpcData
				if npc != null and npc.id != &"":
					ids.append(npc.id)
		file_name = dir.get_next()
	dir.list_dir_end()

	if ids.is_empty():
		_err("found no NPC resources to check")
		_finish()
		return

	# --- 1. Every NPC has a neutral + happy bust -----------------------------
	for id: StringName in ids:
		for suffix: String in ["", "_happy"]:
			var path: String = "%sportrait_%s%s.png" % [PORTRAIT_DIR, String(id), suffix]
			if ResourceLoader.exists(path):
				_ok("%s portrait%s exists" % [String(id), suffix])
			else:
				_err("missing %s (run python3 tools/gen_portraits.py)" % path)

	# --- 2. Dialogue.portrait_for resolves + falls back ----------------------
	var dlg = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	var first: StringName = ids[0]
	if dlg.portrait_for(first, false) != null and dlg.portrait_for(first, true) != null:
		_ok("portrait_for resolved '%s' (neutral + happy)" % String(first))
	else:
		_err("portrait_for did not resolve '%s'" % String(first))
	if dlg.portrait_for(&"") == null and dlg.portrait_for(&"no_such_npc_xyz") == null:
		_ok("portrait_for returns null for empty/unknown ids (graceful)")
	else:
		_err("portrait_for should return null for empty/unknown ids")
	dlg.free()

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - dialogue portraits baked + resolvable for every NPC")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
