extends Node2D

## Generic, biome-driven wild area. Reads the staged request from TravelManager
## (biome, tier, where its exits lead, and whether it is an explorable excursion
## or a one-way travel encounter), then paints the ground, scatters props, spawns
## tier-scaled enemies, and wires the exit gates.
##
## Exits are triggered by the player's position (no collision setup needed):
##   - encounter: a single "Continue" gate at the far side leads to the staged
##     destination — fight through or run past.
##   - explore: a "Return" gate at the near side goes back, and a "Deeper" gate at
##     the far side re-enters the same biome one tier higher.
##
## Expected child nodes (from procedural_area.tscn): $Ground (Sprite2D),
## $Entities (y-sorted Node2D, contains the Player), $Spawns/arrive (Marker2D).

@export var world_width: int = 720
@export var world_height: int = 400

## Fallback used if the scene is opened directly without a staged request.
@export var fallback_biome: BiomeData = null
@export var fallback_tier: int = 1

const EDGE := 24
const GATE_MARGIN := 20.0
const TREASURE_SCENE := preload("res://scenes/entities/treasure_chest.tscn")

var _rng := RandomNumberGenerator.new()
var _entities: Node2D
var _ground: Sprite2D

var _biome: BiomeData
var _tier: int = 1
var _return_to: StringName = &""
var _explore: bool = false

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

	_paint_ground()
	_scatter_props()
	_spawn_enemies()
	_spawn_treasure()
	_build_gates()
	_clamp_camera()

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

# --- Generation -------------------------------------------------------------

func _paint_ground() -> void:
	if _ground == null:
		return
	if ResourceLoader.exists(_biome.ground_texture_path):
		_ground.texture = load(_biome.ground_texture_path)
	_ground.region_enabled = true
	_ground.region_rect = Rect2(0, 0, world_width, world_height)
	_ground.modulate = _biome.ground_tint

func _scatter_props() -> void:
	var border := _load_scene(_biome.border_path)
	if border != null:
		var x := EDGE
		while x < world_width - EDGE:
			_add_prop(border, Vector2(x + _rng.randi_range(-6, 6), EDGE + _rng.randi_range(-4, 8)))
			_add_prop(border, Vector2(x + _rng.randi_range(-6, 6), world_height - 12 + _rng.randi_range(-6, 4)))
			x += _rng.randi_range(52, 84)

	var scenes: Array = []
	for path in _biome.prop_paths:
		var s := _load_scene(path)
		if s != null:
			scenes.append(s)
	if scenes.is_empty():
		return
	var count := _rng.randi_range(_biome.min_props, maxi(_biome.min_props, _biome.max_props))
	for i in range(count):
		var pos := Vector2(
			_rng.randi_range(EDGE + 16, world_width - EDGE - 16),
			_rng.randi_range(EDGE + 16, world_height - EDGE - 16)
		)
		_add_prop(scenes[_rng.randi() % scenes.size()], pos)

func _spawn_enemies() -> void:
	# More foes the deeper the tier; each is also scaled up by apply_tier().
	var base := _rng.randi_range(_biome.min_enemies, maxi(_biome.min_enemies, _biome.max_enemies))
	var count := base + (_tier - 1)
	var loot := _build_loot()
	for i in range(count):
		var path := _biome.pick_enemy_path(_rng)
		if path.is_empty():
			continue
		var scene := _load_scene(path)
		if scene == null:
			continue
		var enemy := scene.instantiate()
		# Spread across the middle so they aren't on top of the entry gate.
		var fx: float = lerp(0.35, 0.85, float(i + 1) / float(count + 1))
		if enemy is Node2D:
			(enemy as Node2D).position = Vector2(
				world_width * fx + _rng.randi_range(-30, 30),
				_rng.randi_range(EDGE + 24, world_height - EDGE - 24)
			)
		if not loot.is_empty():
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
	var chests: int = clampi(_tier - 1, 1, 3) if _explore else (1 if _rng.randf() < 0.4 else 0)
	for c in range(chests):
		var chest := TREASURE_SCENE.instantiate()
		if chest is Node2D:
			(chest as Node2D).position = Vector2(
				_rng.randi_range(EDGE + 24, world_width - EDGE - 24),
				_rng.randi_range(EDGE + 24, world_height - EDGE - 24)
			)
		_entities.add_child(chest)
		var n: int = clampi(1 + _tier / 2, 1, 3)
		var items: Array = []
		for i in range(n):
			items.append(pool[_rng.randi() % pool.size()])
		chest.call("configure", items)

func _build_loot() -> Array:
	var table: Array[Item] = []
	for path in _biome.loot_paths:
		if ResourceLoader.exists(path):
			var item := load(path) as Item
			if item != null:
				table.append(item)
	return table

# --- Exit gates -------------------------------------------------------------

func _build_gates() -> void:
	if _explore:
		_add_gate(0.0, GATE_MARGIN, _on_return, "← Return", Vector2(EDGE, world_height * 0.5), UITheme.PROMPT)
		_add_gate(world_width - GATE_MARGIN, world_width, _on_deeper, "Deeper →", Vector2(world_width - EDGE - 40, world_height * 0.5), UITheme.DANGER)
	else:
		_add_gate(world_width - GATE_MARGIN, world_width, _on_continue, "Continue →", Vector2(world_width - EDGE - 40, world_height * 0.5), UITheme.GOLD)

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
	var inst := scene.instantiate()
	if inst is Node2D:
		(inst as Node2D).position = pos
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
