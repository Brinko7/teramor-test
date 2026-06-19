extends Node

## Autoload `TravelManager`. Owns moving between named locations and wandering
## into procedurally-generated wild areas.
##
## Fast travel (from the map) rolls a danger-based encounter chance: on a hit the
## player is dropped into a generated ambush keyed to the route's biome and tier,
## and only reaches the destination by crossing to the far exit (fight or flee) —
## Baldur's-Gate style. Otherwise they arrive directly.
##
## Wild excursions (an ExploreZone in a town) drop the player into a generated
## area they can push deeper into (each step a higher tier) or retreat from.
##
## ProceduralArea reads the staged request via consume_pending() when it loads.

const PROCEDURAL_SCENE := "res://scenes/world/procedural_area.tscn"

## Emitted when the player drops into a generated wild area (encounter or
## excursion). The Story director listens to fire the "enter the wilds" beat.
signal area_entered(biome_id: StringName)

## Staged area request, consumed by the next ProceduralArea to load. Shape:
##   { biome: BiomeData, tier: int, return_to: StringName, explore: bool }
var _pending: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

# --- Fast travel ------------------------------------------------------------

## Travel to a discovered location, possibly via a random encounter.
func fast_travel(destination_id: StringName) -> void:
	var dest := WorldMap.get_location(destination_id)
	if dest == null or not WorldMap.is_discovered(destination_id):
		return
	var biome := _load_biome(dest.travel_biome_path)
	if biome != null and _rng.randf() < _encounter_chance(dest.tier):
		_stage(biome, dest.tier, destination_id, false)
	else:
		arrive(destination_id)

## Odds of being intercepted en route, climbing with the destination's tier.
func _encounter_chance(tier: int) -> float:
	return clampf(0.18 * float(tier), 0.0, 0.75)

# --- Wild excursions --------------------------------------------------------

## Enter a generated wild area of `biome` at `tier`; its exits return the player
## to `return_to` (or push deeper, one tier up).
func enter_area(biome: BiomeData, tier: int, return_to: StringName, explore: bool = true) -> void:
	if biome == null:
		return
	_stage(biome, tier, return_to, explore)

# --- Arrival ----------------------------------------------------------------

## Land at a named location: discover it, mark it current, and travel there.
func arrive(location_id: StringName) -> void:
	var loc := WorldMap.get_location(location_id)
	if loc == null:
		return
	_pending.clear()
	WorldMap.discover(location_id)
	WorldMap.set_current(location_id)
	SceneManager.travel(loc.scene_path, loc.spawn_point)

# --- Staging ----------------------------------------------------------------

func _stage(biome: BiomeData, tier: int, return_to: StringName, explore: bool) -> void:
	_pending = {"biome": biome, "tier": maxi(1, tier), "return_to": return_to, "explore": explore}
	WorldMap.set_current(&"")  # in the wilds, not at any named place
	area_entered.emit(biome.id)
	SceneManager.travel(PROCEDURAL_SCENE, "arrive")

## Hand the staged request to a loading ProceduralArea (and clear it).
func consume_pending() -> Dictionary:
	var p := _pending.duplicate()
	_pending.clear()
	return p

func _load_biome(path: String) -> BiomeData:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as BiomeData
