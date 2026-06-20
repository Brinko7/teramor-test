extends Node
## Autoload `SceneManager`. Handles fade transitions between scenes and
## repositioning the player onto a named spawn Marker2D in the new scene.
##
## Register in Project Settings > Autoload as `SceneManager` ->
## res://scripts/autoload/scene_manager.gd

## Default spawn marker name searched for when none is supplied.
const DEFAULT_SPAWN := "spawn"
const FADE_TIME := 0.25

var _layer: CanvasLayer
var _fade: ColorRect
var _busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)

## Fade the screen to opaque black. The overlay lives on an always-processing
## CanvasLayer, so this works even while the tree is paused (e.g. mid-sleep).
func fade_to_black() -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await t.finished

## Fade the black overlay back to transparent.
func fade_from_black() -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await t.finished

## Fade out, swap scenes, place the player on `spawn_point`, fade back in.
func travel(target_scene: String, spawn_point: String = "") -> void:
	if _busy:
		return
	if target_scene.is_empty() or not ResourceLoader.exists(target_scene):
		push_warning("SceneManager.travel: missing scene '%s'" % target_scene)
		return
	_busy = true

	await fade_to_black()

	# Carry the player's gear/stats/inventory across the swap. change_scene_to_file
	# frees the old player and builds a fresh one from authored defaults, so without
	# this every transition would reset equipment and leveling. Captured while the
	# old player is still alive; position is re-set by _place_player below.
	var carried := _capture_player()

	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		push_warning("SceneManager.travel: change_scene failed (%d)" % err)
	# Let the new scene enter the tree.
	await get_tree().process_frame
	await get_tree().process_frame

	_restore_player(carried)
	_place_player(spawn_point)

	await fade_from_black()
	_busy = false

## Snapshots the current player subtree's persistent state before a scene swap.
func _capture_player() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return {}
	return SaveManager.capture_subtree(player)

## Re-applies a captured player snapshot onto the freshly built player.
func _restore_player(carried: Dictionary) -> void:
	if carried.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	SaveManager.apply_subtree(player, carried)

func _place_player(spawn_point: String) -> void:
	var tree := get_tree()
	var player := tree.get_first_node_in_group("player")
	if player == null:
		return
	var marker := _find_spawn(spawn_point)
	if marker != null:
		player.global_position = marker.global_position

func _find_spawn(spawn_point: String) -> Node2D:
	var tree := get_tree()
	var root := tree.current_scene
	if root == null:
		return null

	var wanted := spawn_point if not spawn_point.is_empty() else DEFAULT_SPAWN

	# 1) Exact named Marker2D anywhere in the scene.
	var named := _find_marker_by_name(root, wanted)
	if named != null:
		return named

	# 2) Any node in the "spawn" group (prefer one whose name matches).
	var group_nodes := tree.get_nodes_in_group("spawn")
	for n in group_nodes:
		if n is Node2D and n.name == wanted:
			return n
	for n in group_nodes:
		if n is Node2D:
			return n

	# 3) Fallback: first Marker2D found anywhere.
	return _find_any_marker(root)

func _find_marker_by_name(node: Node, wanted: String) -> Node2D:
	if node is Marker2D and node.name == wanted:
		return node as Node2D
	for child in node.get_children():
		var found := _find_marker_by_name(child, wanted)
		if found != null:
			return found
	return null

func _find_any_marker(node: Node) -> Node2D:
	if node is Marker2D:
		return node as Node2D
	for child in node.get_children():
		var found := _find_any_marker(child)
		if found != null:
			return found
	return null
