extends Node2D

## Generic, biome-driven wild area. Reads the staged request from TravelManager
## (biome, tier, where its exits lead, and whether it is an explorable excursion
## or a one-way travel encounter), then paints the ground, lays a meandering trail,
## drops random interior features (groves, clearings, ponds, ruins), frames the
## area, scatters props, spawns tier-scaled enemies + authored encounter setpieces,
## and wires the exit gates.
##
## Areas are deliberately VAST (multi-screen) and freshly generated every visit —
## the trail, features, scatter and encounters are all RNG-driven so re-entering a
## biome feels like new ground to explore.
##
## Exits are triggered by the player's position (no collision setup needed):
##   - encounter: a single "Continue" gate at the far side leads to the staged
##     destination — fight through or run past.
##   - explore: a "Return" gate at the near side goes back, and a "Deeper" gate at
##     the far side re-enters the same biome one tier higher.
##
## Expected child nodes (from procedural_area.tscn): $Ground (Sprite2D),
## $Entities (y-sorted Node2D, contains the Player), $Spawns/arrive (Marker2D).
## A $Decals layer is created at runtime between Ground and Entities for flat
## ground decals (trail, pond water).

@export var world_width: int = 1280
@export var world_height: int = 960

## Fallback used if the scene is opened directly without a staged request.
@export var fallback_biome: BiomeData = null
@export var fallback_tier: int = 1

const EDGE := 24
const GATE_MARGIN := 20.0
## Reference area the biome densities were authored against; bigger areas scale up.
const BASE_AREA := 288000.0
## Half-height of the clear "mouth" left in the side border for each exit/trail.
const MOUTH := 110.0

const TREASURE_SCENE := preload("res://scenes/entities/treasure_chest.tscn")
const GATHER_SCENE := preload("res://scenes/entities/gather_node.tscn")

const TREE_SCENE := "res://scenes/entities/props/tree.tscn"
const ROCK_SCENE := "res://scenes/entities/props/rock.tscn"
const BUSH_SCENE := "res://scenes/entities/props/bush.tscn"
const FLOWER_SCENE := "res://scenes/entities/props/flower.tscn"
const CRATE_SCENE := "res://scenes/entities/props/crate.tscn"
const BARREL_SCENE := "res://scenes/entities/props/barrel.tscn"
const FENCE_SCENE := "res://scenes/entities/props/fence.tscn"
const SIGNPOST_SCENE := "res://scenes/entities/props/signpost.tscn"
const WATER_TEX := "res://assets/placeholder/water.png"
const PATH_TEX := "res://assets/placeholder/path.png"

## Tints applied to gather nodes so materials read distinctly at a glance.
const GATHER_TINTS := {
	&"stone": Color(0.82, 0.82, 0.86),
	&"iron_ore": Color(0.78, 0.62, 0.46),
	&"crystal": Color(0.5, 0.85, 0.95),
	&"wood": Color(0.62, 0.45, 0.3),
}
## Which tool a gathered material needs — veins want a pickaxe, wood wants an axe;
## anything unlisted (herb/mushroom) is hand-gathered (press E). Drives the new
## tool-verb gating on GatherNode.
const GATHER_TOOLS := {
	&"stone": &"pickaxe",
	&"iron_ore": &"pickaxe",
	&"crystal": &"pickaxe",
	&"wood": &"axe",
}
const FISHING_SPOT_SCENE := preload("res://scenes/entities/fishing_spot.tscn")

## Minimap blip colours per feature kind.
const FEATURE_COLORS := {
	&"pond": Color(0.42, 0.68, 1.0),
	&"grove": Color(0.32, 0.66, 0.36),
	&"clearing": Color(0.86, 0.84, 0.6),
	&"ruin": Color(0.72, 0.7, 0.72),
	&"thicket": Color(0.36, 0.58, 0.32),
}

var _rng := RandomNumberGenerator.new()
var _entities: Node2D
var _ground: Sprite2D
var _decals: Node2D

var _biome: BiomeData
var _tier: int = 1
var _return_to: StringName = &""
var _explore: bool = false

## How much denser/bigger this area is vs. the authored base (scales scatter/gather).
var _density: float = 1.0

