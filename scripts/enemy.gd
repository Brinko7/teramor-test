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
@export var touch_cooldown: float = 1.0
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

const WALK_FRAMES := [0, 1, 0, 2]

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
var _touch_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
## Decaying knockback velocity applied when struck.
var _knockback: Vector2 = Vector2.ZERO
## Whether the most recent hit came from the player — read on death so faction
## kills (enemy-vs-enemy) don't award the player XP, quest credit or death juice.
var _last_hit_from_player: bool = false
const KNOCKBACK_DECAY := 700.0

func _ready() -> void:
	add_to_group("enemy")
	health.died.connect(_on_died)
	_pick_wander()

func _physics_process(delta: float) -> void:
	_touch_timer = maxf(0.0, _touch_timer - delta)
	_acquire_target(delta)

	var input: Vector2 = _decide_input(delta)

	velocity = input * speed + _knockback
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	_update_facing(input)
	_update_animation(delta, input.length() > 0.01)
	_check_touch()

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

func _check_touch() -> void:
	if _touch_timer > 0.0:
		return
	for body in touch_box.get_overlapping_bodies():
		if body == self:
			continue
		if _is_hostile_to(body) and body.has_method("take_damage"):
			body.take_damage(touch_damage)
			_touch_timer = touch_cooldown
			return

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
	# Set before health.take_damage: a killing blow fires died -> _on_died
	# synchronously, which reads this flag to attribute the kill.
	_last_hit_from_player = from_player
	health.take_damage(amount)
	_flash()
	Events.damage_dealt.emit(global_position, amount, true, from_player)
	if knockback != Vector2.ZERO:
		_knockback = knockback

func _flash() -> void:
	modulate = Color(1.0, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.2)

func _on_died() -> void:
	_drop_loot()
	Events.enemy_killed.emit(enemy_id, xp_reward, global_position, _last_hit_from_player)
	queue_free()

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
