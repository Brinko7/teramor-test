extends SceneTree

## Content lint — the safety net for the "content is data" bet. Walks every authored
## resource under res://resources/, loads it, and:
##   * fails on any resource that won't load (a broken/typo'd .tres);
##   * fails on any res:// path a resource points at that doesn't exist — the silent
##     killer, since BiomeData.pick_* just skips missing scenes, so a typo'd
##     enemy/loot/biome path no-ops in-game with no error;
##   * fails on duplicate `id` within a resource class.
##
## Generic by reflection (no per-type code), so it covers items, biomes, locations,
## encounters, quests, recipes, crops, skills, abilities, npcs, story chapters — and
## any resource type added later, for free.
##
## Run: godot --headless -s tools/validate_content.gd

const ROOT := "res://resources/"
## Extensions we treat as "this string is a resource path that must resolve".
const RES_EXTS := ["tscn", "tres", "res", "png", "gdshader", "ogg", "wav", "svg", "webp"]

var _fail := 0
var _checked_files := 0
var _checked_paths := 0
## class_name -> { id -> file } for duplicate-id detection.
var _ids: Dictionary = {}

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	_walk(ROOT)
	if _fail == 0:
		print("RESULT: PASS - content lint: %d resources, %d resource paths, all resolve" % [_checked_files, _checked_paths])
	else:
		print("RESULT: FAIL - %d content problem(s) across %d resources" % [_fail, _checked_files])
	quit()

func _walk(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path + name
		if dir.current_is_dir():
			_walk(full + "/")
		else:
			var clean := name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				_check_resource(dir_path + clean)
		name = dir.get_next()
	dir.list_dir_end()

func _check_resource(path: String) -> void:
	_checked_files += 1
	var res = load(path)
	if res == null:
		_err("resource failed to load: %s" % path)
		return

	# Duplicate-id guard, scoped per resource class so e.g. two different types may
	# share an id but two items may not.
	var cls := _class_of(res)
	if "id" in res:
		var id = res.get("id")
		if id != null and String(id) != "":
			var bucket: Dictionary = _ids.get(cls, {})
			if bucket.has(id):
				_err("duplicate %s id '%s' (%s and %s)" % [cls, id, bucket[id], path])
			else:
				bucket[id] = path
				_ids[cls] = bucket

	# Every stored String / StringName / PackedStringArray that looks like a res://
	# path must resolve.
	for prop in res.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var t := int(prop["type"])
		var value = res.get(prop["name"])
		if t == TYPE_STRING or t == TYPE_STRING_NAME:
			_check_path_string(String(value), path, String(prop["name"]))
		elif t == TYPE_PACKED_STRING_ARRAY:
			for s in (value as PackedStringArray):
				_check_path_string(String(s), path, String(prop["name"]))

func _check_path_string(s: String, owner: String, field: String) -> void:
	if not s.begins_with("res://"):
		return
	var ext := s.get_extension()
	if not (ext in RES_EXTS):
		return
	_checked_paths += 1
	if not (ResourceLoader.exists(s) or FileAccess.file_exists(s)):
		_err("%s.%s points at missing resource: %s" % [owner.get_file(), field, s])

func _class_of(res: Object) -> String:
	var scr = res.get_script()
	if scr != null and scr.resource_path != "":
		return scr.resource_path.get_file().trim_suffix(".gd")
	return res.get_class()