## Meandering-trail parameters (RNG each generation).
var _trail_base: float = 480.0
var _amp1: float = 0.0
var _amp2: float = 0.0
var _f1: float = 0.0
var _f2: float = 0.0
var _p1: float = 0.0
var _p2: float = 0.0

## Placed interior features as keep-out zones: [{pos: Vector2, radius: float, type: StringName}].
var _features: Array = []

## Active position-triggered gates: {min_x, max_x, action: Callable, done: bool}.
var _gates: Array = []
## Set once a gate fires, so the player can't trip a second exit during the fade.
var _exiting: bool = false

func _ready() -> void:
	_rng.randomize()
	_entities = get_node_or_null("Entities")
	_ground = get_node_or_null("Ground")

	var pending: Dictionary = TravelManager.consume_pending()
	_biome = pending.get("biome", fallback_biome)
	_tier = int(pending.get("tier", fallback_tier))
	_return_to = StringName(pending.get("return_to", ""))
	_explore = bool(pending.get("explore", false))

	if _biome == null or _entities == null:
		push_warning("procedural_area: no biome staged and no fallback set")
		return

	_density = clampf(float(world_width * world_height) / BASE_AREA, 1.0, 4.5)
	_setup_decals()
	_setup_trail()

	_paint_ground()
	_paint_trail()
	_place_features()
	_frame_border()
	_scatter_props()
	_spawn_enemies()
	_spawn_wildlife()
	_spawn_encounters()
	_spawn_treasure()
	_spawn_gather_nodes()
	_build_gates()
	_place_signage()
	_send_to_minimap()
	_clamp_camera()
	MusicManager.enter_zone(_music_zone())

## Map the staged biome to a music zone: the Cursed-Wilds biomes get the ominous
## theme, the cave its own bed, everything else the lonely wild exploration theme.
func _music_zone() -> StringName:
	if _biome == null:
		return &"wild"
	match _biome.id:
		&"cursed_wilds", &"vast_edge":
			return &"cursed"
		&"cave":
			return &"cave"
		_:
			return &"wild"

func _physics_process(_delta: float) -> void:
	if _exiting or _gates.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var px: float = (player as Node2D).global_position.x
	for gate: Dictionary in _gates:
		if px >= float(gate["min_x"]) and px <= float(gate["max_x"]):
			_exiting = true
			(gate["action"] as Callable).call()
			return

# --- Setup ------------------------------------------------------------------

## A flat decal layer between the Ground sprite and the y-sorted Entities, so the
## trail and pond water always render under everything gameplay regardless of y.
func _setup_decals() -> void:
	_decals = Node2D.new()
	_decals.name = "Decals"
	add_child(_decals)
	move_child(_decals, 1)

## Roll the meander shape: two sine waves with random amplitude/frequency/phase,
## enveloped so the trail pins to mid-height at both edge "mouths".
func _setup_trail() -> void:
	_trail_base = world_height * 0.5
	_amp1 = _rng.randf_range(150.0, 210.0)
	_amp2 = _rng.randf_range(60.0, 110.0)
	_f1 = _rng.randf_range(2.0, 3.2) * TAU
	_f2 = _rng.randf_range(4.0, 6.5) * TAU
	_p1 = _rng.randf_range(0.0, TAU)
	_p2 = _rng.randf_range(0.0, TAU)

## Trail centerline height at a given x. Pinned to mid-height at both ends so it
## connects cleanly to the entry/exit mouths, meandering most in the middle.
func _trail_y(x: float) -> float:
	var u: float = clampf(x / float(world_width), 0.0, 1.0)
	var env: float = sin(PI * u)
	var y: float = _trail_base + env * (_amp1 * sin(u * _f1 + _p1) + _amp2 * sin(u * _f2 + _p2))
	return clampf(y, EDGE + 72, world_height - EDGE - 72)

# --- Generation -------------------------------------------------------------

func _paint_ground() -> void:
	if _ground == null:
		return
	if ResourceLoader.exists(_biome.ground_texture_path):
		_ground.texture = load(_biome.ground_texture_path)
	_ground.region_enabled = true
	_ground.region_rect = Rect2(0, 0, world_width, world_height)
	_ground.modulate = _biome.ground_tint

