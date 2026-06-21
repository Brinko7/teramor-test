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
## Wooded biomes set this so CanopyFX drifts dappled overhead shade across the area
## (sunlight filtering through a thick canopy). Off for open ground (plains/desert)
## and underground (cave).
@export var has_canopy: bool = false

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

## Ambient lone-wanderer count range and prop population range. With encounters in
## play, min/max_enemies is the sparse handful of stray foes you stumble on between
## setpieces — keep it low (min may be 0) for semi-peaceful pacing; the designed
## beats come from `encounter_paths` below.
@export var min_enemies: int = 1
@export var max_enemies: int = 2
@export var min_props: int = 16
@export var max_props: int = 28

## Authored encounter setpieces (EncounterData .tres paths) this biome can stage,
## and how many to drop per area. Empty = ambient scatter only. See EncounterData
## and ProceduralArea._spawn_encounters.
@export var encounter_paths: PackedStringArray = PackedStringArray()
@export var min_encounters: int = 0
@export var max_encounters: int = 0

## Harvestable resource item paths (ore/stone/crystal/herbs) and how many gather
## nodes to scatter. Empty = no nodes (e.g. a road encounter).
@export var gather_paths: PackedStringArray = PackedStringArray()
@export var min_gather: int = 0
@export var max_gather: int = 0

## Passive wildlife (deer/rabbit) scene paths and how many to scatter. These are
## the WILDLIFE faction — peaceful prey the player can hunt for meat/hide. Unlike
## enemies they keep their authored loot and skip tier scaling (see
## ProceduralArea._spawn_wildlife). Empty = no wildlife.
@export var wildlife_paths: PackedStringArray = PackedStringArray()
@export var min_wildlife: int = 0
@export var max_wildlife: int = 0

## Flat ground-cover decal TEXTURE paths (gc_*.png — tufts/flowers/pebbles/leaves/
## moss/brush) strewn across the Decals layer to break the tiling repeat and dapple
## the floor with life. Weighted like enemy_paths; empty = bare ground. Density is
## min/max_groundcover scaled by the area's size (see ProceduralArea._scatter_groundcover).
@export var groundcover_paths: PackedStringArray = PackedStringArray()
@export var groundcover_weights: PackedFloat32Array = PackedFloat32Array()
@export var min_groundcover: int = 0
@export var max_groundcover: int = 0

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

## Weighted-random ground-cover texture path, skipping any that are missing.
## Returns "" if none are available.
func pick_groundcover_path(rng: RandomNumberGenerator) -> String:
	var available: Array = []
	var total: float = 0.0
	for i in range(groundcover_paths.size()):
		var path: String = groundcover_paths[i]
		if not ResourceLoader.exists(path):
			continue
		var weight: float = groundcover_weights[i] if i < groundcover_weights.size() else 1.0
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

## Uniform-random wildlife path, skipping any whose scene is missing. Returns "" if
## none are available.
func pick_wildlife_path(rng: RandomNumberGenerator) -> String:
	var available: Array = []
	for path in wildlife_paths:
		if ResourceLoader.exists(path):
			available.append(path)
	if available.is_empty():
		return ""
	return String(available[rng.randi() % available.size()])

## Weighted-random encounter valid at `tier`, skipping missing resources and any
## whose `min_tier` exceeds the area tier. Returns null if none qualify.
func pick_encounter(rng: RandomNumberGenerator, tier: int) -> EncounterData:
	var available: Array = []
	var total: float = 0.0
	for path in encounter_paths:
		if not ResourceLoader.exists(path):
			continue
		var enc := load(path) as EncounterData
		if enc == null or tier < enc.min_tier:
			continue
		available.append(enc)
		total += maxf(0.0, enc.weight)
	if available.is_empty() or total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	for enc: EncounterData in available:
		roll -= maxf(0.0, enc.weight)
		if roll <= 0.0:
			return enc
	return available[-1]
