extends Node2D

## Remaster slice — an ADDITIVE in-engine sandbox that runs the new Eastward-style
## player art at the remaster scale (84x120 frames, ~32px ground), with full
## 8-direction walk animation, without touching the live player/gear/combat
## systems. The development ground for the full art migration.
##
## Sheet layout matches bake_player.py: 4 cols (walk phases) x 8 rows (facings
## S, SE, E, NE, N, NW, W, SW). Walk cycles phases [0,1,0,2]; idle holds phase 0.

const SPEED := 96.0
const WALK := [0, 1, 0, 2]
## Octant (0=E,1=SE,..7=NE) -> sheet row (0=S,1=SE,2=E,3=NE,4=N,5=NW,6=W,7=SW).
const ROW_BY_OCT := [2, 1, 0, 7, 6, 5, 4, 3]

@onready var _sprite: Sprite2D = $Player/Sprite
@onready var _player: Node2D = $Player

var _facing := 0
var _anim := 0.0

func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir.length() > 0.1:
		dir = dir.normalized()
		_player.position += dir * SPEED * delta
		_facing = _row_for(dir)
		_anim += delta * 7.0
		_sprite.frame = _facing * 4 + WALK[int(_anim) % WALK.size()]
	else:
		_anim = 0.0
		_sprite.frame = _facing * 4

func _row_for(dir: Vector2) -> int:
	var deg := fmod(rad_to_deg(atan2(dir.y, dir.x)) + 360.0, 360.0)
	return ROW_BY_OCT[int(round(deg / 45.0)) % 8]
