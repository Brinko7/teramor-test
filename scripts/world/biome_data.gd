extends Resource
class_name BiomeData

## Authorable description of a procedurally-generated area's flavour: what the
## ground looks like, which creatures roam it, what decor dots it, and what loot
## drops. One BiomeData drives any number of generated areas at any difficulty
## tier (see ProceduralArea). Scenes/items are referenced by path (rather than
## PackedScene/Resource) so these .tres files stay trivial to author by hand.

@export var id: StringName = &""
@export var display_name: String = "Wilds"

## Tiled ground sprite, tinted by `ground_tint` so biomes read distinctly even
## while sharing one placeholder texture.
@export var ground_texture_path: String = "res://assets/placeholder/grass.png"
@export var ground_tint: Color = Color.WHITE

## Enemy scene paths and matching relative spawn weights (parallel arrays; a
## missing/short weights array means uniform odds).
@export var enemy_paths: PackedStringArray = PackedStringArray()
@export var enemy_weights: PackedFloat32Array = PackedFloat32Array()

## Decorative/obstacle prop scene paths scattered across the area, plus a denser
## prop used to line the borders (typically a tree).
@export var prop_paths: PackedStringArray = PackedStringArray()
@export var border_path: String = "res://scenes/entities/props/tree.tscn"

## Item paths that generated enemies may drop.
@export var loot_paths: PackedStringArray = PackedStringArray()

## Baseline difficulty if a generator does not override the tier.
@export var base_tier: int = 1

## Enemy and prop population ranges (before tier scaling of enemy count).
@export var min_enemies: int = 2
@export var max_enemies: int = 4
@export var min_props: int = 16
@export var max_props: int = 28

## Harvestable resource item paths (ore/stone/crystal/herbs) and how many gather
## nodes to scatter. Empty = no nodes (e.g. a road encounter).
@export var gather_paths: PackedStringArray = PackedStringArray()
@export var min_gather: int = 0
@export var max_gather: int = 0

## Weighted random enemy path, skipping any whose scene is missing. Returns "" if
## none are available.
func pick_enemy_path(rng: RandomNumberGenerator) -> String:
	var available: Array = []
	var total: float = 0.0
	for i in range(enemy_paths.size()):
		var path: String = enemy_paths[i]
		if not ResourceLoader.exists(path):
			continue
		var weight: float = enemy_weights[i] if i < enemy_weights.size() else 1.0
		available.append({"path": path, "weight": weight})
		total += weight
	if available.is_empty() or total <= 0.0:
		return ""
	var roll: float = rng.randf() * total
	for entry: Dictionary in available:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return String(entry["path"])
	return String(available[-1]["path"])
