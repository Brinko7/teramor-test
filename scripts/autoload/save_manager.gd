extends Node

## Autoload `SaveManager`. Generic, group-driven persistence.
##
## Any node that wants to be saved joins the "persistent" group in its _ready()
## and implements three methods:
##   func get_save_id() -> String           # globally unique, stable key
##   func save_state() -> Dictionary         # JSON-serializable snapshot
##   func load_state(data: Dictionary) -> void
##
## SaveManager walks the group, collects each node's snapshot keyed by its id,
## and writes one JSON file. Loading reverses it. Because it is fully generic,
## new systems become persistent just by implementing the contract — this file
## never needs to change.
##
## The file is wrapped in a small envelope carrying a format `version`, so the
## on-disk schema can evolve. `load_all()` runs the snapshot dictionary through
## `_migrate()` before handing it to nodes; add a step there whenever the shape of
## any saved state changes. Pre-versioning files (a bare id->state dictionary with
## no "version" key) are read as version 0 and migrated forward.

const GROUP := "persistent"
const SAVE_PATH := "user://teramor_save.json"

## Current on-disk save format. Bump this whenever a migration step is added.
const SAVE_VERSION := 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		save_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		load_all()
		get_viewport().set_input_as_handled()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Read one entry's saved state without applying it to the tree — lets a caller
## peek at where the player was (e.g. WorldMap's current location) before deciding
## which scene to load on Continue. Returns {} when absent or malformed.
func peek(save_id: String) -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var entries: Dictionary = _migrate(parsed)
	var entry: Variant = entries.get(save_id, {})
	return entry if typeof(entry) == TYPE_DICTIONARY else {}

func save_all() -> void:
	var entries: Dictionary = {}
	for node in get_tree().get_nodes_in_group(GROUP):
		if node.has_method("get_save_id") and node.has_method("save_state"):
			entries[node.call("get_save_id")] = node.call("save_state")
	var payload: Dictionary = {"version": SAVE_VERSION, "entries": entries}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open save file for writing")
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func load_all() -> void:
	if not has_save():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save file is malformed")
		return
	var entries: Dictionary = _migrate(parsed)
	for node in get_tree().get_nodes_in_group(GROUP):
		if node.has_method("get_save_id") and node.has_method("load_state"):
			var id: String = node.call("get_save_id")
			if entries.has(id):
				node.call("load_state", entries[id])

## In-memory snapshot of every persistent node at-or-under `root`, keyed by
## save id. Used to carry the player across a `change_scene_to_file` swap, which
## rebuilds the player from authored defaults — without this, every area
## transition would reset gear, stats and inventory. Reuses the exact same
## get_save_id/save_state contract as the on-disk path.
func capture_subtree(root: Node) -> Dictionary:
	var entries: Dictionary = {}
	for node in _persistent_in_subtree(root):
		if node.has_method("get_save_id") and node.has_method("save_state"):
			entries[node.call("get_save_id")] = node.call("save_state")
	return entries

## Re-applies a `capture_subtree` snapshot onto the (freshly built) subtree at
## `root`. Descendants load before `root` itself: the player node recomputes its
## max-HP from its Stats/Equipment children, so those must be restored first.
func apply_subtree(root: Node, entries: Dictionary) -> void:
	if entries.is_empty():
		return
	var nodes: Array = _persistent_in_subtree(root)
	nodes.reverse()  # pre-order visits root first, so reversed puts root last
	for node in nodes:
		if node.has_method("get_save_id") and node.has_method("load_state"):
			var id: String = node.call("get_save_id")
			if entries.has(id):
				node.call("load_state", entries[id])

## Pre-order walk collecting nodes in the "persistent" group at-or-under `root`.
func _persistent_in_subtree(root: Node) -> Array:
	var acc: Array = []
	_gather_persistent(root, acc)
	return acc

func _gather_persistent(node: Node, acc: Array) -> void:
	if node.is_in_group(GROUP):
		acc.append(node)
	for child in node.get_children():
		_gather_persistent(child, acc)

## Returns the id->state snapshot dictionary, upgrading older formats to the
## current schema first. Pre-versioning files are a bare snapshot with no
## "version" key (version 0); versioned files wrap it under "entries".
func _migrate(parsed: Dictionary) -> Dictionary:
	var version: int = int(parsed.get("version", 0))
	var entries: Dictionary = parsed.get("entries", parsed) if version > 0 else parsed
	# Future per-version migrations go here, e.g.:
	#   if version < 2: entries = _migrate_v1_to_v2(entries)
	if version > SAVE_VERSION:
		push_warning("SaveManager: save is newer (v%d) than this build (v%d)" % [version, SAVE_VERSION])
	return entries
