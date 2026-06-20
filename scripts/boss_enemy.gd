extends Enemy
class_name BossEnemy

## A multi-phase, telegraphed boss — the skill check the difficulty curve builds
## toward. It keeps the base Enemy melee rhythm (wind-up → strike → recover) but
## adds two things:
##   * PHASES tied to remaining health. Each threshold it crosses, the boss grows
##     faster and angrier (snappier wind-ups, shorter recovery, a touch quicker)
##     and a banner announces the turn — so a long fight has escalating beats.
##   * A telegraphed AoE GROUND SLAM, unlocked at phase 2: a long, readable wind-up
##     the player can roll out of, then radial damage to everything nearby plus a
##     screen jolt. The counterplay to a boss that also out-trades you up close.
##
## Author a boss by putting this script on an enemy scene and tuning the exports;
## everything else (targeting, loot, death beat) is inherited from Enemy.

## Health fractions (descending) at which the boss advances a phase.
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
@export var boss_name: String = "The Withered Colossus"
@export_multiline var spawn_line: String = "...stirs from the blight."

## Ground-slam AoE (unlocked at phase 2).
@export var slam_damage: int = 12
@export var slam_radius: float = 60.0
@export var slam_windup: float = 0.75
@export var slam_cooldown: float = 5.0
## How close a target must be for the boss to commit to a slam.
@export var slam_range: float = 90.0

var _phase: int = 1
var _slam_cd: float = 0.0
var _slamming: bool = false
var _slam_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_slam_cd = slam_cooldown
	health.health_changed.connect(_on_health_changed)
	# A banner so the arena reads as a Moment, not just a big sprite.
	UIManager.notify(boss_name, spawn_line)

# --- Phases -----------------------------------------------------------------

func _on_health_changed(h: int, max_h: int) -> void:
	if max_h <= 0 or _dying:
		return
	var frac: float = float(h) / float(max_h)
	var target_phase: int = 1
	for t: float in phase_thresholds:
		if frac <= t:
			target_phase += 1
	if target_phase > _phase:
		_enter_phase(target_phase)

func _enter_phase(p: int) -> void:
	_phase = p
	# Each phase: snappier wind-ups, shorter recovery, a little faster, hungrier slams.
	windup_time = maxf(0.18, windup_time * 0.82)
	recover_time = maxf(0.2, recover_time * 0.85)
	speed *= 1.12
	slam_cooldown = maxf(2.0, slam_cooldown * 0.8)
	modulate = modulate.lerp(Color(1.0, 0.4, 0.45), 0.25)
	var line: String = "The blight surges — it grows fiercer." if p == 2 else "Cornered and furious. Finish it!"
	UIManager.notify(boss_name, line)

func get_phase() -> int:
	return _phase

# --- Ground slam ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _dying:
		return
	if _slamming:
		_update_slam(delta)
		# Fully committed: only knockback moves the boss mid-slam.
		velocity = _knockback
		move_and_slide()
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
		return
	super._physics_process(delta)
	# Charge a slam between melee swings, once enraged enough and the target's close.
	_slam_cd -= delta
	if _phase >= 2 and _slam_cd <= 0.0 and _atk_state == AttackState.READY and _can_slam():
		_begin_slam()

func _can_slam() -> bool:
	return _target != null and is_instance_valid(_target) and _is_hostile_to(_target) \
		and global_position.distance_to(_target.global_position) <= slam_range

func _begin_slam() -> void:
	_slamming = true
	_slam_timer = slam_windup
	# A big, readable tell: the telegraph ring + warn-glow ramp give the roll window.
	Events.attack_windup.emit(global_position + Vector2(0, -8), Vector2.DOWN, slam_windup)

func _update_slam(delta: float) -> void:
	_slam_timer -= delta
	var p: float = 1.0 - clampf(_slam_timer / maxf(slam_windup, 0.001), 0.0, 1.0)
	_set_warn(p * 0.8)
	if _slam_timer <= 0.0:
		_do_slam()
		_slamming = false
		_set_warn(0.0)
		_slam_cd = slam_cooldown
		# Land in recovery so it can't immediately melee on top of the slam.
		_atk_state = AttackState.RECOVER
		_atk_timer = recover_time

func _do_slam() -> void:
	Events.melee_swung.emit(global_position + Vector2(0, -8), Vector2.DOWN, false)
	Events.screen_shake.emit(6.0)
	for victim in _slam_victims():
		if not victim.has_method("take_damage"):
			continue
		if victim is Enemy:
			var dir: Vector2 = (victim.global_position - global_position).normalized()
			victim.take_damage(slam_damage, dir * 200.0, false)
		else:
			victim.take_damage(slam_damage)

## Every hostile within slam_radius (player + rival factions).
func _slam_victims() -> Array:
	var out: Array = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player) and Faction.hostile(faction, Faction.PLAYER):
		if global_position.distance_to(player.global_position) <= slam_radius:
			out.append(player)
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not (other is Enemy) or not is_instance_valid(other):
			continue
		if not Faction.hostile(faction, (other as Enemy).faction):
			continue
		if global_position.distance_to((other as Enemy).global_position) <= slam_radius:
			out.append(other)
	return out

# --- Tier scaling (gentler HP curve than rank-and-file; bosses are already big) ---

func apply_tier(tier: int) -> void:
	if tier <= 1:
		return
	var steps: int = tier - 1
	touch_damage = int(round(touch_damage * (1.0 + 0.3 * steps)))
	slam_damage = int(round(slam_damage * (1.0 + 0.3 * steps)))
	xp_reward = int(round(xp_reward * (1.0 + 0.6 * steps)))
	var scaled_hp: int = int(round(health.max_health * (1.0 + 0.3 * steps)))
	health.max_health = scaled_hp
	health.health = scaled_hp
	modulate = modulate.lerp(Color(1.0, 0.6, 0.7), clampf(0.1 * steps, 0.0, 0.4))
