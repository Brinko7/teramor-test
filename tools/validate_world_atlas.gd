extends SceneTree

## Headless integrity check for the three-kingdom world atlas: every WorldLocation
## resource, the region graph, the new regional biomes, the Cursed-Wilds Vast
## identity (the Withered), and the WorldMap autoload's grouping + arrival tagging.
##
## Run: godot --headless -s tools/validate_world_atlas.gd

const LOC_DIR := "res://resources/world/locations/"
const BIOME_DIR := "res://resources/world/biomes/"
const WITHERED := "res://scenes/entities/enemy_withered.tscn"
const NEW_BIOMES := ["plains", "desert", "vast_edge"]

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _list(dir_path: String, suffix: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			var clean: String = f.trim_suffix(".remap")
			if clean.ends_with(suffix):
				out.append(dir_path + clean)
		f = dir.get_next()
	dir.list_dir_end()
	return out

func _run() -> void:
	await process_frame
	await process_frame

	# --- Locations load and the graph is sound -------------------------------
	var locs: Dictionary = {}  # id -> WorldLocation
	for path in _list(LOC_DIR, ".tres"):
		var loc := load(path) as WorldLocation
		if loc == null:
			_err("location failed to load: %s" % path)
			continue
		if loc.id == &"":
			_err("location has empty id: %s" % path)
			continue
		if locs.has(loc.id):
			_err("duplicate location id: %s" % loc.id)
		locs[loc.id] = loc

	for id: Variant in locs.keys():
		var loc := locs[id] as WorldLocation
		if loc.region == &"":
			_err("%s has no region" % id)
		# Connections must point at real places.
		for c in loc.connections:
			if not locs.has(StringName(c)):
				_err("%s connects to unknown location '%s'" % [id, c])
		# A travelable place (built scene) must have a scene that exists; rumored
		# landmarks may have a blank scene_path (no built scene yet).
		if loc.scene_path != "" and not ResourceLoader.exists(loc.scene_path):
			_err("%s scene_path missing: %s" % [id, loc.scene_path])
		if not loc.rumored and loc.kind != &"landmark" and loc.scene_path == "":
			_err("%s is travelable but has no scene_path" % id)
		# Travel biome must resolve.
		if loc.travel_biome_path != "" and load(loc.travel_biome_path) == null:
			_err("%s travel_biome failed to load: %s" % [id, loc.travel_biome_path])

	# The three kingdoms + frontier must all be represented.
	for region in ["hollenmark", "plint", "terakin", "cursed_wilds"]:
		var found := false
		for id: Variant in locs.keys():
			if String((locs[id] as WorldLocation).region) == region:
				found = true
				break
		if not found:
			_err("no locations in region '%s'" % region)

	# The difficulty wall: the Great Tree sits far above the home town.
	if locs.has(&"the_great_tree") and locs.has(&"cleaves_landing"):
		if (locs[&"the_great_tree"] as WorldLocation).tier <= (locs[&"cleaves_landing"] as WorldLocation).tier + 3:
			_err("Cursed-Wilds frontier tier is not a real step above the home kingdom")

	# --- Biomes load and the new regions exist -------------------------------
	var biomes: Dictionary = {}
	for path in _list(BIOME_DIR, ".tres"):
		var b := load(path) as BiomeData
		if b == null:
			_err("biome failed to load: %s" % path)
			continue
		biomes[String(b.id)] = b
	for need in NEW_BIOMES:
		if not biomes.has(need):
			_err("expected new biome '%s' missing" % need)

	# Vast identity: the Withered must roam the cursed wilds and the Vast edge.
	if not ResourceLoader.exists(WITHERED):
		_err("withered scene missing: %s" % WITHERED)
	for region_biome in ["cursed_wilds", "vast_edge"]:
		var b := biomes.get(region_biome, null) as BiomeData
		if b == null:
			_err("biome '%s' missing for Vast check" % region_biome)
			continue
		if not (WITHERED in b.enemy_paths):
			_err("biome '%s' does not field the Withered" % region_biome)
		if b.base_tier < 5:
			_err("biome '%s' base_tier %d is too low for the deep frontier" % [region_biome, b.base_tier])

	# Every biome's enemy/encounter references must resolve.
	for bid: Variant in biomes.keys():
		var b := biomes[bid] as BiomeData
		for ep in b.enemy_paths:
			if not ResourceLoader.exists(ep):
				_err("biome '%s' references missing enemy %s" % [bid, ep])
		for enc in b.encounter_paths:
			if not ResourceLoader.exists(enc):
				_err("biome '%s' references missing encounter %s" % [bid, enc])

	# --- Live WorldMap autoload: grouping + arrival tagging -------------------
	var wm = get_root().get_node_or_null("WorldMap")
	if wm == null:
		_err("WorldMap autoload missing")
	else:
		var regions: Array = wm.get_map_regions()
		if regions.is_empty():
			_err("get_map_regions() returned nothing (rumored nodes should surface)")
		# A rumored distant goal should be visible on the map from the start.
		var saw_great_tree := false
		for r: Dictionary in regions:
			for loc: WorldLocation in r["locations"]:
				if loc.id == &"the_great_tree":
					saw_great_tree = true
		if not saw_great_tree:
			_err("rumored landmark 'the_great_tree' not surfaced on the map")

		# A journey stages an arrival; a shared scene then claims that id.
		wm.stage_arrival(&"hollen")
		var claimed: StringName = wm.claim_arrival(&"cleaves_landing")
		if claimed != &"hollen":
			_err("claim_arrival did not honour a staged journey (got %s)" % claimed)
		if not wm.is_discovered(&"hollen"):
			_err("claim_arrival did not discover the staged destination")
		# With nothing staged, a scene claims its own fallback id.
		var fallback: StringName = wm.claim_arrival(&"cleaves_landing")
		if fallback != &"cleaves_landing":
			_err("claim_arrival fallback wrong (got %s)" % fallback)

	if _fail == 0:
		print("RESULT: PASS - world atlas (kingdoms, biomes, Vast frontier, map grouping) is sound")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