## Lay the worn trail as a ribbon of overlapping path-tile decals from the entry
## mouth to the exit mouth, following the meander.
func _paint_trail() -> void:
	var x: float = float(EDGE)
	while x <= world_width - EDGE:
		var y: float = _trail_y(x)
		_add_decal(PATH_TEX, Rect2(x - 18.0, y - 16.0, 36.0, 32.0), Color(0.94, 0.9, 0.84))
		x += 14.0

## A flat ground decal (tiled texture) on the Decals layer.
func _add_decal(tex_path: String, rect: Rect2, tint: Color) -> void:
	if not ResourceLoader.exists(tex_path) or _decals == null:
		return
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.position = rect.position
	s.modulate = tint
	_decals.add_child(s)

## Pick a handful of interior features and place them at non-overlapping anchors,
## kept away from the edges. Each records a keep-out radius so generic scatter and
## loot don't pile on top of it (and clearings stay open).
func _place_features() -> void:
	var kinds := [&"grove", &"grove", &"clearing", &"clearing", &"pond", &"ruin", &"thicket", &"thicket"]
	var want: int = _rng.randi_range(4, 7)
	var mx: int = EDGE + 140
	var my: int = EDGE + 140
	for _i in range(want):
		var kind: StringName = kinds[_rng.randi() % kinds.size()]
		var radius: float = _feature_radius(kind)
		var anchor := Vector2.ZERO
		var placed := false
		for _try in range(14):
			var c := Vector2(_rng.randi_range(mx, world_width - mx), _rng.randi_range(my, world_height - my))
			if _overlaps_feature(c, radius):
				continue
			anchor = c
			placed = true
			break
		if not placed:
			continue
		_build_feature(kind, anchor, radius)
		_features.append({"pos": anchor, "radius": _keepout_radius(kind, radius), "type": kind})

func _feature_radius(kind: StringName) -> float:
	match kind:
		&"pond": return _rng.randf_range(64.0, 104.0)
		&"grove": return _rng.randf_range(80.0, 120.0)
		&"clearing": return _rng.randf_range(72.0, 112.0)
		&"ruin": return _rng.randf_range(66.0, 100.0)
		_: return _rng.randf_range(60.0, 96.0)

## How far generic scatter/loot must stay from a feature's center. Clearings keep
## their whole radius clear (so they read as open); dense features keep less.
func _keepout_radius(kind: StringName, radius: float) -> float:
	match kind:
		&"clearing": return radius
		&"pond": return radius + 12.0
		&"ruin": return radius * 0.6
		&"grove": return radius * 0.45
		_: return radius * 0.4

func _overlaps_feature(c: Vector2, radius: float) -> bool:
	for f: Dictionary in _features:
		if c.distance_to(f["pos"]) < radius + float(f["radius"]) + 28.0:
			return true
	return false

func _build_feature(kind: StringName, c: Vector2, r: float) -> void:
	match kind:
		&"pond": _feature_pond(c, r)
		&"grove": _feature_grove(c, r)
		&"clearing": _feature_clearing(c, r)
		&"ruin": _feature_ruin(c, r)
		_: _feature_thicket(c, r)

## A water patch ringed with rocks/bushes (decorative — no collision yet).
func _feature_pond(c: Vector2, r: float) -> void:
	var w: float = r * 2.0
	var h: float = r * 1.5
	_add_decal(WATER_TEX, Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), Color(0.86, 0.92, 1.0))
	var ring: int = _rng.randi_range(5, 8)
	for i in range(ring):
		var a: float = TAU * float(i) / float(ring) + _rng.randf_range(-0.25, 0.25)
		var rim := c + Vector2(cos(a) * w * 0.52, sin(a) * h * 0.56)
		_add_prop(_load_scene(ROCK_SCENE if _rng.randf() < 0.5 else BUSH_SCENE), rim)
	# A fishable spot at the bank — cast here with the rod (or interact carrying one).
	var spot := FISHING_SPOT_SCENE.instantiate()
	if spot is Node2D:
		(spot as Node2D).position = c + Vector2(0, h * 0.40)
	_entities.add_child(spot)

