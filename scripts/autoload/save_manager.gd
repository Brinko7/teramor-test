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

const GROUP := "persistent"
const SAVE_PATH := "user://teramor_save.json"

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

func save_all() -> void:
	var data: Dictionary = {}
	for node in get_tree().get_nodes_in_group(GROUP):
		if node.has_method("get_save_id") and node.has_method("save_state"):
			data[node.call("get_save_id")] = node.call("save_state")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open save file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))
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
	var data: Dictionary = parsed
	for node in get_tree().get_nodes_in_group(GROUP):
		if node.has_method("get_save_id") and node.has_method("load_state"):
			var id: String = node.call("get_save_id")
			if data.has(id):
				node.call("load_state", data[id])
