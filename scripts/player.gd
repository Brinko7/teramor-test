extends CharacterBody2D

## Top-down ranger player. Body sprite sheet is a 4x4 grid (cols = walk frames,
## rows = facing: 0=down, 1=up, 2=left, 3=right). Combat is mouse-driven: the
## player aims at the cursor, left-click attacks/fires, right-click raises a
## shield (if one is equipped). Equipped gear is drawn on the body.

@export var speed: float = 70.0
@export var anim_fps: float = 8.0

## --- Combat tunables (fallback when no weapon is equipped) ---
@export var attack_power: int = 4
@export var attack_duration: float = 0.15
@export var attack_cooldown: float = 0.35
@export var invuln_time: float = 0.5

const ARROW_SCENE := preload("res://scenes/entities/arrow.tscn")

## Starting kit, set in the player scene. The weapon is auto-equipped; the
## rest land in the bag.
@export var starting_weapon: WeaponItem
@export var starting_items: Array[Item] = []

## Column order of the walk cycle. The facing row comes from DirUtil, which reads
## the sprite's vframes (4 = the remaster cardinal rig: down/up/left/right). The
## 4-dir model uses all four phases (0 rest, 1 stride, 2 rest, 3 counter-stride).
const WALK_FRAMES := [0, 1, 2, 3]
## Preloaded so the global-class dependency resolves before this script
## compiles — avoids the editor's "DirUtil not declared" partial-reload error.
const DIR_UTIL := preload("res://scripts/dir_util.gd")

## How far the melee hitbox sits from the player along the aim direction (scaled to
## the 84x120 hero's reach), and the bow's draw time before the arrow looses.
const HITBOX_REACH := 42.0
const BOW_DRAW_TIME := 0.12
## Melee swing played as body frames (cols 4-7 of the 8-col sheet): wind-up, strike,
## follow-through, recover. Per-frame durations; the hit + slash + lunge land on the
## STRIKE frame so damage connects exactly when the blade sweeps across.
const ATTACK_FRAME_TIME: Array[float] = [0.07, 0.07, 0.06, 0.08]
const ATTACK_STRIKE_FRAME := 1
## Bow draw played as body frames (cols 8-10): nock, draw-back, loose. The arrow
## fires on the loose frame, so it leaves the bow exactly as the string snaps forward.
const DRAW_FRAME_TIME: Array[float] = [1.5, 2.5, 0.6]
const DRAW_LOOSE_FRAME := 2

## Combat-feel tunables: melee knockback dealt to foes, and the player's own
## forward lunge on a melee swing.
const MELEE_KNOCKBACK := 175.0
const LUNGE_SPEED := 95.0
const LUNGE_DECAY := 620.0
## Seconds between footstep dust puffs while moving.
const STEP_INTERVAL := 0.28

## Dodge-roll tunables. A burst dash in the move/aim direction with invulnerability
## (i-frames) over most of it, then a short recovery before you can roll again. The
## defensive verb the combat needed — read an enemy's wind-up, roll through the hit.
const DODGE_SPEED := 230.0
const DODGE_END_SPEED := 70.0
const DODGE_DURATION := 0.22
const DODGE_IFRAMES := 0.17
const DODGE_COOLDOWN := 0.40

