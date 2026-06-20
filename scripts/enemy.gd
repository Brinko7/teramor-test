extends CharacterBody2D
class_name Enemy

## Basic bandit enemy and shared base for the other enemy types. Wanders idly,
## chases the player when near, and damages the player on contact. Sprite sheet
## is a 4x4 grid matching the player layout (rows: 0=down, 1=up, 2=left,
## 3=right). Subclasses (wolf, brute, archer) tweak exported stats and may
## override `_decide_input()` for bespoke movement.

@export var speed: float = 45.0
@export var anim_fps: float = 6.0
@export var detect_range: float = 80.0
@export var touch_damage: int = 3
## Whether this enemy performs a telegraphed melee strike. False for kiters (the
## archer) and non-combatants (wildlife, bear cub) — they never deal contact
## damage. `touch_damage` is the strike's damage.
@export var melee_attacker: bool = true
## Telegraphed-attack timing. The enemy commits to a wind-up when a hostile comes
## within `attack_range`, telegraphs for `windup_time`, then strikes any hostile
## still inside `strike_range`, and can't attack again for `recover_time`. The
## wind-up is the player's window to disengage or block — the rhythm of a fight.
@export var attack_range: float = 20.0
@export var strike_range: float = 24.0
@export var windup_time: float = 0.4
@export var strike_time: float = 0.12
@export var recover_time: float = 0.55
## Experience granted to the player when this enemy dies.
@export var xp_reward: int = 5
## Identifies the creature kind so monster contracts can target it (e.g. a
## "slay 3 wolves" bounty matches only enemies whose id is &"wolf").
@export var enemy_id: StringName = &"bandit"
## Allegiance for the faction system (see Faction). Decides who this enemy
## treats as hostile: the player plus any rival-faction enemy in range. Default
## is BANDIT; wolves/bears are BEAST, the Withered is MONSTER.
@export var faction: StringName = &"bandit"

## Items dropped on death. Each entry rolls independently against loot_chance.
@export var loot_table: Array[Item] = []
@export_range(0.0, 1.0) var loot_chance: float = 0.5

const PICKUP_SCENE := preload("res://scenes/entities/item_pickup.tscn")
## Preloaded so the global-class dependency resolves before this script
## compiles — avoids the editor's "DirUtil not declared" partial-reload error.
const DIR_UTIL := preload("res://scripts/dir_util.gd")
## Two-channel sprite feedback shader (warn-glow + white hit-flash); a per-instance
## ShaderMaterial wraps it so each enemy flashes independently.
const FLASH_SHADER := preload("res://assets/shaders/hit_flash.gdshader")

const WALK_FRAMES := [0, 1, 0, 2]

## Attack phases. READY = free to chase/attack; WINDUP/STRIKE lock movement so the
## tell reads; RECOVER is the post-swing cooldown before READY again.
enum AttackState { READY, WINDUP, STRIKE, RECOVER }
## Forward pounce speed added on a strike, decaying like knockback for a weighty lunge.
const STRIKE_LUNGE := 150.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: Health = $Health
@onready var touch_box: Area2D = $TouchBox

var _facing_row: int = 0
var _anim_time: float = 0.0
## Current thing this enemy is chasing/attacking: the player or a rival-faction
## enemy. Refreshed periodically by _acquire_target.
var _target: Node2D = null
var _retarget_timer: float = 0.0
const RETARGET_INTERVAL := 0.3
var _wander_dir: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
## Decaying knockback velocity applied when struck.
var _knockback: Vector2 = Vector2.ZERO
## Decaying forward lunge applied during a strike (separate from knockback so a
## strike-while-being-knocked-back reads as both).
var _attack_lunge: Vector2 = Vector2.ZERO
## Whether the most recent hit came from the player — read on death so faction
## kills (enemy-vs-enemy) don't award the player XP, quest credit or death juice.
var _last_hit_from_player: bool = false
const KNOCKBACK_DECAY := 700.0

## Telegraphed-attack state machine.
var _atk_state: AttackState = AttackState.READY
var _atk_timer: float = 0.0
var _atk_dir: Vector2 = Vector2.DOWN
## True once dead and playing the death beat — gates further hits and physics.
var _dying: bool = false
## Per-instance flash/telegraph material on the sprite.
var _mat: ShaderMaterial
## The active hurt-flinch scale tween, killed before re-starting so flinches don't fight.
var _flinch_tween: Tween

