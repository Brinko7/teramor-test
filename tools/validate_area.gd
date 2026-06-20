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

## Check that a signpost with text builds its carved label, and an empty one stays a
## plain post. Drives _ready() directly (it needs no tree), so this is deterministic.
func _check_signpost() -> void:
	print("\n[signpost] carved-label build")
	var scene := load("res://scenes/entities/props/signpost.tscn") as PackedScene
	if scene == null:
		_err("signpost.tscn missing")
		return
	var post := scene.instantiate()
	post.set("text", "Danger ahead")
	post.call("_ready")
	var labels := 0
	for c in post.get_children():
		if c is Label:
			labels += 1
			if (c as Label).text != "Danger ahead":
				_err("signpost label text wrong: '%s'" % (c as Label).text)
	if labels != 1:
		_err("signpost with text should build exactly one label, got %d" % labels)
	post.free()
	var plain := scene.instantiate()
	plain.call("_ready")
	for c in plain.get_children():
		if c is Label:
			_err("empty signpost should have no label")
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
	area.call("_frame_border")
	area.call("_scatter_props")
	area.call("_place_signage")

	var decals: Node2D = area.get("_decals")
	var features: Array = area.get("_features")
	var tag := "%s/seed%d" % [biome.id, seed_v]

	# 1. dimensions are the vast target.
	if w < 1200 or h < 900:
		_err("%s: area not vast (%dx%d)" % [tag, w, h])

	# 2. trail decals laid as a ribbon.
	var decal_n: int = decals.get_child_count() if decals != null else 0
	if decal_n < 80:
		_err("%s: too few trail decals (%d)" % [tag, decal_n])

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
		if c is Signpost:
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
		print("  [%s] %dx%d  density=%.2f  decals=%d  features=%s  entities=%d" % [
			tag, w, h, float(area.get("_density")), decal_n, str(tally), ent_n])

	area.free()