@onready var sprite: Sprite2D = $Sprite2D
@onready var outfit_sprite: Sprite2D = $Outfit
@onready var hair_sprite: Sprite2D = $Hair
@onready var beard_sprite: Sprite2D = $Beard
## Remaster cloak layers: the cape behind the body and the mantle/collar over it.
@onready var cloak_back_sprite: Sprite2D = $CloakBack
@onready var collar_sprite: Sprite2D = $Collar
## Helm layer (over the hair) for armour sets that include one.
@onready var helm_sprite: Sprite2D = $Helm
## Melee weapon overlay (the blade riding the swinging hand) — cols 4-7 of the
## 8-col sheet, synced to the body's attack frame. Hidden except mid-swing.
@onready var weapon_overlay: Sprite2D = $WeaponOverlay
@onready var gear_layers: Dictionary = {
	ArmorItem.ArmorSlot.FEET: $GearFeet,
	ArmorItem.ArmorSlot.LEGS: $GearLegs,
	ArmorItem.ArmorSlot.BODY: $GearBody,
	ArmorItem.ArmorSlot.HEAD: $GearHead,
}
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite
@onready var attack_arm: Sprite2D = $WeaponPivot/AttackArm
@onready var shield_pivot: Node2D = $ShieldPivot
@onready var shield_sprite: Sprite2D = $ShieldPivot/ShieldSprite
## Directional "stowed gear" overlays, shown when the weapon/shield is not in use.
@onready var weapon_holster: Sprite2D = $WeaponHolster
@onready var shield_back: Sprite2D = $ShieldBack
@onready var health: Health = $Health
@onready var interact_probe: Area2D = $InteractProbe
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var inventory: Inventory = $Inventory
@onready var equipment: Equipment = $Equipment
@onready var stats: Stats = $Stats
@onready var mana: Mana = get_node_or_null("Mana")
@onready var ability_caster: AbilityCaster = get_node_or_null("AbilityCaster")
@onready var item_hotbar: ItemHotbar = get_node_or_null("ItemHotbar")

var _facing_row: int = 0
var _aim: Vector2 = Vector2.DOWN
var _anim_time: float = 0.0
var _attack_timer: float = 0.0
## Melee swing animation: true mid-swing, the elapsed time into it, whether the hit
## has already landed this swing, and the committed swing direction.
var _attacking: bool = false
var _attack_time: float = 0.0
var _attack_struck: bool = false
var _attack_aim: Vector2 = Vector2.DOWN
## True when the current attack is a bow draw (cols 8-10) rather than a melee swing.
var _ranged: bool = false
var _cooldown_timer: float = 0.0
var _invuln_timer: float = 0.0
var _blocking: bool = false
var _hit_enemies: Array = []
## Decaying forward step applied during a melee swing for weighty hits.
var _lunge: Vector2 = Vector2.ZERO
## Footstep-dust cadence timer.
var _step_timer: float = 0.0
## Dodge state: dash time left, invulnerability time left, cooldown, and direction.
var _dodge_timer: float = 0.0
var _iframe_timer: float = 0.0
var _dodge_cd: float = 0.0
var _dodge_dir: Vector2 = Vector2.DOWN
## Cosmetic rendering (worn gear, held weapon/shield), created in _ready().
var _visuals: PlayerVisuals
## Scene-placed start position, used as the respawn point after death.
var _home_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	add_to_group("persistent")
	hitbox.monitoring = false
	hitbox_shape.disabled = true
	_visuals = PlayerVisuals.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_visuals.setup(sprite, outfit_sprite, hair_sprite, gear_layers,
		weapon_pivot, weapon_sprite, shield_pivot, shield_sprite, equipment,
		weapon_holster, shield_back, attack_arm, beard_sprite)
	# The remaster model bakes the outfit/cloak into its own layers, so the old
	# 24x40 worn-armour + stowed-gear overlays are off (weapon/shield are drawn-
	# only). Phase 0b restores visible gear as full armour-set swaps.
	_visuals.legacy_body_overlays = false
	equipment.changed.connect(_visuals.refresh_gear)
	equipment.changed.connect(_apply_armor_set)
	equipment.changed.connect(_on_gear_changed)
	# Progression wiring: earn XP from kills, scale Health to leveled max HP.
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_leveled_up.connect(_on_player_leveled_up)
	health.died.connect(_on_died)
	health.max_health = _max_hp()
	health.health = health.max_health
	_home_position = global_position
	PlayerProfile.changed.connect(_apply_appearance)
	_apply_appearance()
	_apply_armor_set()
	_grant_starting_kit()
	# Top off to the full pool now that starting gear (and its HP affixes) is on.
	health.health = health.max_health
	_visuals.refresh_gear()
	stats.skills_changed.connect(_on_skills_changed)
	_sync_abilities()

## Max HP from level/attributes/skills plus equipped-gear HP affixes.
func _max_hp() -> int:
	return stats.max_hp + (equipment.bonus_max_hp() if equipment != null else 0)

