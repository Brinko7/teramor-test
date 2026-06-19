class_name PlayerVisuals
extends Node

## Owns the player's "paper-doll" cosmetics: the worn armour overlay layers and
## the held weapon/shield sprites, plus their per-frame posing, swing and recoil
## animation.
##
## Extracted from player.gd, which had grown into a ~400-line god script handling
## movement, combat, progression AND all of this rendering. The player now owns
## the gameplay state and feeds this node what it needs each frame — the body's
## animation frame, the aim direction and the block flag — and this node drives
## the cosmetic sprites. It holds references to sprites that live on the player
## scene (passed in via `setup`); it lives as a child of the player so it can
## create tweens.

## Sideways gap between the main hand (weapon) and off hand (shield), measured
## perpendicular to the aim direction so the two never overlap.
const HAND_SEPARATION := 5.0
## Anchor for both hands in local space (roughly chest height).
const HAND_ANCHOR := Vector2(0, -22)
## Held-item draw order relative to the body sprite (z 0): in front for most aims,
## behind the player when aiming north so the gear reads as held on the far side.
const HAND_Z_FRONT := 5
const HAND_Z_BEHIND := 0

## Fallbacks matching player.gd's bare-handed tunables. Only used when no weapon
## is equipped, which also hides the weapon sprite — so a swing never reaches them.
const DEFAULT_SWING_ARC := 1.1
const DEFAULT_SWING_DURATION := 0.15

var _body: Sprite2D
var _outfit: Sprite2D
var _hair: Sprite2D
var _gear_layers: Dictionary
var _weapon_pivot: Node2D
var _weapon_sprite: Sprite2D
var _shield_pivot: Node2D
var _shield_sprite: Sprite2D
var _equipment: Equipment

var _swinging: bool = false
var _swing_tween: Tween

func setup(body: Sprite2D, outfit: Sprite2D, hair: Sprite2D, gear_layers: Dictionary,
		weapon_pivot: Node2D, weapon_sprite: Sprite2D,
		shield_pivot: Node2D, shield_sprite: Sprite2D, equipment: Equipment) -> void:
	_body = body
	_outfit = outfit
	_hair = hair
	_gear_layers = gear_layers
	_weapon_pivot = weapon_pivot
	_weapon_sprite = weapon_sprite
	_shield_pivot = shield_pivot
	_shield_sprite = shield_sprite
	_equipment = equipment

func is_swinging() -> bool:
	return _swinging

## Copy the body's current animation frame onto the cosmetic overlay layers so
## the outfit, hair and worn gear walk in lockstep with the body.
func sync_frame(frame: int) -> void:
	_outfit.frame = frame
	_hair.frame = frame
	for layer: Sprite2D in _gear_layers.values():
		if layer.visible:
			layer.frame = frame

## Rebuild the equipped-gear visuals from the Equipment component: the held
## weapon, the held shield, and the worn paper-doll layers (feet/legs/body/head).
## The off-hand slot is drawn as a held item, not a body overlay, so it is skipped.
func refresh_gear() -> void:
	var weapon: WeaponItem = _equipment.get_weapon() if _equipment != null else null
	if weapon != null and weapon.held_texture() != null:
		_weapon_sprite.texture = weapon.held_texture()
		_weapon_sprite.position.x = weapon.hold_distance
		_weapon_sprite.visible = true
	else:
		_weapon_sprite.visible = false

	var shield: ArmorItem = _equipment.get_shield() if _equipment != null else null
	if shield != null and shield.hold_texture != null:
		_shield_sprite.texture = shield.hold_texture
		_shield_sprite.visible = true
	else:
		_shield_sprite.visible = false

	for slot: Variant in _gear_layers:
		var layer: Sprite2D = _gear_layers[slot]
		var piece: ArmorItem = _equipment.get_armor(slot) if _equipment != null else null
		if piece != null and piece.overlay_sheet != null:
			layer.texture = piece.overlay_sheet
			layer.frame = _body.frame
			layer.visible = true
		else:
			layer.visible = false

## Position the held weapon/shield each frame so they point at `aim` and sit in
## front of or behind the body depending on aim.
func update_pose(aim: Vector2, blocking: bool) -> void:
	var aim_angle: float = aim.angle()
	# Perpendicular to the aim: weapon on one side, shield on the other.
	var perp: Vector2 = Vector2(-aim.y, aim.x)

	# Facing north, the held items sit on the far side of the body, so draw them
	# behind the player sprite; any other aim keeps them in front.
	var hand_z: int = HAND_Z_BEHIND if aim.y < -0.35 else HAND_Z_FRONT
	_weapon_pivot.z_index = hand_z
	_shield_pivot.z_index = hand_z

	if _weapon_sprite.visible and not _swinging:
		_weapon_pivot.position = HAND_ANCHOR + perp * HAND_SEPARATION
		_weapon_pivot.rotation = aim_angle
		_weapon_sprite.flip_v = aim.x < 0.0

	if _shield_sprite.visible:
		_shield_pivot.position = HAND_ANCHOR - perp * HAND_SEPARATION
		_shield_pivot.rotation = aim_angle
		_shield_sprite.flip_v = aim.x < 0.0
		_shield_sprite.position.x = 13.0 if blocking else 8.0

## Sweep the held weapon through its swing arc, aimed at `aim`.
func swing_melee(weapon: WeaponItem, aim: Vector2) -> void:
	if not _weapon_sprite.visible:
		return
	var arc: float = weapon.swing_arc if weapon != null else DEFAULT_SWING_ARC
	var dur: float = weapon.attack_duration if weapon != null else DEFAULT_SWING_DURATION
	var base: float = aim.angle()
	_swinging = true
	_weapon_pivot.rotation = base - arc
	_weapon_sprite.flip_v = aim.x < 0.0
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.tween_property(_weapon_pivot, "rotation", base + arc, dur)
	_swing_tween.tween_callback(func() -> void: _swinging = false)

## Brief kickback on the held weapon when a ranged shot is fired.
func recoil(aim: Vector2) -> void:
	_weapon_sprite.flip_v = aim.x < 0.0
	_weapon_pivot.rotation = aim.angle()
	var rest_x: float = _weapon_sprite.position.x
	var tw := create_tween()
	tw.tween_property(_weapon_sprite, "position:x", rest_x - 4.0, 0.05)
	tw.tween_property(_weapon_sprite, "position:x", rest_x, 0.12)
