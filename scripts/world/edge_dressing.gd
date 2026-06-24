extends RefCounted
class_name EdgeDressing

## Frames an outdoor scene with a perimeter tree-line — a band of trees along the
## top and side edges (the bottom is left open for the entrance road), planted into
## the y-sorted Entities layer so the player passes in front of the near trunks and
## behind the far ones. This is the cheap substitute for the depth a top-down view
## with no sky can't otherwise show: the wall of forest reads as "the woods go on".
##
## Reusable by the towns (town_terrain.gd) and the LocationScene scaffolds; gate it
## to wooded regions so deserts and plains don't sprout an incongruous forest.

const TREES: Array[PackedScene] = [
	preload("res://scenes/entities/props/tree.tscn"),
]

## host: a y-sorted Entities node. avoid: world points (building feet) to keep clear.
static func plant_treeline(host: Node2D, map_size: Vector2i, seed: int, avoid: Array,
		avoid_r: float = 150.0, band: float = 170.0, spacing: float = 116.0) -> void:
	if host == null or TREES.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var w := float(map_size.x)
	var h := float(map_size.y)
	var edge := 40.0
	var spots: Array[Vector2] = []
	# Top edge — the densest line (the backdrop you read against).
	var x := edge
	while x < w - edge:
		spots.append(Vector2(x + rng.randf_range(-22.0, 22.0), rng.randf_range(edge, band)))
		x += spacing * rng.randf_range(0.7, 1.1)
	# Left + right edges — thinner, only down the upper two-thirds.
	var y := band
	while y < h * 0.66:
		spots.append(Vector2(rng.randf_range(edge, band), y + rng.randf_range(-20.0, 20.0)))
		spots.append(Vector2(w - rng.randf_range(edge, band), y + rng.randf_range(-20.0, 20.0)))
		y += spacing * rng.randf_range(0.8, 1.2)
	for p in spots:
		var skip := false
		for a: Vector2 in avoid:
			if p.distance_to(a) < avoid_r:
				skip = true
				break
		if skip:
			continue
		var tree := TREES[rng.randi() % TREES.size()].instantiate()
		if tree.get("choppable") != null:
			tree.set("choppable", false)        # the frame can't be felled (matches the procedural border)
		if tree is Node2D:
			(tree as Node2D).position = p
		host.add_child(tree)
