extends SceneTree

## World-content integrity: every path referenced by a biome, an encounter, or a
## location actually exists, so a typo'd scene/resource path can't slip into the
## expanding world (7 biomes, the encounter set, all locations). Also instantiates
## the new Vast creatures so a malformed enemy scene surfaces as a hard failure.
##
## Loads after awaiting frames so the BiomeData/EncounterData/WorldLocation
## class_name scripts resolve.

const BIOME_DIR := "res://resources/world/biomes"
const ENC_DIR := "res://resources/world/encounters"
const LOC_DIR := "res://resources/world/locations"
const VAST := [
	"res://scenes/entities/enemy_vast_hound.tscn",
	"res://scenes/entities/enemy_vast_hulk.tscn",
]

var _fail := 0
var _checked := 0

func _initialize() -> void:
	_run.call_deferred()

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _exists(ctx: String, path) -> void:
	if path == null:
		return
	var p := String(path)
	if p.is_empty():
		return
	_checked += 1
	if not ResourceLoader.exists(p):
		_err("%s -> missing '%s'" % [ctx, p])

func _run() -> void:
	await process_frame
	await process_frame

	for f in _tres(BIOME_DIR):
		var b = load(f)
		if b == null:
			_err("biome load failed: %s" % f)
			continue
		_exists(f, b.get("ground_texture_path"))
		_exists(f, b.get("border_path"))
		for key in ["enemy_paths", "prop_paths", "loot_paths", "encounter_paths", "gather_paths", "wildlife_paths"]:
			for p in (b.get(key) as Array):
				_exists("%s.%s" % [f.get_file(), key], p)

	for f in _tres(ENC_DIR):
		var e = load(f)
		if e == null:
			_err("encounter load failed: %s" % f)
			continue
		for p in (e.get("enemy_paths") as Array):
			_exists("%s.enemy" % f.get_file(), p)
		for p in (e.get("prop_paths") as Array):
			_exists("%s.prop" % f.get_file(), p)

	for f in _tres(LOC_DIR):
		var l = load(f)
		if l == null:
			_err("location load failed: %s" % f)
			continue
		var sp = l.get("scene_path")
		if sp != null and not String(sp).is_empty():
			_exists("%s.scene" % f.get_file(), sp)

	for path in VAST:
		var packed = load(path)
		if packed == null:
			_err("load failed: %s" % path)
			continue
		var inst = packed.instantiate()
		if inst == null:
			_err("instantiate failed: %s" % path)
		else:
			inst.queue_free()

	if _fail == 0:
		print("RESULT: PASS - %d world-content paths resolve; Vast creatures instantiate" % _checked)
	else:
		print("RESULT: FAIL - %d issue(s)" % _fail)
	quit()

func _tres(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		_err("cannot open %s" % dir)
		return out
	for f in d.get_files():
		if f.ends_with(".tres"):
			out.append("%s/%s" % [dir, f])
	return out