## Equipped gear changed: resize the health pool to include gear HP affixes.
func _on_gear_changed() -> void:
	health.max_health = _max_hp()
	health.health = mini(health.health, health.max_health)
	health.health_changed.emit(health.health, health.max_health)

## Paints the remaster paper-doll from the chosen identity: the body sheet is
## picked by skin tone (full colour, no modulate, so the eyes stay right); the
## hair/beard layers swap by style and tint by hair colour.
func _apply_appearance() -> void:
	sprite.texture = PlayerProfile.body_layer()
	sprite.modulate = Color.WHITE
	hair_sprite.texture = PlayerProfile.hair_layer()
	hair_sprite.modulate = PlayerProfile.hair_color
	var beard_tex := PlayerProfile.beard_layer()
	beard_sprite.texture = beard_tex
	beard_sprite.visible = beard_tex != null
	beard_sprite.modulate = PlayerProfile.hair_color
	if beard_tex != null:
		beard_sprite.frame = sprite.frame

## The equipped chest (BODY) piece drives the visible armour SET: its `armor_set`
## swaps the outfit / helm / cloak layers to that set's baked sheets. No chest, or an
## untagged one, shows the default ranger kit. Helm and cloak layers hide for sets
## that lack them.
func _apply_armor_set() -> void:
	var chest: ArmorItem = equipment.get_armor(ArmorItem.ArmorSlot.BODY) if equipment != null else null
	var set_id: String = "ranger"
	if chest != null and chest.armor_set != &"":
		set_id = String(chest.armor_set)
	_set_layer(outfit_sprite, "outfit_%s" % set_id, "outfit_ranger")
	_set_layer(helm_sprite, "helm_%s" % set_id, "")
	_set_layer(cloak_back_sprite, "cloakback_%s" % set_id, "")
	_set_layer(collar_sprite, "collar_%s" % set_id, "")

## Point a paper-doll layer at `char/<name>.png`. If it's missing, use `fallback`
## (or hide the layer when fallback is empty). Keeps the frame synced.
func _set_layer(layer: Sprite2D, layer_name: String, fallback: String) -> void:
	var path := PlayerProfile.REMASTER_CHAR + layer_name + ".png"
	if not ResourceLoader.exists(path):
		path = (PlayerProfile.REMASTER_CHAR + fallback + ".png") if fallback != "" else ""
	if path == "" or not ResourceLoader.exists(path):
		layer.visible = false
		return
	layer.texture = load(path) as Texture2D
	layer.visible = true
	layer.frame = sprite.frame

func _grant_starting_kit() -> void:
	if starting_weapon != null:
		equipment.equip_weapon(starting_weapon)
	for it in starting_items:
		if it == null:
			continue
		# Auto-equip armor into any empty slot; everything else goes in the bag.
		if it is ArmorItem and equipment.get_armor((it as ArmorItem).armor_slot) == null:
			equipment.equip_armor(it as ArmorItem)
		else:
			inventory.add_item(it, 1)

func _physics_process(delta: float) -> void:
	if health.is_dead():
		velocity = Vector2.ZERO
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_iframe_timer = maxf(0.0, _iframe_timer - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)

	_update_aim()

	if Input.is_action_just_pressed("dodge") and _can_dodge():
		_start_dodge()

	if _attacking:
		_update_attack_anim(delta)

	# Only the melee path enables the hitbox; ranged attacks never do, so gate
	# the scan on monitoring to avoid querying a disabled area.
	if hitbox.monitoring:
		if _attack_timer > 0.0:
			_scan_hitbox()
		else:
			_end_attack()

	_blocking = _dodge_timer <= 0.0 and Input.is_action_pressed("attack_secondary") and equipment.get_shield() != null

	if _dodge_timer <= 0.0 and _primary_pressed() and _cooldown_timer <= 0.0 and not _blocking and not UIManager.dialogue.is_active():
		_start_attack()

	_handle_hotbar_input()

	_movement(delta)
	_update_gear_pose()

