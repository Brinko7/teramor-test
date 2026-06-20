extends SceneTree

## Headless smoke test for the encounter-setpiece system. Run with:
##   godot --headless --path <project> -s res://tools/validate_encounters.gd
## Loads every EncounterData and biome, resolves every referenced scene, and
## exercises the tier-gated weighted picker. Focus-independent (no running game).

const ENCOUNTERS := [
	"res://resources/world/encounters/wolf_pack.tres",
	"res://resources/world/encounters/bear_family.tres",
	"res://resources/world/encounters/bandit_camp.tres",
]
const BIOMES := [
	"res://resources/world/biomes/roadside.tres",
	"res://resources/world/biomes/deepwood.tres",
	"res://resources/world/biomes/cursed_wilds.tres",
]

var _fail := 0

func _initialize() -> void:
	print("=== encounter validation ===")
	for path in ENCOUNTERS:
		_check_encounter(path)
	for path in BIOMES:
		_check_biome(path)
	if _fail == 0:
		print("\nRESULT: PASS — all encounters/biomes valid")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)

func _check_encounter(path: String) -> void:
	print("\n[encounter] " + path)
	if not ResourceLoader.exists(path):
		_err("resource missing")
		return
	var enc := load(path) as EncounterData
	if enc == null:
		_err("did not load as EncounterData (script not attached?)")
		return
	print("  id=%s  name=%s  min_tier=%d  weight=%.1f  loot_cache=%s" % [enc.id, enc.display_name, enc.min_tier, enc.weight, str(enc.loot_cache)])
	print("  enemies=%d (offsets=%d)  props=%d (offsets=%d)" % [enc.enemy_paths.size(), enc.enemy_offsets.size(), enc.prop_paths.size(), enc.prop_offsets.size()])
	if enc.enemy_paths.is_empty():
		_err("no enemies in encounter")
	for p in enc.enemy_paths:
		_check_scene(p, "enemy")
	for p in enc.prop_paths:
		_check_scene(p, "prop")

func _check_scene(path: String, kind: String) -> void:
	if not ResourceLoader.exists(path):
		_err("%s scene missing: %s" % [kind, path])
		return
	var scene := load(path) as PackedScene
	if scene == null:
		_err("%s did not load as PackedScene: %s" % [kind, path])
		return
	var inst := scene.instantiate()
	if inst == null:
		_err("%s failed to instantiate: %s" % [kind, path])
		return
	inst.free()

func _check_biome(path: String) -> void:
	print("\n[biome] " + path)
	var biome := load(path) as BiomeData
	if biome == null:
		_err("did not load as BiomeData")
		return
	print("  id=%s  ambient=%d..%d  encounters=%d..%d  paths=%d" % [biome.id, biome.min_enemies, biome.max_enemies, biome.min_encounters, biome.max_encounters, biome.encounter_paths.size()])
	if biome.max_encounters > 0 and biome.encounter_paths.is_empty():
		_err("budget set but no encounter_paths")
	# Exercise the picker across tiers; tally what it returns at the biome's tier.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var tally := {}
	for i in range(400):
		var enc := biome.pick_encounter(rng, biome.base_tier)
		if enc == null:
			continue
		if biome.base_tier < enc.min_tier:
			_err("picker returned %s below its min_tier at tier %d" % [enc.id, biome.base_tier])
		tally[enc.id] = int(tally.get(enc.id, 0)) + 1
	if not biome.encounter_paths.is_empty() and tally.is_empty():
		_err("picker never returned an encounter at base_tier %d" % biome.base_tier)
	print("  picker@tier%d -> %s" % [biome.base_tier, str(tally)])