## A dense cluster of the biome's border tree (or plain tree as a fallback).
func _feature_grove(c: Vector2, r: float) -> void:
	var tree := _load_scene(_biome.border_path)
	if tree == null:
		tree = _load_scene(TREE_SCENE)
	if tree == null:
		return
	var n: int = _rng.randi_range(6, 10)
	for i in range(n):
		var rp := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * r
		_add_prop(tree, c + rp)

## An open glade — a ring of flowers, empty center (kept clear by its keep-out).
func _feature_clearing(c: Vector2, r: float) -> void:
	var flower := _load_scene(FLOWER_SCENE)
	if flower == null:
		return
	var n: int = _rng.randi_range(5, 9)
	for i in range(n):
		var a: float = TAU * float(i) / float(n) + _rng.randf_range(-0.3, 0.3)
		var rad: float = r * _rng.randf_range(0.7, 1.0)
		_add_prop(flower, c + Vector2(cos(a), sin(a)) * rad)

## Scattered rocks/crates/barrels suggesting a broken structure.
func _feature_ruin(c: Vector2, r: float) -> void:
	var pieces := [ROCK_SCENE, ROCK_SCENE, CRATE_SCENE, BARREL_SCENE, FENCE_SCENE]
	var n: int = _rng.randi_range(6, 10)
	for i in range(n):
		var ring: float = _rng.randf_range(0.45, 1.0)
		var a: float = _rng.randf_range(0.0, TAU)
		var pos := c + Vector2(cos(a), sin(a)) * (r * ring)
		_add_prop(_load_scene(pieces[_rng.randi() % pieces.size()]), pos)

## A bramble of bushes and the odd flower — good forage cover.
func _feature_thicket(c: Vector2, r: float) -> void:
	var bush := _load_scene(BUSH_SCENE)
	var flower := _load_scene(FLOWER_SCENE)
	var n: int = _rng.randi_range(6, 11)
	for i in range(n):
		var rp := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * r
		_add_prop(bush if _rng.randf() < 0.7 else flower, c + rp)

## Wall the area on all four sides with the biome's border scene, leaving a clear
## "mouth" at mid-height on the left and right so the player can reach the gates
## and the trail flows out of the area.
func _frame_border() -> void:
	var border := _load_scene(_biome.border_path)
	if border == null:
		return
	var x: int = EDGE
	while x < world_width - EDGE:
		_add_border_prop(border, Vector2(x + _rng.randi_range(-6, 6), EDGE + _rng.randi_range(-4, 8)))
		_add_border_prop(border, Vector2(x + _rng.randi_range(-6, 6), world_height - 12 + _rng.randi_range(-6, 4)))
		x += _rng.randi_range(52, 84)
	var mid: float = world_height * 0.5
	var y: int = EDGE + 48
	while y < world_height - EDGE - 48:
		if absf(float(y) - mid) > MOUTH:
			_add_border_prop(border, Vector2(EDGE + _rng.randi_range(-4, 8), y + _rng.randi_range(-6, 6)))
			_add_border_prop(border, Vector2(world_width - 12 + _rng.randi_range(-6, 4), y + _rng.randi_range(-6, 6)))
		y += _rng.randi_range(52, 84)

func _scatter_props() -> void:
	var scenes: Array = []
	for path in _biome.prop_paths:
		var s := _load_scene(path)
		if s != null:
			scenes.append(s)
	if scenes.is_empty():
		return
	var base := _rng.randi_range(_biome.min_props, maxi(_biome.min_props, _biome.max_props))
	var count: int = int(round(float(base) * _density))
	for i in range(count):
		var pos := _free_point(EDGE + 16, 22.0)
		if pos.x < 0.0:
			continue
		_add_prop(scenes[_rng.randi() % scenes.size()], pos)

## Find an open point not inside any feature keep-out and at least `trail_clear`
## from the trail centerline. Returns (-1,-1) if it can't after a few tries.
func _free_point(margin: int, trail_clear: float) -> Vector2:
	for _t in range(8):
		var p := Vector2(
			_rng.randi_range(margin, world_width - margin),
			_rng.randi_range(margin, world_height - margin)
		)
		if _blocked(p, 0.0):
			continue
		if trail_clear > 0.0 and absf(p.y - _trail_y(p.x)) < trail_clear:
			continue
		return p
	return Vector2(-1.0, -1.0)