## The number row is modal: holding the ability key (Q) turns 1–4 into spell
## casts (the radial wheel is shown by the ability HUD while held); otherwise the
## keys 1–0 drive the item hotbar — select a slot, wheel to cycle, [F] to use the
## held item. Splitting on Q means items and abilities never fight over the keys.
func _handle_hotbar_input() -> void:
	if UIManager.dialogue.is_active():
		return
	if Input.is_action_pressed("ability_menu"):
		_cast_radial_abilities()
	else:
		_drive_item_hotbar()

## Casts an unlocked ability when its 1–4 key is tapped while the radial is open,
## aimed at the cursor. The AbilityCaster enforces mana and cooldown.
func _cast_radial_abilities() -> void:
	if ability_caster == null:
		return
	var slots: int = mini(ability_caster.slot_count(), 4)
	for slot in range(slots):
		if Input.is_action_just_pressed("ability_%d" % (slot + 1)):
			ability_caster.cast(slot, global_position + Vector2(0, -10), _aim)

func _drive_item_hotbar() -> void:
	if item_hotbar == null:
		return
	for i in range(ItemHotbar.SIZE):
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			item_hotbar.select(i)
	if Input.is_action_just_pressed("hotbar_next"):
		item_hotbar.cycle(1)
	if Input.is_action_just_pressed("hotbar_prev"):
		item_hotbar.cycle(-1)
	if Input.is_action_just_pressed("use_item"):
		# Consumables drink; otherwise a held tool/seed acts on what you face.
		if not item_hotbar.use_active(self):
			_use_held_on_facing()

## A held tool or seed acts on the interactable the player is facing — till/water/
## harvest a plot, mine/chop a vein, cast at a fishing spot, or plant a seed. The
## quiet verbs of the cozy half, surfaced through the same F key.
func _use_held_on_facing() -> void:
	if item_hotbar == null:
		return
	var item: Item = item_hotbar.active_item()
	if item is ToolItem:
		_apply_tool((item as ToolItem).tool_kind)
	elif item is SeedItem:
		_plant_facing(item as SeedItem)

func _apply_tool(kind: StringName) -> void:
	var target := _nearest_tool_target()
	if target != null and target.has_method("use_tool") and target.use_tool(kind, self):
		_swing_tool()
		Events.tool_used.emit(kind, (target as Node2D).global_position)

func _plant_facing(seed: SeedItem) -> void:
	if seed.crop == null:
		return
	var target := _nearest_tool_target()
	if target != null and target.has_method("try_plant") and target.try_plant(seed.crop, self):
		inventory.consume_items(seed.id, 1)
		_swing_tool()
		Events.tool_used.emit(&"plant", (target as Node2D).global_position)

## The nearest tool-able object within arm's reach. Unlike interaction (E, which
## follows the mouse-aimed probe), tools work by **proximity** — stand on/next to a
## plot, vein, tree or pond and use it, Stardew-style, without precise aiming.
const TOOL_REACH := 30.0
func _nearest_tool_target() -> Node2D:
	var best: Node2D = null
	var best_d := TOOL_REACH * TOOL_REACH
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node2D) or not (n.has_method("use_tool") or n.has_method("try_plant")):
			continue
		var d := global_position.distance_squared_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

## Visibly swing the held tool toward the aim — the tool's bag icon stands in for an
## in-hand sprite for now, plus a small forward nudge.
func _swing_tool() -> void:
	var item: Item = item_hotbar.active_item() if item_hotbar != null else null
	if item != null and item.icon != null and _visuals != null:
		_visuals.swing_tool(item.icon, _aim)
	_lunge = _aim * 36.0

func _primary_pressed() -> bool:
	return Input.is_action_just_pressed("attack_primary") or Input.is_action_just_pressed("attack")

func _update_aim() -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		_aim = to_mouse.normalized()

func _unhandled_input(event: InputEvent) -> void:
	# Interact is event-driven (not polled) so the dialogue box can consume the
	# closing key press via set_input_as_handled(), preventing an instant reopen.
	if event.is_action_pressed("interact") and not UIManager.dialogue.is_active():
		_try_interact()

