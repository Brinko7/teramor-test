extends Node2D

## Remaster slice — an ADDITIVE in-engine sandbox that runs the new Eastward-style
## player art at the remaster scale (84x120 frames, ~32px ground), with full
## 8-direction walk animation, without touching the live player/gear/combat
## systems. The development ground for the full art migration.
##
## Sheet layout matches bake_player.py: 4 cols (walk phases) x 8 rows (facings
## S, SE, E, NE, N, NW, W, SW). Walk cycles phases [0,1,0,2]; idle holds phase 0.
##
## The player is a layered PAPER-DOLL: a body sheet plus stacked armour + weapon
## OVERLAY sheets (gen_player_gear.py) that share the body's frame index, so the
## hero visibly "levels up" through gear — the new-art proof of the engine's
## existing ArmorItem.overlay_sheet / WeaponItem contract. 1/2 cycle the layers.
##
## The player and the baked props (cottage / trees / NPCs) all live under a
## y-sorted Entities node and are foot-anchored, so they depth-sort by their feet
## as the player walks behind or in front of them.

const SPEED := 96.0
const WALK := [0, 1, 0, 2]
## Octant (0=E,1=SE,..7=NE) -> sheet row (0=S,1=SE,2=E,3=NE,4=N,5=NW,6=W,7=SW).
const ROW_BY_OCT := [2, 1, 0, 7, 6, 5, 4, 3]

## Equippable overlay layers — "" means that slot is empty (no overlay shown).
const ARMOURS := ["", "res://assets/remaster/armor_leather.png",
		"res://assets/remaster/armor_plate.png"]
const WEAPONS := ["", "res://assets/remaster/weapon_sword.png",
		"res://assets/remaster/weapon_ember.png"]

@onready var _sprite: Sprite2D = $Entities/Player/Sprite
@onready var _armor: Sprite2D = $Entities/Player/Armor
@onready var _weapon: Sprite2D = $Entities/Player/Weapon
@onready var _player: Node2D = $Entities/Player

var _facing := 0
var _anim := 0.0
var _armor_idx := 2   # start in plate so the slice opens on a geared hero
var _weapon_idx := 1  # ...holding a steel sword

func _ready() -> void:
	_equip(_armor, ARMOURS, _armor_idx)
	_equip(_weapon, WEAPONS, _weapon_idx)

func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var frame := 0
	if dir.length() > 0.1:
		dir = dir.normalized()
		_player.position += dir * SPEED * delta
		_facing = _row_for(dir)
		_anim += delta * 7.0
		frame = _facing * 4 + WALK[int(_anim) % WALK.size()]
	else:
		_anim = 0.0
		frame = _facing * 4
	# every visible layer walks in lockstep on the shared frame index
	_sprite.frame = frame
	if _armor.texture != null:
		_armor.frame = frame
	if _weapon.texture != null:
		_weapon.frame = frame

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				_armor_idx = (_armor_idx + 1) % ARMOURS.size()
				_equip(_armor, ARMOURS, _armor_idx)
			KEY_2:
				_weapon_idx = (_weapon_idx + 1) % WEAPONS.size()
				_equip(_weapon, WEAPONS, _weapon_idx)

## Swap an overlay layer's sheet (or clear it when the slot is empty).
func _equip(layer: Sprite2D, paths: Array, idx: int) -> void:
	var path: String = paths[idx]
	layer.texture = (load(path) as Texture2D) if not path.is_empty() else null
	if layer.texture != null:
		layer.frame = _sprite.frame

func _row_for(dir: Vector2) -> int:
	var deg := fmod(rad_to_deg(atan2(dir.y, dir.x)) + 360.0, 360.0)
	return ROW_BY_OCT[int(round(deg / 45.0)) % 8]
