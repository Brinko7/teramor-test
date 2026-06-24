extends SceneTree

## Headless coverage for rolled loot affixes:
##   1. Rolling a generic COMMON weapon yields a distinct, affixed, higher-rarity
##      instance — without mutating the shared base .tres.
##   2. Authored uniques (rarity > COMMON) pass through untouched.
##   3. A rolled item survives an inventory save/load round-trip by value.
##   godot --headless --path . -s res://tools/validate_affixes.gd

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	print("=== affix validation ===")
	var Roller: Script = load("res://scripts/items/affix_roller.gd")
	var base: Resource = load("res://resources/items/iron_sword.tres")
	if Roller == null or base == null:
		_err("missing AffixRoller or base weapon"); _done(); return

	# snapshot the shared base so we can prove it isn't mutated
	var b_melee: int = base.bonus_melee
	var b_name: String = base.name
	var b_rarity: int = base.rarity

	var with_affix := 0
	var sample: Resource = null
	for i in range(400):
		var rolled: Resource = Roller.roll(base, 5)
		if rolled == base:
			continue   # rolled nothing this time
		with_affix += 1
		if rolled.name == b_name:
			_err("rolled item kept the base name"); break
		if int(rolled.rarity) <= b_rarity:
			_err("rolled item did not gain rarity"); break
		if not rolled.has_affixes():
			_err("rolled item carries no affix bonuses"); break
		if not rolled.rolled:
			_err("rolled item missing the `rolled` flag"); break
		sample = rolled
	if with_affix == 0:
		_err("400 rolls at tier 5 produced no affixed gear")
	else:
		print("  [ok] %d/400 rolls produced affixed gear" % with_affix)
	if base.bonus_melee != b_melee or base.name != b_name or int(base.rarity) != b_rarity:
		_err("rolling MUTATED the shared base .tres")
	else:
		print("  [ok] base .tres left unmutated")

	# 2. authored uniques are preserved
	var uniq: Resource = load("res://resources/items/emberbrand.tres")
	if uniq != null:
		if Roller.roll(uniq, 7) != uniq:
			_err("an authored unique was re-rolled")
		else:
			print("  [ok] authored unique passed through untouched")

	# 3. save/load round-trip preserves the roll
	if sample != null:
		var Inv: Script = load("res://scripts/inventory.gd")
		var inv: Node = Inv.new()
		inv.slots.resize(inv.capacity)
		inv.slots[0] = {"item": sample, "count": 1}
		var data: Dictionary = inv.save_state()
		var inv2: Node = Inv.new()
		inv2.load_state(data)
		var restored: Resource = inv2.slots[0]["item"]
		if restored == null:
			_err("round-trip lost the item")
		elif restored.name != sample.name or restored.bonus_melee != sample.bonus_melee \
				or restored.bonus_ranged != sample.bonus_ranged or restored.bonus_spell != sample.bonus_spell \
				or restored.bonus_max_hp != sample.bonus_max_hp or restored.bonus_defense != sample.bonus_defense:
			_err("save/load did not preserve the rolled stats")
		elif not restored.rolled:
			_err("restored item lost its rolled flag")
		else:
			print("  [ok] rolled item survives save/load (\"%s\")" % restored.name)
		inv.free(); inv2.free()

	_done()

func _err(m: String) -> void:
	_fail += 1
	print("  [FAIL] " + m)

func _done() -> void:
	if _fail == 0:
		print("\nRESULT: PASS — rolled affixes drop, preserve uniques, and persist")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)
