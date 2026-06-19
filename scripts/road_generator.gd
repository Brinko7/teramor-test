extends Node2D
## Procedurally builds a horizontal road segment connecting the settlement
## (left) and the town (right). Paints a dirt/cobble road band on the Terrain
## TileMapLayer, scatters roadside decor avoiding the road, and spawns a couple
## of bandit enemies along the road.
##
## Expects sibling/child nodes (provided by road.tscn):
##   - $Ground            : Sprite2D (tiled grass)
##   - $Terrain           : TileMapLayer (tile_set = terrain.tres)
##   - $Entities          : Node2D (y_sort_enabled) for props/enemies
## Marker2D spawns "from_settlement"/"from_town", a Player, and two
## transition_zones are placed in the scene file.

## Atlas tile indices in terrain.tres (source id 0, row 0).
const TILE_GRASS := 0
const TILE_DIRT := 2
const TILE_COBBLE := 3
const TILE_SOURCE := 0
const CELL := 16

## World extent (in pixels). Wider than tall: it's a road.
@export var world_width: int = 960
@export var world_height: int = 320
## Set >= 0 for a repeatable layout; -1 randomizes each entry.
@export var use_seed: int = -1
## Road band vertical center (pixels) and nominal half-height (pixels).
@export var road_center_y: int = 160
@export var road_half_height: int = 28

const ENEMY_PATH := "res://scenes/entities/enemy.tscn"

## Weighted enemy roster. Common, weak types have high weight; tough, rewarding
## types are rare. `weight` is relative (summed at spawn time).
const ENEMY_TYPES := [
	{"path": "res://scenes/entities/enemy.tscn", "weight": 4.0},
	{"path": "res://scenes/entities/enemy_wolf.tscn", "weight": 4.0},
	{"path": "res://scenes/entities/enemy_archer.tscn", "weight": 2.0},
	{"path": "res://scenes/entities/enemy_brute.tscn", "weight": 1.0},
]

const LOOT_PATHS := [
	"res://resources/items/health_potion.tres",
	"res://resources/items/herb.tres",
	"res://resources/items/wood.tres",
]
const PROP_TREE := "res://scenes/entities/props/tree.tscn"
const PROP_ROCK := "res://scenes/entities/props/rock.tscn"
const PROP_BUSH := "res://scenes/entities/props/bush.tscn"
const PROP_FLOWER := "res://scenes/entities/props/flower.tscn"

var _rng := RandomNumberGenerator.new()
var _entities: Node2D
var _terrain: TileMapLayer

func _ready() -> void:
	if use_seed >= 0:
		_rng.seed = use_seed
	else:
		_rng.randomize()

	_entities = get_node_or_null("Entities")
	_terrain = get_node_or_null("Terrain")
	if _entities == null or _terrain == null:
		push_warning("road_generator: missing Entities or Terrain node")
		return

	_paint_terrain()
	_scatter_decor()
	_spawn_enemies()

## Returns the road's top/bottom y (pixels) for a given column x, with a little
## wobble so edges aren't perfectly straight.
func _road_bounds_at(cell_x: int) -> Vector2i:
	var wobble := int(round(sin(float(cell_x) * 0.6) * 1.5))
	var extra := _rng.randi_range(-1, 1)
	var center_cell := int(road_center_y / CELL)
	var half_cells := int(road_half_height / CELL) + 1
	var top := center_cell - half_cells + wobble
	var bottom := center_cell + half_cells + wobble + extra
	return Vector2i(top, bottom)

func _paint_terrain() -> void:
	var cols := int(ceil(float(world_width) / CELL))
	var rows := int(ceil(float(world_height) / CELL))
	for cx in range(cols):
		var bounds := _road_bounds_at(cx)
		for cy in range(rows):
			if cy >= bounds.x and cy <= bounds.y:
				# Mostly dirt with occasional cobble for texture.
				var atlas_x := TILE_COBBLE if _rng.randf() < 0.18 else TILE_DIRT
				_terrain.set_cell(Vector2i(cx, cy), TILE_SOURCE, Vector2i(atlas_x, 0))

## True if a world-space point sits on (or just beside) the road band.
func _on_road(pos: Vector2, margin: float = 10.0) -> bool:
	var top := (road_center_y - road_half_height) - margin
	var bottom := (road_center_y + road_half_height) + margin
	return pos.y >= top and pos.y <= bottom

func _scatter_decor() -> void:
	var tree_scene := _load(PROP_TREE)
	var rock_scene := _load(PROP_ROCK)
	var bush_scene := _load(PROP_BUSH)
	var flower_scene := _load(PROP_FLOWER)

	# Dense tree borders along top and bottom edges.
	var x := 24
	while x < world_width - 24:
		if tree_scene != null:
			_add_prop(tree_scene, Vector2(x + _rng.randi_range(-6, 6), 24 + _rng.randi_range(-4, 8)))
			_add_prop(tree_scene, Vector2(x + _rng.randi_range(-6, 6), world_height - 16 + _rng.randi_range(-6, 4)))
		x += _rng.randi_range(48, 80)

	# Scattered small decor avoiding the road.
	var scatter_scenes := [bush_scene, rock_scene, flower_scene, flower_scene]
	var count := _rng.randi_range(22, 34)
	for i in range(count):
		var scene: PackedScene = scatter_scenes[_rng.randi() % scatter_scenes.size()]
		if scene == null:
			continue
		var pos := Vector2(
			_rng.randi_range(40, world_width - 40),
			_rng.randi_range(40, world_height - 40)
		)
		if _on_road(pos):
			continue
		_add_prop(scene, pos)

func _spawn_enemies() -> void:
	var n := _rng.randi_range(1, 2)
	for i in range(n):
		var enemy_scene := _load(_pick_enemy_path())
		if enemy_scene == null:
			continue
		# Spread along the central third of the road so they sit on it.
		var fx: float = lerp(0.3, 0.7, float(i + 1) / float(n + 1))
		var pos := Vector2(
			world_width * fx + _rng.randi_range(-40, 40),
			road_center_y + _rng.randi_range(-12, 12)
		)
		var e := enemy_scene.instantiate()
		if e is Node2D:
			e.position = pos
		_assign_loot(e)
		_entities.add_child(e)

## Weighted random pick from ENEMY_TYPES, skipping any whose scene is missing.
## Falls back to the base bandit path if nothing else is available.
func _pick_enemy_path() -> String:
	var total: float = 0.0
	for entry: Dictionary in ENEMY_TYPES:
		var path: String = entry["path"]
		if ResourceLoader.exists(path):
			total += float(entry["weight"])
	if total <= 0.0:
		return ENEMY_PATH
	var roll: float = _rng.randf() * total
	for entry: Dictionary in ENEMY_TYPES:
		var path: String = entry["path"]
		if not ResourceLoader.exists(path):
			continue
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return path
	return ENEMY_PATH

func _assign_loot(enemy: Node) -> void:
	var table: Array[Item] = []
	for path in LOOT_PATHS:
		var item := _load_item(path)
		if item != null:
			table.append(item)
	enemy.set("loot_table", table)
	enemy.set("loot_chance", 0.5)

func _load_item(path: String) -> Item:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Item

func _add_prop(scene: PackedScene, pos: Vector2) -> void:
	var inst := scene.instantiate()
	if inst is Node2D:
		inst.position = pos
	_entities.add_child(inst)

func _load(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene
