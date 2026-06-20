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
##
## Weapons and shields are not wielded at all times. By default they ride the
## body as directional "stowed" overlays — a sword in a hip scabbard, a bow or
## shield slung on the back — synced to the walk frame like worn armour. They are
## only drawn into the hand for the moment of an attack (weapon) or while the
## block is held (shield), then returned to the body.

## Sideways gap between the main hand (weapon) and off hand (shield), measured
## perpendicular to the aim direction so the two never overlap.
const HAND_SEPARATION := 5.0
## Anchor for both hands in local space (roughly chest height).
const HAND_ANCHOR := Vector2(0, -22)
## Held-item draw order relative to the body sprite (z 0): in front for most aims,
## behind the player when aiming north so the gear reads as held on the far side.
const HAND_Z_FRONT := 5
const HAND_Z_BEHIND := 0
## How long the drawn weapon lingers in hand after a swing/shot before it is
## returned to its holster, so rapid attacks don't flicker the scabbard.
const STOW_DELAY := 0.12

var _body: Sprite2D
var _outfit: Sprite2D
var _hair: Sprite2D
var _gear_layers: Dictionary
var _weapon_pivot: Node2D
var _weapon_sprite: Sprite2D
var _shield_pivot: Node2D
var _shield_sprite: Sprite2D
var _equipment: Equipment
## Directional overlays drawn on the body while the gear is stowed (not in use).
var _weapon_holster: Sprite2D
var _shield_back: Sprite2D
## Forearm sprite that rides the weapon pivot so a swing moves an arm, not just
## the blade. Shown only while the weapon is drawn.
var _attack_arm: Sprite2D

## True while a swing tween is actively rotating the weapon.
var _swinging: bool = false
## True while the weapon is out of its holster (mid-attack), false when stowed.
var _weapon_drawn: bool = false
var _swing_tween: Tween

func setup(body: Sprite2D, outfit: Sprite2D, hair: Sprite2D, gear_layers: Dictionary,
		weapon_pivot: Node2D, weapon_sprite: Sprite2D,
		shield_pivot: Node2D, shield_sprite: Sprite2D, equipment: Equipment,
		weapon_holster: Sprite2D, shield_back: Sprite2D, attack_arm: Sprite2D) -> void:
	_body = body
	_outfit = outfit
	_hair = hair
	_gear_layers = gear_layers
	_weapon_pivot = weapon_pivot
	_weapon_sprite = weapon_sprite
	_shield_pivot = shield_pivot
	_shield_sprite = shield_sprite
	_equipment = equipment
	_weapon_holster = weapon_holster
	_shield_back = shield_back
	_attack_arm = attack_arm

func is_swinging() -> bool:
	return _swinging

## Copy the body's current animation frame onto the cosmetic overlay layers so
## the outfit, hair, worn gear and stowed weapon/shield walk in lockstep with the
## body.
func sync_frame(frame: int) -> void:
	_outfit.frame = frame
	_hair.frame = frame
	for layer: Sprite2D in _gear_layers.values():
		if layer.visible:
			layer.frame = frame
	if _weapon_holster.visible:
		_weapon_holster.frame = frame
	if _shield_back.visible:
		_shield_back.frame = frame

## Rebuild the equipped-gear visuals from the Equipment component: the held
## weapon and shield (kept hidden until drawn), their stowed body overlays, and
## the worn paper-doll layers (feet/legs/body/head).
func refresh_gear() -> void:
	var weapon: WeaponItem = _equipment.get_weapon() if _equipment != null else null
	if weapon != null and weapon.held_texture() != null:
		_weapon_sprite.texture = weapon.held_texture()
		_weapon_sprite.position.x = weapon.hold_distance
	_weapon_sprite.visible = false
	_attack_arm.visible = false
	_weapon_drawn = false
	_swinging = false
	if weapon != null and weapon.stow_texture != null:
		_weapon_holster.texture = weapon.stow_texture
		_weapon_holster.frame = _body.frame
		_weapon_holster.visible = true
	else:
		_weapon_holster.visible = false

	var shield: ArmorItem = _equipment.get_shield() if _equipment != null else null
	if shield != null and shield.hold_texture != null:
		_shield_sprite.texture = shield.hold_texture
	_shield_sprite.visible = false
	if shield != null and shield.back_texture != null:
		_shield_back.texture = shield.back_texture
		_shield_back.frame = _body.frame
		_shield_back.visible = true
	else:
		_shield_back.visible = false

	for slot: Variant in _gear_layers:
		var layer: Sprite2D = _gear_layers[slot]
		var piece: ArmorItem = _equipment.get_armor(slot) if _equipment != null else null
		if piece != null and piece.overlay_sheet != null:
			layer.texture = piece.overlay_sheet
			layer.frame = _body.frame
			layer.visible = true
		else:
			layer.visible = false

## Each frame: decide whether the weapon/shield are stowed on the body or held in
## hand, and pose whatever is held so it points at `aim`.
func update_pose(aim: Vector2, blocking: bool) -> void:
	var aim_angle: float = aim.angle()
	var perp: Vector2 = Vector2(-aim.y, aim.x)
	var flip: bool = aim.x < 0.0

	# Facing north, the held items sit on the far side of the body, so draw them
	# behind the player sprite; any other aim keeps them in front.
	var hand_z: int = HAND_Z_BEHIND if aim.y < -0.35 else HAND_Z_FRONT
	_weapon_pivot.z_index = hand_z
	_shield_pivot.z_index = hand_z

	_pose_shield(aim_angle, perp, flip, blocking)
	_pose_weapon(aim_angle, perp, flip)

## Shield: slung on the back, raised onto the arm only while blocking. A shield
## without back art falls back to being permanently in hand.
func _pose_shield(aim_angle: float, perp: Vector2, flip: bool, blocking: bool) -> void:
	var shield: ArmorItem = _equipment.get_shield() if _equipment != null else null
	if shield == null:
		_shield_back.visible = false
		_shield_sprite.visible = false
		return
	if blocking or shield.back_texture == null:
		_shield_back.visible = false
		_shield_sprite.visible = true
		_shield_pivot.position = HAND_ANCHOR - perp * HAND_SEPARATION
		_shield_pivot.rotation = aim_angle
		_shield_sprite.flip_v = flip
		_shield_sprite.position.x = 13.0 if blocking else 8.0
	else:
		_shield_back.visible = true
		_shield_sprite.visible = false

## Weapon: stowed on the body, drawn into the hand on an extended arm only while
## attacking. A weapon without stow art falls back to being permanently in hand.
func _pose_weapon(aim_angle: float, perp: Vector2, flip: bool) -> void:
	var weapon: WeaponItem = _equipment.get_weapon() if _equipment != null else null
	var has_held: bool = weapon != null and weapon.held_texture() != null
	var has_stow: bool = weapon != null and weapon.stow_texture != null
	if _weapon_drawn:
		_weapon_holster.visible = false
		_weapon_sprite.visible = has_held
		_attack_arm.visible = has_held
		if has_held and not _swinging:
			_weapon_pivot.position = HAND_ANCHOR + perp * HAND_SEPARATION
			_weapon_pivot.rotation = aim_angle
			_weapon_sprite.flip_v = flip
			_attack_arm.flip_v = flip
	else:
		_weapon_holster.visible = has_stow
		_attack_arm.visible = false
		_weapon_sprite.visible = has_held and not has_stow
		if _weapon_sprite.visible:
			_weapon_pivot.position = HAND_ANCHOR + perp * HAND_SEPARATION
			_weapon_pivot.rotation = aim_angle
			_weapon_sprite.flip_v = flip

## Sweep the held weapon through its swing arc, aimed at `aim`. Draws the weapon
## from its holster onto the swinging arm, then re-stows it once the swing settles.
func swing_melee(weapon: WeaponItem, aim: Vector2) -> void:
	if weapon == null or weapon.held_texture() == null:
		return
	var arc: float = weapon.swing_arc
	var dur: float = weapon.attack_duration
	var base: float = aim.angle()
	var perp: Vector2 = Vector2(-aim.y, aim.x)
	_draw_weapon()
	_swinging = true
	_weapon_pivot.position = HAND_ANCHOR + perp * HAND_SEPARATION
	_weapon_pivot.rotation = base - arc
	_weapon_sprite.flip_v = aim.x < 0.0
	_attack_arm.flip_v = aim.x < 0.0
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.tween_property(_weapon_pivot, "rotation", base + arc, dur)
	_swing_tween.tween_callback(func() -> void: _swinging = false)
	_swing_tween.tween_interval(STOW_DELAY)
	_swing_tween.tween_callback(_stow_weapon)

## Brief kickback on the held weapon when a ranged shot is fired. Draws the bow
## from the back, kicks it, then re-stows.
func recoil(aim: Vector2) -> void:
	var weapon: WeaponItem = _equipment.get_weapon() if _equipment != null else null
	if weapon == null or weapon.held_texture() == null:
		return
	var perp: Vector2 = Vector2(-aim.y, aim.x)
	_draw_weapon()
	_weapon_pivot.position = HAND_ANCHOR + perp * HAND_SEPARATION
	_weapon_pivot.rotation = aim.angle()
	_weapon_sprite.flip_v = aim.x < 0.0
	_attack_arm.flip_v = aim.x < 0.0
	var rest_x: float = weapon.hold_distance
	_weapon_sprite.position.x = rest_x
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.tween_property(_weapon_sprite, "position:x", rest_x - 4.0, 0.05)
	_swing_tween.tween_property(_weapon_sprite, "position:x", rest_x, 0.12)
	_swing_tween.tween_interval(STOW_DELAY)
	_swing_tween.tween_callback(_stow_weapon)

## Pull the weapon out of its holster into the hand for an attack.
func _draw_weapon() -> void:
	_weapon_drawn = true
	_weapon_holster.visible = false
	var weapon: WeaponItem = _equipment.get_weapon() if _equipment != null else null
	var has_held: bool = weapon != null and weapon.held_texture() != null
	_weapon_sprite.visible = has_held
	_attack_arm.visible = has_held

## Return the weapon to its holster once the attack animation settles. Visibility
## flips back on the next update_pose.
func _stow_weapon() -> void:
	_weapon_drawn = false
	_swinging = false