func _blocked(pos: Vector2, pad: float) -> bool:
	for f: Dictionary in _features:
		if pos.distance_to(f["pos"]) < float(f["radius"]) + pad:
			return true
	return false

## Sparse "ambient" wanderers — the few lone foes you stumble on between setpieces.
## Kept deliberately low so the wilds read as semi-peaceful; the designed beats come
## from _spawn_encounters().
func _spawn_enemies() -> void:
	var loot := _build_loot()
	var count := _rng.randi_range(_biome.min_enemies, maxi(_biome.min_enemies, _biome.max_enemies))
	if _density >= 2.0:
		count += 1
	for i in range(count):
		var path := _biome.pick_enemy_path(_rng)
		if path.is_empty():
			continue
		var pos := Vector2(
			world_width * lerp(0.30, 0.85, _rng.randf()) + _rng.randi_range(-30, 30),
			_rng.randi_range(EDGE + 24, world_height - EDGE - 24)
		)
		_place_enemy(_load_scene(path), pos, loot)

## Scatter passive wildlife (deer/rabbit) for the player to hunt. Deliberately does
## NOT route through _place_enemy: that overrides loot_table with biome loot, but
## wildlife must keep its authored meat/hide drops — and Wildlife ignores apply_tier,
## so it stays ambient rather than scaling into a threat. Placed on open ground away
## from the trail/features so the animals read as grazing in the wild.
func _spawn_wildlife() -> void:
	if _biome.wildlife_paths.is_empty() or _biome.max_wildlife <= 0:
		return
	var base := _rng.randi_range(_biome.min_wildlife, maxi(_biome.min_wildlife, _biome.max_wildlife))
	var count: int = int(round(float(base) * _density))
	for i in range(count):
		var path := _biome.pick_wildlife_path(_rng)
		if path.is_empty():
			continue
		var scene := _load_scene(path)
		if scene == null:
			continue
		var pos := _free_point(EDGE + 24, 24.0)
		if pos.x < 0.0:
			continue
		var animal := scene.instantiate()
		if animal is Node2D:
			(animal as Node2D).position = pos
		_entities.add_child(animal)

## Drop the biome's authored encounter setpieces (wolf pack, bear & cubs, bandit
## camp) into the area, capped by a per-area budget so it never overwhelms. Anchors
## are spread along the corridor (entry → exit) with jitter so setpieces stay apart,
## clear of the gates, and leave big calm gaps to explore between them. Anchors that
## land on a pond are nudged off it.
func _spawn_encounters() -> void:
	if _biome.encounter_paths.is_empty() or _biome.max_encounters <= 0:
		return
	var loot := _build_loot()
	var budget := _rng.randi_range(_biome.min_encounters, maxi(_biome.min_encounters, _biome.max_encounters))
	if _explore:
		budget += _tier / 2
	if _density >= 2.0:
		budget += 1
	for i in range(budget):
		var enc := _biome.pick_encounter(_rng, _tier)
		if enc == null:
			continue
		var t: float = (float(i) + 0.5) / float(maxi(1, budget))
		var ax: float = lerp(world_width * 0.22, world_width * 0.86, t) + _rng.randf_range(-50.0, 50.0)
		var ay: float = _rng.randf_range(EDGE + 64, world_height - EDGE - 64)
		var anchor := Vector2(ax, ay)
		for _n in range(4):
			if not _blocked(anchor, enc.radius * 0.5):
				break
			anchor.y = _rng.randf_range(EDGE + 64, world_height - EDGE - 64)
		_spawn_encounter(enc, anchor, loot)

## Lay out one setpiece around its anchor: decor first, then the enemy formation,
## then an optional loot-cache chest.
func _spawn_encounter(enc: EncounterData, anchor: Vector2, loot: Array) -> void:
	for i in range(enc.prop_paths.size()):
		var prop := _load_scene(enc.prop_paths[i])
		if prop != null:
			_add_prop(prop, anchor + enc.prop_offset(i))
	for i in range(enc.enemy_paths.size()):
		_place_enemy(_load_scene(enc.enemy_paths[i]), anchor + enc.enemy_offset(i), loot)
	if enc.loot_cache:
		_make_chest(anchor + enc.loot_offset, loot)