## The raw WASD/arrow movement vector this frame (clamped to unit length).
func _move_input() -> Vector2:
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	return input.normalized() if input.length() > 1.0 else input

func _movement(delta: float) -> void:
	# A dodge overrides normal movement: a decaying dash along the committed
	# direction, facing the roll. Footsteps/lunge are suppressed for the roll.
	if _dodge_timer > 0.0:
		var t: float = 1.0 - _dodge_timer / DODGE_DURATION
		velocity = _dodge_dir * lerpf(DODGE_SPEED, DODGE_END_SPEED, t)
		move_and_slide()
		_update_facing(_dodge_dir)
		_update_animation(delta, true)
		return

	var input := _move_input()

	velocity = input * speed + _lunge
	move_and_slide()
	_lunge = _lunge.move_toward(Vector2.ZERO, LUNGE_DECAY * delta)

	var moving: bool = input.length() > 0.01
	_emit_footstep(delta, moving)

	# Face where you're moving; when standing still, face the cursor.
	_update_facing(input if input != Vector2.ZERO else _aim)
	_update_animation(delta, moving)

## Kick up a dust puff at the feet on a step cadence while moving.
func _emit_footstep(delta: float, moving: bool) -> void:
	_step_timer -= delta
	if not moving:
		_step_timer = minf(_step_timer, 0.0)
		return
	if _step_timer <= 0.0:
		_step_timer = STEP_INTERVAL
		Events.step_puff.emit(global_position)

func _update_facing(dir: Vector2) -> void:
	if _attacking or dir == Vector2.ZERO:
		return  # facing is committed to the swing direction while attacking
	_facing_row = DIR_UTIL.row_for(dir, sprite.vframes)

func _update_animation(delta: float, moving: bool) -> void:
	if _attacking:
		return  # the swing owns every layer's frame while it plays
	if moving:
		_anim_time += delta * anim_fps
	else:
		_anim_time = 0.0
	var col: int = WALK_FRAMES[int(_anim_time) % WALK_FRAMES.size()] if moving else 0
	sprite.frame = _facing_row * sprite.hframes + col
	cloak_back_sprite.frame = sprite.frame
	collar_sprite.frame = sprite.frame
	helm_sprite.frame = sprite.frame
	_visuals.sync_frame(sprite.frame)

# --- Equipped-gear visuals --------------------------------------------------

## Aims the interaction probe at the cursor, then lets the visuals component pose
## the held weapon/shield. Gear rendering itself lives in PlayerVisuals.
func _update_gear_pose() -> void:
	interact_probe.position = _aim * 10.0
	_visuals.update_pose(_aim, _blocking)

# --- Combat / interaction ---------------------------------------------------

## The nearest interactable in front of the player (the interact probe sits at the
## aim direction), or null. Shared by interact (E) and tool/seed use (F).
func _faced_interactable() -> Area2D:
	var nearest: Area2D = null
	var nearest_d := INF
	for area in interact_probe.get_overlapping_areas():
		if not area.is_in_group("interactable"):
			continue
		var d := global_position.distance_squared_to(area.global_position)
		if d < nearest_d:
			nearest_d = d
			nearest = area
	return nearest

func _try_interact() -> void:
	var nearest := _faced_interactable()
	if nearest != null and nearest.has_method("interact"):
		nearest.interact(self)

## Resolves the active weapon, or null for bare-handed.
func _current_weapon() -> WeaponItem:
	return equipment.get_weapon() if equipment != null else null

func _start_attack() -> void:
	var weapon: WeaponItem = _current_weapon()
	_cooldown_timer = weapon.attack_cooldown if weapon != null else attack_cooldown
	# Both melee and ranged play as body frames: melee swings the blade (cols 4-7),
	# ranged draws the bow (cols 8-10). _update_attack_anim drives the frames and
	# lands the hit (melee strike) / looses the arrow (bow release) on the key frame.
	_attacking = true
	_attack_time = 0.0
	_attack_struck = false
	_attack_aim = _aim  # commit the aim + facing for the duration of this attack
	_ranged = weapon != null and weapon.is_ranged()
	_facing_row = DIR_UTIL.row_for(_aim, sprite.vframes)
	if weapon != null and weapon.attack_sheet != null:
		weapon_overlay.texture = weapon.attack_sheet
		weapon_overlay.visible = true
	else:
		weapon_overlay.visible = false

