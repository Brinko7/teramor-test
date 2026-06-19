extends Node

## Autoload `Skills`. Catalog of every SkillNode in the game, loaded from
## res://resources/skills/ at startup. Pure lookup — character progression state
## (which nodes are learned, spent attributes, points) lives on the player's
## Stats component; this just answers "what nodes exist and what do they do".

const SKILLS_DIR := "res://resources/skills/"

## id -> SkillNode
var _nodes: Dictionary = {}
## Insertion order, for stable display.
var _order: Array[StringName] = []

func _ready() -> void:
	_load_nodes()

func _load_nodes() -> void:
	var dir := DirAccess.open(SKILLS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean: String = file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var node := load(SKILLS_DIR + clean) as SkillNode
				if node != null and node.id != &"":
					_nodes[node.id] = node
					_order.append(node.id)
		file_name = dir.get_next()
	dir.list_dir_end()

func get_node_data(node_id: StringName) -> SkillNode:
	return _nodes.get(node_id, null)

func all_nodes() -> Array:
	var out: Array = []
	for id in _order:
		out.append(_nodes[id])
	return out

func nodes_in_branch(branch: int) -> Array:
	var out: Array = []
	for id in _order:
		var node: SkillNode = _nodes[id]
		if node.branch == branch:
			out.append(node)
	return out