## Instantiate one enemy at `pos`, give it the biome loot table, add it, and scale
## it to the area tier. No-op on a null scene.
func _place_enemy(scene: PackedScene, pos: Vector2, loot: Array) -> void:
	if scene == null:
		return
	var enemy := scene.instantiate()
	if enemy is Node2D:
		(enemy as Node2D).position = pos
	# Keep an enemy's own thematic loot (wolf -> meat/hide, bandit -> their gear);
	# only fall back to the biome pool for enemies that ship without a table, so
	# drops read as logical rather than a generic biome grab-bag.
	var own_loot = enemy.get("loot_table")
	if not loot.is_empty() and (own_loot == null or (own_loot is Array and own_loot.is_empty())):
		enemy.set("loot_table", loot)
		enemy.set("loot_chance", 0.5)
	_entities.add_child(enemy)
	if enemy.has_method("apply_tier"):
		enemy.call("apply_tier", _tier)

## Scatter treasure chests. Excursions reward exploration more than one-off
## encounters, and deeper tiers stock fuller chests — so braving the Wilds pays.
func _spawn_treasure() -> void:
	var pool: Array = _build_loot()
	if pool.is_empty():
		return
	# Chests are a real find, not litter: usually none-to-one, with a small chance
	# of a second only deep in an excursion. Foraging (gather nodes) and the loot
	# caches you earn by clearing an authored camp are the steady reward — a chest
	# you stumble on in the open should feel rare.
	var chests := 0
	if _rng.randf() < (0.3 + 0.1 * float(_tier)):
		chests = 1
	if _explore and _tier >= 3 and _rng.randf() < 0.3:
		chests += 1
	for c in range(chests):
		var pos := _free_point(EDGE + 24, 0.0)
		if pos.x < 0.0:
			continue
		_make_chest(pos, pool)

## Spawn a treasure chest at `pos` stocked from `pool` (deeper tiers stock fuller).
func _make_chest(pos: Vector2, pool: Array) -> void:
	if pool.is_empty():
		return
	var chest := TREASURE_SCENE.instantiate()
	if chest is Node2D:
		(chest as Node2D).position = pos
	_entities.add_child(chest)
	var n: int = clampi(1 + _tier / 2, 1, 3)
	var items: Array = []
	for i in range(n):
		items.append(pool[_rng.randi() % pool.size()])
	chest.call("configure", items)

## Scatter harvestable resource nodes (mining/foraging). Richer deeper in.
func _spawn_gather_nodes() -> void:
	if _biome.gather_paths.is_empty() or _biome.max_gather <= 0:
		return
	var base: int = _rng.randi_range(_biome.min_gather, maxi(_biome.min_gather, _biome.max_gather))
	var count: int = int(round(float(base) * _density))
	for i in range(count):
		var path: String = _biome.gather_paths[_rng.randi() % _biome.gather_paths.size()]
		if not ResourceLoader.exists(path):
			continue
		var item := load(path) as Item
		if item == null:
			continue
		var node := GATHER_SCENE.instantiate()
		var pos := _free_point(EDGE + 24, 0.0)
		if pos.x < 0.0:
			pos = Vector2(_rng.randi_range(EDGE + 24, world_width - EDGE - 24), _rng.randi_range(EDGE + 24, world_height - EDGE - 24))
		if node is Node2D:
			(node as Node2D).position = pos
		_entities.add_child(node)
		var qty: int = 2 + _rng.randi_range(0, 1 + _tier / 2)
		node.call("configure", item, qty, GATHER_TINTS.get(item.id, Color.WHITE), GATHER_TOOLS.get(item.id, &""))

func _build_loot() -> Array:
	var table: Array[Item] = []
	for path in _biome.loot_paths:
		if ResourceLoader.exists(path):
			var item := load(path) as Item
			if item != null:
				table.append(item)
	return table

# --- Minimap ----------------------------------------------------------------

