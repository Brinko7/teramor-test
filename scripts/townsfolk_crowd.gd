extends Node2D

## Fills a scene with cosmetic pedestrians at startup — one node that spawns `count`
## Townsfolk at random stroll points, each with a random look (cycled from a sprite
## pool) and a slightly varied gait, so a town reads as a moving crowd without
## hand-placing every body. Drop one under a town's Entities and set the count.

const TOWNSFOLK := preload("res://scenes/entities/townsfolk.tscn")

# Remaster villager walk-sheets (84x120 frames, 4 dirs x 4 phases). A per-body
# tint + gait variation (below) keeps the small pool from reading as clones.
const _DEFAULT_LOOKS: Array[String] = [
	"res://assets/remaster/cast/villager_a.png",
	"res://assets/remaster/cast/villager_b.png",
	"res://assets/remaster/cast/villager_c.png",
]

@export var count: int = 8
## Markers the crowd strolls between (shared with the scene's scheduled NPCs).
@export var stroll_group: StringName = &"npc_waypoint"
## Sprite sheets the crowd is drawn from. Left empty, the placeholder townsfolk
## looks above are used.
@export var looks: Array[Texture2D] = []

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var pool: Array[Texture2D] = looks.duplicate()
	if pool.is_empty():
		for path in _DEFAULT_LOOKS:
			var tex := load(path) as Texture2D
			if tex != null:
				pool.append(tex)
	if pool.is_empty():
		return

	var points: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(stroll_group):
		if node is Node2D:
			points.append(node as Node2D)

	# Spawn the crowd into our parent (the scene's y-sorted Entities root) rather
	# than under this factory node, so each pedestrian depth-sorts against the
	# buildings and NPCs by its own feet instead of all sharing the spawner's Y.
	var host: Node = get_parent()
	if host == null:
		host = self

	for i in count:
		var folk := TOWNSFOLK.instantiate() as Townsfolk
		if folk == null:
			continue
		folk.stroll_group = stroll_group
		folk.sprite_texture = pool[i % pool.size()]
		folk.sprite_tint = _vary()
		folk.walk_speed = _rng.randf_range(24.0, 36.0)
		host.add_child(folk)
		if not points.is_empty():
			folk.place(points[_rng.randi_range(0, points.size() - 1)].global_position)

## A gentle per-body tint so the reused sheets don't read as clones — a small,
## desaturated drift around white that keeps everyone on the grounded palette.
func _vary() -> Color:
	var v: float = _rng.randf_range(0.85, 1.0)
	return Color(v, v, _rng.randf_range(0.82, 1.0) * v, 1.0)
