extends SceneTree

## Headless check for the first boss (BossEnemy / enemy_vast_colossus.tscn):
##   1. It loads, is a BossEnemy of the monster faction, and starts in phase 1.
##   2. Crossing health thresholds advances phases and sharpens its wind-ups.
##   3. The ground slam damages a hostile inside its radius, not one outside it.
##   4. A player kill fires enemy_killed (attributed) and drops the trophy.
##
## Run: godot --headless -s tools/validate_boss.gd

const BOSS_SCENE := "res://scenes/entities/enemy_vast_colossus.tscn"

var _fail := 0
var _killed := {}

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _ok(m: String) -> void:
	print("  ok: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _make_dummy_player(pos: Vector2) -> Node2D:
	var src := GDScript.new()
	src.source_code = "extends Node2D\nvar dmg := 0\nfunc take_damage(a: int) -> void:\n\tdmg += a\n"
	src.reload()
	var d := Node2D.new()
	d.set_script(src)
	d.global_position = pos
	d.add_to_group("player")
	return d

func _run() -> void:
	await process_frame
	await process_frame

	var packed = load(BOSS_SCENE)
	if packed == null:
		_err("boss scene failed to load")
		_finish()
		return
	var boss = packed.instantiate()
	get_root().add_child(boss)
	await process_frame
	await process_frame

	# --- 1. Identity --------------------------------------------------------
	var script_path: String = boss.get_script().resource_path
	if script_path.ends_with("boss_enemy.gd") and String(boss.faction) == "monster" and boss.get_phase() == 1:
		_ok("boss loads as a monster-faction BossEnemy in phase 1")
	else:
		_err("boss identity wrong (script=%s faction=%s phase=%d)" % [script_path, boss.faction, boss.get_phase()])

	var max_hp: int = boss.health.max_health
	var windup_p1: float = boss.windup_time

	# --- 2. Phase transitions ----------------------------------------------
	# Drop below 66% -> phase 2.
	boss.take_damage(int(max_hp * 0.4), Vector2.ZERO, true)
	await process_frame
	if boss.get_phase() == 2 and boss.windup_time < windup_p1:
		_ok("phase 2 reached; wind-up sharpened (%.2f -> %.2f)" % [windup_p1, boss.windup_time])
	else:
		_err("phase 2 not reached on damage (phase=%d)" % boss.get_phase())
	# Drop below 33% -> phase 3.
	boss.take_damage(int(max_hp * 0.35), Vector2.ZERO, true)
	await process_frame
	if boss.get_phase() == 3:
		_ok("phase 3 reached at low health")
	else:
		_err("phase 3 not reached (phase=%d)" % boss.get_phase())

	# --- 3. Ground slam AoE -------------------------------------------------
	var near := _make_dummy_player(boss.global_position + Vector2(20, 0))
	get_root().add_child(near)
	boss._do_slam()
	if near.dmg > 0:
		_ok("slam damaged a hostile inside its radius (%d dmg)" % near.dmg)
	else:
		_err("slam did not damage an in-range hostile")
	near.queue_free()
	await process_frame
	var far := _make_dummy_player(boss.global_position + Vector2(400, 0))
	get_root().add_child(far)
	boss._do_slam()
	if far.dmg == 0:
		_ok("slam spared a hostile outside its radius")
	else:
		_err("slam hit an out-of-range hostile")
	far.queue_free()

	# --- 4. Death + trophy --------------------------------------------------
	var ev = get_root().get_node_or_null("Events")
	ev.enemy_killed.connect(func(id, _xp, _pos, by_player): _killed = {"id": String(id), "by": by_player})
	boss.take_damage(boss.health.health + 10, Vector2.ZERO, true)
	await process_frame
	await process_frame
	if _killed.get("id", "") == "vast_colossus" and bool(_killed.get("by", false)):
		_ok("boss death fired an attributed kill")
	else:
		_err("boss death did not attribute the kill (%s)" % str(_killed))
	var dropped := false
	for child in get_root().get_children():
		var item = child.get("item") if child.has_method("get") else null
		if item != null and String(item.id) == "blightbane":
			dropped = true
			break
	if dropped:
		_ok("boss dropped its trophy (Blightbane)")
	else:
		_err("boss did not drop the trophy")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - boss phases, slam AoE, and death/trophy all work")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