func _send_to_minimap() -> void:
	var mm := get_tree().get_first_node_in_group("minimap")
	if mm == null or not mm.has_method("configure"):
		return
	var blips: Array = []
	for f: Dictionary in _features:
		blips.append({"pos": f["pos"], "color": FEATURE_COLORS.get(f["type"], Color.WHITE)})
	if _explore:
		blips.append({"pos": Vector2(EDGE, _trail_y(EDGE)), "color": UITheme.PROMPT})
		blips.append({"pos": Vector2(world_width - EDGE, _trail_y(world_width - EDGE)), "color": UITheme.DANGER})
	else:
		blips.append({"pos": Vector2(world_width - EDGE, _trail_y(world_width - EDGE)), "color": UITheme.GOLD})
	mm.call("configure", Vector2(world_width, world_height), blips)

# --- Exit gates -------------------------------------------------------------

func _build_gates() -> void:
	var left_y: float = _trail_y(EDGE)
	var right_y: float = _trail_y(world_width - EDGE)
	if _explore:
		_add_gate(0.0, GATE_MARGIN, _on_return, "← Return", Vector2(EDGE, left_y), UITheme.PROMPT)
		_add_gate(world_width - GATE_MARGIN, world_width, _on_deeper, "Deeper →", Vector2(world_width - EDGE - 40, right_y), UITheme.DANGER)
	else:
		_add_gate(world_width - GATE_MARGIN, world_width, _on_continue, "Continue →", Vector2(world_width - EDGE - 40, right_y), UITheme.GOLD)

## Diegetic trail signage at the mouths: a post naming the area at the entrance, and
## a carved warning at the far exit (worded by danger, never a tier number — the kind
## of thing a villager would actually carve). Posts don't block movement; walk up and
## press interact to read the carved line in the dialogue box.
func _place_signage() -> void:
	var entry_x: float = float(EDGE + 52)
	_place_sign(Vector2(entry_x, _trail_y(entry_x) + 30.0), _biome.display_name)
	var exit_x: float = float(world_width - EDGE - 64)
	var warn: String = _danger_line(_tier + 1) if _explore else "The road continues"
	_place_sign(Vector2(exit_x, _trail_y(exit_x) + 30.0), warn)

func _place_sign(pos: Vector2, text: String) -> void:
	var scene := _load_scene(SIGNPOST_SCENE)
	if scene == null:
		return
	var post := scene.instantiate()
	if post is Node2D:
		(post as Node2D).position = pos
	post.set("text", text)
	_entities.add_child(post)

## Carved-board warning worded by danger, scaling with how deep you'd push — never a
## number or colour code (those belong in menus, not on a villager's signpost).
func _danger_line(tier: int) -> String:
	if tier <= 1:
		return "The trail winds on"
	elif tier == 2:
		return "Wild country ahead"
	elif tier == 3:
		return "Danger ahead —\ngo armed"
	elif tier == 4:
		return "Turn back if you\nvalue your life"
	return "Cursed ground\nlies beyond"

func _add_gate(min_x: float, max_x: float, action: Callable, text: String, label_pos: Vector2, color: Color) -> void:
	_gates.append({"min_x": min_x, "max_x": max_x, "action": action})
	var label := UITheme.make_label(text, 10, color)
	label.position = label_pos
	_entities.add_child(label)

func _on_return() -> void:
	TravelManager.arrive(_return_to)

func _on_continue() -> void:
	TravelManager.arrive(_return_to)

func _on_deeper() -> void:
	TravelManager.enter_area(_biome, _tier + 1, _return_to, true)

# --- Helpers ----------------------------------------------------------------

func _add_prop(scene: PackedScene, pos: Vector2) -> void:
	if scene == null:
		return
	var inst := scene.instantiate()
	if inst is Node2D:
		(inst as Node2D).position = pos
	_entities.add_child(inst)

## A border prop that, if it's a choppable tree, is marked un-choppable before it
## enters the tree — so felling can never breach the area's frame.
func _add_border_prop(scene: PackedScene, pos: Vector2) -> void:
	if scene == null:
		return
	var inst := scene.instantiate()
	if inst is Node2D:
		(inst as Node2D).position = pos
	if "choppable" in inst:
		inst.set("choppable", false)
	_entities.add_child(inst)

func _load_scene(path: String) -> PackedScene:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene

func _clamp_camera() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam := (player as Node).get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = world_width
		cam.limit_bottom = world_height
