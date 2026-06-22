extends SceneTree

## Headless smoke test for the VAST procedural-area generator (task #26). Run with:
##   godot --headless --path <project> -s res://tools/validate_area.gd
## Drives the generator's pure generation pass OFF-TREE (no _ready, no autoloads,
## no HUD) on a seeded RNG, then asserts the new structure: a decal trail, RNG
## interior features inside bounds, four-sided framing, keep-out-aware scatter, the
## meander pinned at both mouths, and density scaling. Focus-independent.

const GEN := "res://scripts/world/procedural_area.gd"
const BIOMES := [
	"res://resources/world/biomes/deepwood.tres",
	"res://resources/world/biomes/roadside.tres",
	"res://resources/world/biomes/cursed_wilds.tres",
]
const EDGE := 24

var _fail := 0

func _initialize() -> void:
	# Defer + await: loading procedural_area.gd (which references the UIManager
	# autoload) at frame 0 hits "Identifier not found: UIManager" because autoload
	# globals aren't registered yet. A few frames in, the compile resolves.
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	await process_frame
	print("=== vast-area validation ===")
	var gen: GDScript = load(GEN)
	if gen == null:
		_err("procedural_area.gd failed to load (parse error?)")
		quit(1)
		return
	_check_signpost()
	for path in BIOMES:
		for seed_i in [1, 7, 99]:
			_run_case(gen, path, int(seed_i), seed_i == 1)
	if _fail == 0:
		print("\nRESULT: PASS — vast areas generate cleanly")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)

## Identify a signpost by script path rather than `is Signpost`: referencing the
## class_name forces signpost.gd (which uses the UIManager autoload) to compile at
## this validator's frame-0 parse time, before autoload globals register, which
## poisons every signpost instance in headless. Path-matching keeps the compile lazy.
func _is_signpost(node: Node) -> bool:
	var s = node.get_script()
	return s != null and s.resource_path.ends_with("signpost.gd")

## Check the signpost interact contract: a post carved with text becomes a readable
## interactable, a blank post stays plain scenery. (Signposts show NO floating label
## any more — you walk up and press interact to read the line in the dialogue box.)
## Drives _ready() directly, so this is deterministic.
func _check_signpost() -> void:
	print("\n[signpost] interact contract")
	var scene := load("res://scenes/entities/props/signpost.tscn") as PackedScene
	if scene == null:
		_err("signpost.tscn missing")
		return
	var post := scene.instantiate()
	post.set("text", "Danger ahead")
	post.call("_ready")
	if not post.is_in_group("interactable"):
		_err("a carved signpost should join the 'interactable' group")
	if not post.has_method("interact"):
		_err("a signpost should expose interact()")
	post.free()
	var plain := scene.instantiate()
	plain.call("_ready")
	if plain.is_in_group("interactable"):
		_err("a blank signpost should stay plain scenery, not interactable")
	plain.free()

func _run_case(gen: GDScript, biome_path: String, seed_v: int, verbose: bool) -> void:
	var biome := load(biome_path) as BiomeData
	if biome == null:
		_err("biome did not load: " + biome_path)
		return

	var area := Node2D.new()
	area.set_script(gen)
	var ground := Sprite2D.new()
	ground.name = "Ground"
	area.add_child(ground)
	var entities := Node2D.new()
	entities.name = "Entities"
	area.add_child(entities)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	area.set("_rng", rng)
	area.set("_ground", ground)
	area.set("_entities", entities)
	area.set("_biome", biome)
	area.set("_tier", biome.base_tier)
	area.set("_explore", true)

	var w: int = area.get("world_width")
	var h: int = area.get("world_height")
	area.set("_density", clampf(float(w * h) / 288000.0, 1.0, 4.5))

	# Drive the off-tree generation pass (everything that doesn't touch get_tree()).
	area.call("_setup_decals")
	area.call("_setup_trail")
	area.call("_paint_ground")
	area.call("_paint_trail")
	area.call("_place_features")
	var decals: Node2D = area.get("_decals")
	var trail_n: int = decals.get_child_count() if decals != null else 0
	area.call("_scatter_groundcover")
	var cover_n: int = (decals.get_child_count() - trail_n) if decals != null else 0
	area.call("_frame_border")
	area.call("_scatter_props")
	area.call("_place_signage")

	var features: Array = area.get("_features")
	var tag := "%s/seed%d" % [biome.id, seed_v]

	# 1. dimensions are the vast target.
	if w < 1200 or h < 900:
		_err("%s: area not vast (%dx%d)" % [tag, w, h])

	# 2. trail decals laid as a ribbon.
	if trail_n < 80:
		_err("%s: too few trail decals (%d)" % [tag, trail_n])

	# 2b. ground-cover decals strewn to break the tiling repeat (these biomes all
	# author groundcover; the pass scales the count by density and caps it).
	if biome.groundcover_paths.size() > 0 and biome.max_groundcover > 0:
		if cover_n < 20:
			_err("%s: too little ground-cover scatter (%d decals)" % [tag, cover_n])

	# 3. trail pinned to mid-height at both mouths.
	var mid := float(h) * 0.5
	var y_left: float = area.call("_trail_y", float(EDGE))
	var y_right: float = area.call("_trail_y", float(w - EDGE))
	if absf(y_left - mid) > 30.0 or absf(y_right - mid) > 30.0:
		_err("%s: trail not pinned at mouths (L=%.0f R=%.0f mid=%.0f)" % [tag, y_left, y_right, mid])

	# 4. features placed, inside the interior, non-trivial.
	if features.is_empty():
		_err("%s: no interior features placed" % tag)
	for f: Dictionary in features:
		var p: Vector2 = f["pos"]
		if p.x < EDGE + 100 or p.x > w - EDGE - 100 or p.y < EDGE + 100 or p.y > h - EDGE - 100:
			_err("%s: feature %s out of interior at %s" % [tag, f["type"], str(p)])
		# keep-out reports blocked at its own center.
		if not area.call("_blocked", p, 0.0):
			_err("%s: keep-out not active at feature %s center" % [tag, f["type"]])

	# 5. scatter + framing produced a populated world.
	var ent_n: int = entities.get_child_count()
	if ent_n < 80:
		_err("%s: world feels empty (%d entities)" % [tag, ent_n])

	# 5b. entry + exit signage placed.
	var signs := 0
	for c in entities.get_children():
		if _is_signpost(c):
			signs += 1
	if signs < 2:
		_err("%s: expected entry+exit signage, got %d signposts" % [tag, signs])

	# 6. a fresh free point respects keep-outs and trail clearance.
	for _s in range(40):
		var fp: Vector2 = area.call("_free_point", EDGE + 16, 22.0)
		if fp.x < 0.0:
			continue
		if area.call("_blocked", fp, 0.0):
			_err("%s: _free_point returned a blocked point" % tag)
			break

	if verbose:
		var tally := {}
		for f: Dictionary in features:
			tally[f["type"]] = int(tally.get(f["type"], 0)) + 1
		print("  [%s] %dx%d  density=%.2f  trail=%d  groundcover=%d  features=%s  entities=%d" % [
			tag, w, h, float(area.get("_density")), trail_n, cover_n, str(tally), ent_n])

	area.free()
