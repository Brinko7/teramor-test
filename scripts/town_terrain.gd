extends Node2D
## Paints Cleeve's Landing's streets onto the sibling `Terrain` TileMapLayer and
## clamps the follow-camera to the map bounds. The town is an urban grid: a wide
## cobble avenue runs south-to-north up the middle to a central market plaza,
## crossed by two cobble cross-streets (a trade row up top and a residential row
## below), with dirt footpaths fanning out to the buildings. Only the paint is
## scripted so the hand-placed buildings stay editable.

const TILE_DIRT := 2
const TILE_COBBLE := 3
const TILE_SOURCE := 0
const TILE := 16

@export var town_width: int = 960
@export var town_height: int = 720
## Camera clamp bounds (pixels); matches the grass ground / wall perimeter.
@export var map_size: Vector2i = Vector2i(960, 720)

var _terrain: TileMapLayer = null

func _ready() -> void:
	# Tag this scene as the player's current world location for the map/fast travel.
	WorldMap.discover(&"cleaves_landing")
	WorldMap.set_current(&"cleaves_landing")
	_terrain = get_node_or_null("Terrain") as TileMapLayer
	if _terrain != null:
		_paint_streets()
	_clamp_camera()

func _paint_streets() -> void:
	var cols := int(town_width / TILE)
	var rows := int(town_height / TILE)
	var center_cx := int(cols / 2)

	# Vertical cobble avenue (4 cells wide), full height from the south gate up.
	_fill(center_cx - 2, 1, center_cx + 1, rows - 2, TILE_COBBLE)

	# Trade-row cross street (upper third) and residential cross street (lower).
	var trade_cy := 15
	var res_cy := 31
	_fill(4, trade_cy, cols - 5, trade_cy + 1, TILE_COBBLE)
	_fill(6, res_cy, cols - 7, res_cy + 1, TILE_COBBLE)

	# Central market plaza (cobble square around the well).
	_fill(center_cx - 7, 17, center_cx + 7, 26, TILE_COBBLE)

	# Dirt footpaths fanning from the plaza to the north landmark buildings.
	_fill(16, 11, 17, 17, TILE_DIRT)
	_fill(center_cx + 12, 11, center_cx + 13, 17, TILE_DIRT)

func _fill(cx0: int, cy0: int, cx1: int, cy1: int, tile: int) -> void:
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			_terrain.set_cell(Vector2i(cx, cy), TILE_SOURCE, Vector2i(tile, 0))

func _clamp_camera() -> void:
	var cam := get_node_or_null("Entities/Player/Camera2D") as Camera2D
	if cam == null:
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			cam = p.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = map_size.x
		cam.limit_bottom = map_size.y
