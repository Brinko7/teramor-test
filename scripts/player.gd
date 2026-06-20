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

## Column order of the 4-frame walk cycle. The facing row comes from DirUtil,
## which reads the sprite's vframes (8 = the directional humanoid rig).
const WALK_FRAMES := [0, 1, 0, 2]
## Preloaded so the global-class dependency resolves before this script
## compiles — avoids the editor's "DirUtil not declared" partial-reload error.
const DIR_UTIL := preload("res://scripts/dir_util.gd")

## How far the melee hitbox sits from the player along the aim direction.
const HITBOX_REACH := 14.0

## Combat-feel tunables: melee knockback dealt to foes, and the player's own
## forward lunge on a melee swing.
const MELEE_KNOCKBACK := 175.0
const LUNGE_SPEED := 95.0
const LUNGE_DECAY := 620.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var outfit_sprite: Sprite2D = $Outfit
@onready var hair_sprite: Sprite2D = $Hair
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
var _cooldown_timer: float = 0.0
var _invuln_timer: float = 0.0
var _blocking: bool = false
var _hit_enemies: Array = []
## Decaying forward step applied during a melee swing for weighty hits.
var _lunge: Vector2 = Vector2.ZERO
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
		weapon_holster, shield_back, attack_arm)
	equipment.changed.connect(_visuals.refresh_gear)
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

## Paints the paper-doll from the chosen identity: skin tints the body sprite,
## the hair style swaps its texture and the hair colour tints it.
func _apply_appearance() -> void:
	sprite.modulate = PlayerProfile.skin_tone
	hair_sprite.texture = PlayerProfile.hair_texture()
	hair_sprite.modulate = PlayerProfile.hair_color

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

	_update_aim()

	# Only the melee path enables the hitbox; ranged attacks never do, so gate
	# the scan on monitoring to avoid querying a disabled area.
	if hitbox.monitoring:
		if _attack_timer > 0.0:
			_scan_hitbox()
		else:
			_end_attack()

	_blocking = Input.is_action_pressed("attack_secondary") and equipment.get_shield() != null

	if _primary_pressed() and _cooldown_timer <= 0.0 and not _blocking and not UIManager.dialogue.is_active():
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
		item_hotbar.use_active(self)

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

func _movement(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input.length() > 1.0:
		input = input.normalized()

	velocity = input * speed + _lunge
	move_and_slide()
	_lunge = _lunge.move_toward(Vector2.ZERO, LUNGE_DECAY * delta)

	# Face where you're moving; when standing still, face the cursor.
	_update_facing(input if input != Vector2.ZERO else _aim)
	_update_animation(delta, input.length() > 0.01)

func _update_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	_facing_row = DIR_UTIL.row_for(dir, sprite.vframes)

func _update_animation(delta: float, moving: bool) -> void:
	if moving:
		_anim_time += delta * anim_fps
	else:
		_anim_time = 0.0
	var col: int = WALK_FRAMES[int(_anim_time) % WALK_FRAMES.size()] if moving else 0
	sprite.frame = _facing_row * sprite.hframes + col
	_visuals.sync_frame(sprite.frame)

# --- Equipped-gear visuals --------------------------------------------------

## Aims the interaction probe at the cursor, then lets the visuals component pose
## the held weapon/shield. Gear rendering itself lives in PlayerVisuals.
func _update_gear_pose() -> void:
	interact_probe.position = _aim * 10.0
	_visuals.update_pose(_aim, _blocking)

# --- Combat / interaction ---------------------------------------------------

func _try_interact() -> void:
	var nearest: Area2D = null
	var nearest_d := INF
	for area in interact_probe.get_overlapping_areas():
		if not area.is_in_group("interactable"):
			continue
		var d := global_position.distance_squared_to(area.global_position)
		if d < nearest_d:
			nearest_d = d
			nearest = area
	if nearest != null and nearest.has_method("interact"):
		nearest.interact(self)

## Resolves the active weapon, or null for bare-handed.
func _current_weapon() -> WeaponItem:
	return equipment.get_weapon() if equipment != null else null

func _start_attack() -> void:
	var weapon: WeaponItem = _current_weapon()
	_attack_timer = weapon.attack_duration if weapon != null else attack_duration
	_cooldown_timer = weapon.attack_cooldown if weapon != null else attack_cooldown

	if weapon != null and weapon.is_ranged():
		_fire_projectile(weapon)
		_visuals.recoil(_aim)
		return

	_hit_enemies.clear()
	hitbox.position = _aim * HITBOX_REACH
	hitbox.monitoring = true
	hitbox_shape.disabled = false
	_lunge = _aim * LUNGE_SPEED  # weighty step into the swing
	_visuals.swing_melee(weapon, _aim)

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

func take_damage(amount: int) -> void:
	if _invuln_timer > 0.0:
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