## Advance the melee swing: drive every paper-doll layer to the current attack column
## and, on the strike frame, open the hitbox + spawn the slash + lunge (once).
func _update_attack_anim(delta: float) -> void:
	_attack_time += delta
	var times: Array[float] = DRAW_FRAME_TIME if _ranged else ATTACK_FRAME_TIME
	var base_col: int = 8 if _ranged else 4
	var total: float = 0.0
	for d: float in times:
		total += d
	var acc: float = 0.0
	var idx: int = times.size() - 1
	for i in times.size():
		acc += times[i]
		if _attack_time < acc:
			idx = i
			break
	var frame: int = _facing_row * sprite.hframes + (base_col + idx)
	sprite.frame = frame
	cloak_back_sprite.frame = frame
	collar_sprite.frame = frame
	helm_sprite.frame = frame
	weapon_overlay.frame = frame
	_visuals.sync_frame(frame)
	if _ranged:
		# Loose the arrow on the release frame — it leaves as the string snaps forward.
		if not _attack_struck and idx >= DRAW_LOOSE_FRAME:
			_attack_struck = true
			var bow: WeaponItem = _current_weapon()
			if bow != null:
				_fire_projectile(bow)
			_lunge = -_attack_aim * 18.0  # slight recoil step
	elif not _attack_struck and idx >= ATTACK_STRIKE_FRAME:
		# Land the hit + slash + lunge on the strike frame.
		_attack_struck = true
		_hit_enemies.clear()
		hitbox.position = _attack_aim * HITBOX_REACH
		hitbox.monitoring = true
		hitbox_shape.disabled = false
		_attack_timer = ATTACK_FRAME_TIME[ATTACK_STRIKE_FRAME] + ATTACK_FRAME_TIME[ATTACK_STRIKE_FRAME + 1]
		_lunge = _attack_aim * LUNGE_SPEED  # weighty step into the strike
		Events.melee_swung.emit(global_position + _attack_aim * (HITBOX_REACH + 12.0) + Vector2(0, -46), _attack_aim, true)
	if _attack_time >= total:
		_attacking = false
		weapon_overlay.visible = false

func _fire_projectile(weapon: WeaponItem) -> void:
	var arrow := ARROW_SCENE.instantiate() as Projectile
	arrow.global_position = global_position + _aim * 8.0 + Vector2(0, -10)
	var ranged_dmg: int = weapon.damage + stats.ranged_power() + (equipment.bonus_ranged() if equipment != null else 0)
	arrow.setup(_aim, ranged_dmg, weapon.projectile_speed, weapon.range)
	get_parent().add_child(arrow)

func _end_attack() -> void:
	hitbox.monitoring = false
	hitbox_shape.disabled = true
	_hit_enemies.clear()

func _scan_hitbox() -> void:
	for body in hitbox.get_overlapping_bodies():
		_apply_hit(body)
	for area in hitbox.get_overlapping_areas():
		_apply_hit(area.get_parent())

func _apply_hit(target) -> void:
	if target == null or target in _hit_enemies:
		return
	if target.is_in_group("enemy") and target.has_method("take_damage"):
		var weapon: WeaponItem = _current_weapon()
		var weapon_dmg: int = weapon.damage if weapon != null else attack_power
		# Base (level + attributes + skills), the weapon's flat damage, and gear affixes.
		var dmg: int = stats.attack_power() + weapon_dmg + (equipment.bonus_melee() if equipment != null else 0)
		_hit_enemies.append(target)
		target.take_damage(dmg, _aim * MELEE_KNOCKBACK, true)
		var steal: float = equipment.lifesteal() if equipment != null else 0.0
		if steal > 0.0:
			health.heal(maxi(1, int(round(dmg * steal))))