func _ready() -> void:
	add_to_group("enemy")
	# Per-instance material so warn-glow and hit-flash are independent per enemy.
	_mat = ShaderMaterial.new()
	_mat.shader = FLASH_SHADER
	sprite.material = _mat
	health.died.connect(_on_died)
	_pick_wander()

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_acquire_target(delta)
	_update_attack(delta)

	# Movement is suppressed while winding up or striking so the tell reads and the
	# attack commits to its direction; otherwise the subclass brain drives movement.
	var locked: bool = _atk_state == AttackState.WINDUP or _atk_state == AttackState.STRIKE
	var input: Vector2 = Vector2.ZERO if locked else _decide_input(delta)

	velocity = input * speed + _knockback + _attack_lunge
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	_attack_lunge = _attack_lunge.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	_update_facing(_atk_dir if locked else input)
	_update_animation(delta, input.length() > 0.01)

## Returns the desired movement direction this frame. Base behavior: chase the
## current target within detect_range, otherwise wander. Overridable by subclasses.
func _decide_input(delta: float) -> Vector2:
	if _target != null and is_instance_valid(_target):
		var to_target: Vector2 = _target.global_position - global_position
		if to_target.length() <= detect_range:
			return to_target.normalized()
	return _wander(delta)

## Periodically re-pick the nearest hostile (player or rival-faction enemy) in
## detection range. Throttled so we don't scan the enemy group every frame, and
## re-evaluated even when a target is held so a closer threat can steal focus and
## dead/fled targets get dropped.
func _acquire_target(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer > 0.0 and _target != null and is_instance_valid(_target):
		return
	_retarget_timer = RETARGET_INTERVAL
	_target = _find_nearest_hostile()

## Nearest node this enemy is willing to fight, within detect_range, or null.
## The player counts when this faction is hostile to it; rival-faction enemies
## always count when hostile.
func _find_nearest_hostile() -> Node2D:
	var best: Node2D = null
	var best_dist: float = detect_range
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player) and Faction.hostile(faction, Faction.PLAYER):
		var pd: float = global_position.distance_to(player.global_position)
		if pd <= best_dist:
			best = player
			best_dist = pd
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not (other is Enemy) or not is_instance_valid(other):
			continue
		if not Faction.hostile(faction, (other as Enemy).faction):
			continue
		var od: float = global_position.distance_to((other as Enemy).global_position)
		if od <= best_dist:
			best = other
			best_dist = od
	return best

## Whether this enemy will deal contact/projectile damage to `node`.
func _is_hostile_to(node: Node) -> bool:
	if node.is_in_group("player"):
		return Faction.hostile(faction, Faction.PLAYER)
	if node is Enemy:
		return Faction.hostile(faction, (node as Enemy).faction)
	return false

func _wander(delta: float) -> Vector2:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander()
	return _wander_dir * 0.5

func _pick_wander() -> void:
	_wander_timer = randf_range(1.0, 2.5)
	if randf() < 0.4:
		_wander_dir = Vector2.ZERO
	else:
		_wander_dir = Vector2.from_angle(randf() * TAU)

## --- Telegraphed melee attack ----------------------------------------------
## Drives READY -> WINDUP -> STRIKE -> RECOVER. Non-attackers (kiters, prey) skip
## it entirely and so never deal contact damage. The wind-up shows a warm warn-glow
## on the sprite plus a CombatFX telegraph ring; the strike paints a swing arc,
## lunges forward, and damages any hostile still in range.
func _update_attack(delta: float) -> void:
	if not melee_attacker:
		return
	match _atk_state:
		AttackState.READY:
			if _target != null and is_instance_valid(_target) and _is_hostile_to(_target) \
					and global_position.distance_to(_target.global_position) <= attack_range:
				_begin_windup(_target)
		AttackState.WINDUP:
			_atk_timer -= delta
			var p: float = 1.0 - clampf(_atk_timer / maxf(windup_time, 0.001), 0.0, 1.0)
			_set_warn(p * 0.65)
			if _atk_timer <= 0.0:
				_do_strike()
				_atk_state = AttackState.STRIKE
				_atk_timer = strike_time
		AttackState.STRIKE:
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_atk_state = AttackState.RECOVER
				_atk_timer = recover_time
		AttackState.RECOVER:
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_atk_state = AttackState.READY

func _begin_windup(target: Node2D) -> void:
	_atk_state = AttackState.WINDUP
	_atk_timer = windup_time
	_atk_dir = (target.global_position - global_position).normalized()
	if _atk_dir == Vector2.ZERO:
		_atk_dir = Vector2.from_angle(randf() * TAU)
	Events.attack_windup.emit(global_position + Vector2(0, -8), _atk_dir, windup_time)

func _do_strike() -> void:
	_set_warn(0.0)
	_attack_lunge = _atk_dir * STRIKE_LUNGE
	Events.melee_swung.emit(global_position + _atk_dir * 10.0 + Vector2(0, -8), _atk_dir, false)
	for victim in _strike_victims():
		if victim.has_method("take_damage"):
			# Single-arg call keeps the player (take_damage(amount)) and enemies
			# (take_damage(amount, knockback, from_player)) on a common signature.
			victim.take_damage(touch_damage)

