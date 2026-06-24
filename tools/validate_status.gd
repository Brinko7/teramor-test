extends SceneTree

## Headless coverage for status-effects-on-hit:
##   1. DoT kinds (Burn/Poison/Bleed) tick damage through take_damage().
##   2. Slow scales `speed` and restores it on expiry; Stun roots (speed 0) and
##      reads via is_stunned().
##   3. Status affixes roll onto weapons as an on-hit effect.
##   4. A rolled on-hit weapon survives an inventory save/load.
##   godot --headless --path . -s res://tools/validate_status.gd

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	print("=== status validation ===")
	var SE: GDScript = load("res://scripts/status_effect.gd")
	var dummy_src := "extends Node\nvar speed := 40.0\nvar hp := 100\nvar status_resist := 0.0\nfunc take_damage(a: int, k := Vector2.ZERO, f := false) -> void:\n\thp -= a\n"
	var Dummy := GDScript.new()
	Dummy.source_code = dummy_src
	Dummy.reload()

	# 1. DoT ticks (kind BURN=1)
	var d1: Node = Dummy.new()
	SE.apply(d1, 1, 5, 10.0, 1.0)
	var fx1: Node = d1.get_child(d1.get_child_count() - 1)
	fx1._ready()
	fx1._process(0.6); fx1._process(0.6)
	if d1.hp == 90:
		print("  [ok] DoT ticked 2x5 -> hp 90")
	else:
		_err("DoT did not tick correctly (hp=%d, want 90)" % d1.hp)

	# 2a. Slow scales + restores speed (kind SLOW=2)
	var d2: Node = Dummy.new()
	SE.apply(d2, 2, 0, 4.0, 0.5)
	var fx2: Node = d2.get_child(d2.get_child_count() - 1)
	fx2._ready()
	if not is_equal_approx(d2.speed, 20.0):
		_err("slow did not scale speed (%.1f, want 20)" % d2.speed)
	fx2._process(4.5)
	if is_equal_approx(d2.speed, 40.0):
		print("  [ok] slow scaled to 20 then restored to 40 on expiry")
	else:
		_err("slow did not restore speed (%.1f, want 40)" % d2.speed)

	# 2b. Stun roots + is_stunned (kind STUN=5)
	var d3: Node = Dummy.new()
	SE.apply(d3, 5, 0, 1.0, 1.0)
	var fx3: Node = d3.get_child(d3.get_child_count() - 1)
	fx3._ready()
	if SE.is_stunned(d3) and is_equal_approx(d3.speed, 0.0):
		print("  [ok] stun roots (speed 0) and reads as stunned")
	else:
		_err("stun did not root / register (stunned=%s speed=%.1f)" % [SE.is_stunned(d3), d3.speed])

	# 3. status affixes roll onto weapons
	var Roller: GDScript = load("res://scripts/items/affix_roller.gd")
	var base: Resource = load("res://resources/items/iron_sword.tres")
	var on_hit: Resource = null
	for i in range(800):
		var r: Resource = Roller.roll(base, 7)
		if r != base and r.has_on_hit():
			on_hit = r
			break
	if on_hit == null:
		_err("800 rolls produced no on-hit status weapon")
	elif on_hit.on_hit_status <= 0 or on_hit.on_hit_chance <= 0.0:
		_err("on-hit weapon has no valid status payload")
	else:
		print("  [ok] rolled an on-hit weapon (\"%s\", status=%d)" % [on_hit.name, on_hit.on_hit_status])
		if base.on_hit_status != 0:
			_err("rolling an on-hit affix mutated the base .tres")

	# 4. on-hit weapon survives save/load
	if on_hit != null:
		var Inv: GDScript = load("res://scripts/inventory.gd")
		var inv: Node = Inv.new()
		inv.slots.resize(inv.capacity)
		inv.slots[0] = {"item": on_hit, "count": 1}
		var inv2: Node = Inv.new()
		inv2.load_state(inv.save_state())
		var got: Resource = inv2.slots[0]["item"]
		if got != null and got.on_hit_status == on_hit.on_hit_status \
				and is_equal_approx(got.on_hit_chance, on_hit.on_hit_chance) \
				and got.on_hit_power == on_hit.on_hit_power:
			print("  [ok] on-hit weapon survives save/load")
		else:
			_err("save/load lost the on-hit status")
		inv.free(); inv2.free()

	d1.free(); d2.free(); d3.free()
	if _fail == 0:
		print("\nRESULT: PASS — status effects tick/root, roll onto weapons, and persist")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(m: String) -> void:
	_fail += 1
	print("  [FAIL] " + m)