## Whether a dodge can start: off cooldown, not mid-roll, not blocking, alive, and
## not in a menu/dialogue.
func _can_dodge() -> bool:
	return _dodge_cd <= 0.0 and _dodge_timer <= 0.0 and not _blocking \
		and not health.is_dead() and not UIManager.dialogue.is_active()

## Begin a dodge-roll: commit a direction (movement, else the aim), grant i-frames,
## cancel any swing, and report it on the Events bus for the dust + whoosh.
func _start_dodge() -> void:
	var dir: Vector2 = _move_input()
	if dir == Vector2.ZERO:
		dir = _aim
	_dodge_dir = dir.normalized()
	if _dodge_dir == Vector2.ZERO:
		_dodge_dir = Vector2.DOWN
	_dodge_timer = DODGE_DURATION
	_iframe_timer = DODGE_IFRAMES
	_dodge_cd = DODGE_DURATION + DODGE_COOLDOWN
	_lunge = Vector2.ZERO
	_end_attack()
	_attacking = false  # dodge-cancels a swing
	weapon_overlay.visible = false
	Events.player_dodged.emit(global_position)
	Events.step_puff.emit(global_position)

func take_damage(amount: int) -> void:
	# Invulnerable during a dodge's i-frames (roll through the blow) or post-hit.
	if _invuln_timer > 0.0 or _iframe_timer > 0.0:
		return
	_invuln_timer = invuln_time
	# Mitigation = leveled defense + worn armor defense (+ shield block if raised).
	var reduction: int = stats.defense_power()
	reduction += equipment.total_defense() if equipment != null else 0
	if _blocking:
		var shield: ArmorItem = equipment.get_shield()
		if shield != null:
			reduction += shield.block
	var taken: int = maxi(1, amount - reduction)
	health.take_damage(taken)
	Events.damage_dealt.emit(global_position, taken, false, true)
	_hit_flash()

func _hit_flash() -> void:
	modulate = Color(1.0, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, invuln_time)

# --- Progression ------------------------------------------------------------

func _on_enemy_killed(_enemy_id: StringName, xp_reward: int, _position: Vector2, by_player: bool) -> void:
	# Only the player's own kills pay XP — faction brawls aren't a free XP fountain.
	if by_player:
		stats.add_xp(xp_reward)

func _on_player_leveled_up(_new_level: int) -> void:
	# Grow the Health pool to the new max and refill on level-up.
	health.max_health = _max_hp()
	health.heal(health.max_health)

## Attributes/skills changed: grow the health pool (without a free heal) and
## refresh which elemental abilities are castable.
func _on_skills_changed() -> void:
	health.max_health = _max_hp()
	health.health = mini(health.health, health.max_health)
	health.health_changed.emit(health.health, health.max_health)
	_sync_abilities()

## Rebuild the ability hotbar from the abilities unlocked by learned skill nodes.
func _sync_abilities() -> void:
	if ability_caster == null:
		return
	var ids: Array = []
	for node_id in stats.learned:
		var node: SkillNode = Skills.get_node_data(node_id)
		if node != null and node.is_ability():
			ids.append(node.unlock_ability_id)
	ability_caster.set_unlocked(ids)

# --- Death / respawn --------------------------------------------------------

func _on_died() -> void:
	_end_attack()
	_attacking = false
	weapon_overlay.visible = false
	modulate = Color(0.5, 0.5, 0.5)
	GameManager.player_died()

## Revives the player at the camp spawn with full (leveled) health. Death costs
## a slice of progress toward the current level rather than a hard XP/level loss.
func revive() -> void:
	health.max_health = _max_hp()
	health.revive(health.max_health)
	stats.apply_death_penalty()
	_invuln_timer = invuln_time
	modulate = Color.WHITE
	global_position = _home_position

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "player"

func save_state() -> Dictionary:
	return {
		"x": global_position.x,
		"y": global_position.y,
		"health": health.health,
	}

func load_state(data: Dictionary) -> void:
	global_position = Vector2(float(data.get("x", global_position.x)), float(data.get("y", global_position.y)))
	health.max_health = _max_hp()
	health.health = clampi(int(data.get("health", health.health)), 0, health.max_health)
	health.health_changed.emit(health.health, health.max_health)
