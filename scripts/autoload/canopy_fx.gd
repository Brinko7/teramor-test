extends CanvasLayer

## Autoload `CanopyFX`. A drifting dappled-shade overlay for wooded areas — the look
## of sunlight filtering through a thick canopy overhead. A small seamless shadow tile
## (`canopy_dapple.png`) scrolls opposite the player's motion, so you feel like you're
## moving *under* the leaves rather than past flat trees.
##
## It's **data-driven, not zone-guessed**: a procedural area turns it on when its
## `BiomeData.has_canopy` is set, so it shows in forests but not open plains/desert or
## underground caves. It fades out at night (no sun to dapple) and resets off whenever
## the zone changes (so stepping out of the woods clears it). Sits just under WeatherFX,
## over the world; the day/night fade is handled here since CanvasLayers skip the
## world's CanvasModulate.

const VW := 1280.0
const VH := 720.0
const TILE := 96.0
const PARALLAX := 0.4     # how fast the canopy drifts against the player's motion
const STRENGTH := 0.5     # peak opacity at midday

var _dapple: Sprite2D
var _on: bool = false
var _tween: Tween

func _ready() -> void:
	layer = 77  # under WeatherFX (79), over the world (0)
	_dapple = Sprite2D.new()
	_dapple.texture = load("res://assets/placeholder/canopy_dapple.png")
	_dapple.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_dapple.region_enabled = true
	_dapple.region_rect = Rect2(0, 0, VW + TILE * 2.0, VH + TILE * 2.0)
	_dapple.centered = false
	_dapple.modulate = Color(1, 1, 1, 0)
	add_child(_dapple)
	TimeManager.period_changed.connect(func(_p: int) -> void: _refresh())
	MusicManager.zone_changed.connect(func(_z: StringName) -> void: set_canopy(false))
	set_process(false)

## Turn the canopy on/off for the current area. A forest procedural area calls this
## with its biome's `has_canopy`; it is also reset off on every zone change so the
## overlay never lingers into a town or cave.
func set_canopy(on: bool) -> void:
	if _on == on:
		return
	_on = on
	set_process(on)
	_refresh()

func _refresh() -> void:
	var target: float = STRENGTH * _day_factor() if _on else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_dapple, "modulate:a", target, 1.0)

## Sunlight only dapples in daylight — full by day, soft at dusk, gone at night.
func _day_factor() -> float:
	match TimeManager.get_period():
		TimeManager.Period.MORNING, TimeManager.Period.AFTERNOON:
			return 1.0
		TimeManager.Period.EVENING:
			return 0.4
		_:
			return 0.0

func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	# Scroll the tile opposite the player so the canopy reads as fixed overhead;
	# fposmod keeps it within one tile for a seamless wrap.
	var o: Vector2 = -p.global_position * PARALLAX
	_dapple.position = Vector2(fposmod(o.x, TILE) - TILE, fposmod(o.y, TILE) - TILE)