## Hostiles within strike_range when the blow lands (player and rival factions).
func _strike_victims() -> Array:
	var out: Array = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player) and Faction.hostile(faction, Faction.PLAYER):
		if global_position.distance_to(player.global_position) <= strike_range:
			out.append(player)
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not (other is Enemy) or not is_instance_valid(other):
			continue
		if not Faction.hostile(faction, (other as Enemy).faction):
			continue
		if global_position.distance_to((other as Enemy).global_position) <= strike_range:
			out.append(other)
	return out

## Drive the sprite's telegraph glow (0 = none) — no-op until the material exists.
func _set_warn(amount: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("warn", amount)

func _update_facing(input: Vector2) -> void:
	if input == Vector2.ZERO:
		return
	_facing_row = DIR_UTIL.row_for(input, sprite.vframes)

func _update_animation(delta: float, moving: bool) -> void:
	if moving:
		_anim_time += delta * anim_fps
	else:
		_anim_time = 0.0
	var col: int = WALK_FRAMES[int(_anim_time) % WALK_FRAMES.size()] if moving else 0
	sprite.frame = _facing_row * sprite.hframes + col

## Scale this enemy's threat to a difficulty tier (1 = base). Called by the area
## generator right after spawning so the deeper wilds field tougher, more
## rewarding creatures. Subclasses inherit this unchanged.
func apply_tier(tier: int) -> void:
	if tier <= 1:
		return
	var steps: int = tier - 1
	touch_damage = int(round(touch_damage * (1.0 + 0.35 * steps)))
	xp_reward = int(round(xp_reward * (1.0 + 0.5 * steps)))
	var scaled_hp: int = int(round(health.max_health * (1.0 + 0.5 * steps)))
	health.max_health = scaled_hp
	health.health = scaled_hp
	# Tint deeper-tier foes so they read as more dangerous.
	modulate = modulate.lerp(Color(1.0, 0.6, 0.7), clampf(0.12 * steps, 0.0, 0.5))

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, from_player: bool = false) -> void:
	if _dying:
		return
	# Set before health.take_damage: a killing blow fires died -> _on_died
	# synchronously (flipping _dying), which reads this flag to attribute the kill.
	_last_hit_from_player = from_player
	health.take_damage(amount)
	# The number pops even for a lethal hit; the death beat owns the rest of the
	# visuals, so flash/flinch only run when the enemy survives.
	Events.damage_dealt.emit(global_position, amount, true, from_player)
	if knockback != Vector2.ZERO:
		_knockback = knockback
	if _dying:
		return
	_flash()
	_flinch()

## A crisp white silhouette flash via the sprite shader (independent of the
## warn-glow and the modulate tint), decaying fast.
func _flash() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.18)

## A quick squash-and-recover on the sprite so a hit lands with weight.
func _flinch() -> void:
	if _flinch_tween != null and _flinch_tween.is_valid():
		_flinch_tween.kill()
	sprite.scale = Vector2(0.84, 1.16)
	_flinch_tween = create_tween()
	_flinch_tween.tween_property(sprite, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_died() -> void:
	if _dying:
		return
	_dying = true
	_drop_loot()
	# Fire the kill now so XP, quest credit and the CombatFX burst land at the
	# moment of death; the corpse then plays out its fade independently.
	Events.enemy_killed.emit(enemy_id, xp_reward, global_position, _last_hit_from_player)
	# Stop being a combatant: no more targeting, attacking, ticking or blocking.
	remove_from_group("enemy")
	_set_warn(0.0)
	set_physics_process(false)
	var body_col := get_node_or_null("CollisionShape2D")
	if body_col != null:
		body_col.set_deferred("disabled", true)
	if touch_box != null:
		touch_box.set_deferred("monitoring", false)
	if _flinch_tween != null and _flinch_tween.is_valid():
		_flinch_tween.kill()
	# Death beat: collapse, topple and fade rather than a hard pop.
	var topple: float = deg_to_rad(18.0) * (1.0 if randf() < 0.5 else -1.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_property(sprite, "scale", Vector2(1.15, 0.72), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "rotation", topple, 0.4)
	get_tree().create_timer(0.5).timeout.connect(queue_free)

func _drop_loot() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for item in loot_table:
		if item == null or randf() > loot_chance:
			continue
		var pickup := PICKUP_SCENE.instantiate() as ItemPickup
		pickup.configure(item, 1)
		pickup.position = position + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		parent.call_deferred("add_child", pickup)
