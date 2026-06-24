extends SceneTree

## Headless coverage for the cooking / food-buff system:
##   1. The cook_* recipes resolve to buff-granting ConsumableItem dishes with
##      well-formed (matched-length, real-id) ingredient lists.
##   2. PlayerBuffs.apply stacks a stat bonus, refreshes to the stronger/longer of
##      a re-apply, and clears the bonus when the timer expires.
##   3. REGEN buffs heal the parent's Health over time.
##   4. Eating a dish (ConsumableItem.use) heals AND lands its buff on the eater.
##   godot --headless --path . -s res://tools/validate_cooking.gd

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	print("=== cooking validation ===")

	var Buffs: GDScript = load("res://scripts/player_buffs.gd")
	var HealthScript: GDScript = load("res://scripts/health.gd")

	# Stat enum mirror (MELEE=0 .. REGEN=6) — load() to read the real enum.
	var MELEE := 0
	var REGEN := 6

	# --- 1. cook_* recipes resolve to buff dishes -----------------------------
	var item_ids := _collect_item_ids()
	var cook_count := 0
	var dir := DirAccess.open("res://resources/recipes/")
	if dir == null:
		_err("cannot open resources/recipes/")
	else:
		for fn in dir.get_files():
			if not fn.begins_with("cook_") or not fn.ends_with(".tres"):
				continue
			cook_count += 1
			var rec: Resource = load("res://resources/recipes/" + fn)
			if rec == null:
				_err("%s failed to load" % fn)
				continue
			var result: Resource = rec.result
			if result == null or not (result is ConsumableItem):
				_err("%s result is not a ConsumableItem" % fn)
				continue
			var dish := result as ConsumableItem
			if not dish.has_buff():
				_err("%s dish '%s' grants no buff" % [fn, dish.name])
			if dish.heal <= 0:
				_err("%s dish '%s' has no heal" % [fn, dish.name])
			if dish.buff_line() == "":
				_err("%s dish '%s' has an empty buff line" % [fn, dish.name])
			# Ingredient arrays must be matched-length and reference real items.
			if rec.ingredient_ids.size() != rec.ingredient_counts.size():
				_err("%s ingredient arrays mismatched" % fn)
			for ing in rec.get_ingredients():
				var iid: StringName = ing["item_id"]
				if not item_ids.has(iid):
					_err("%s requires unknown item id '%s'" % [fn, iid])
				if int(ing["count"]) <= 0:
					_err("%s has a non-positive ingredient count" % fn)
	if cook_count == 0:
		_err("no cook_* recipes found")
	elif _fail == 0:
		print("  [ok] %d cooking recipes produce well-formed buff dishes" % cook_count)

	# --- 2. PlayerBuffs lifecycle ---------------------------------------------
	var b: Node = Buffs.new()
	b.apply(MELEE, 4, 2.0)
	if b.bonus(MELEE) != 4:
		_err("apply did not register a +4 melee bonus (got %d)" % b.bonus(MELEE))
	# Re-apply weaker/shorter must not downgrade the active buff.
	b.apply(MELEE, 2, 0.5)
	if b.bonus(MELEE) != 4:
		_err("a weaker re-apply downgraded the buff (got %d)" % b.bonus(MELEE))
	# Re-apply stronger upgrades it.
	b.apply(MELEE, 6, 1.0)
	if b.bonus(MELEE) != 6:
		_err("a stronger re-apply did not upgrade the buff (got %d)" % b.bonus(MELEE))
	# Tick past expiry — bonus clears.
	b.set_process(false)
	b._process(2.5)
	if b.bonus(MELEE) == 0 and not b.has_any():
		print("  [ok] buff applies, refreshes to the stronger value, and expires to 0")
	else:
		_err("buff did not expire (bonus=%d, any=%s)" % [b.bonus(MELEE), b.has_any()])
	b.free()

	# --- 3. REGEN heals the parent's Health -----------------------------------
	var host := Node.new()
	get_root().add_child(host)
	var hp: Node = HealthScript.new()
	hp.name = "Health"
	hp.max_health = 100
	host.add_child(hp)
	hp.health = 50
	var rb: Node = Buffs.new()
	rb.name = "Buffs"
	host.add_child(rb)
	rb.set_process(false)
	rb.apply(REGEN, 5, 4.0)
	rb._process(1.0)
	if hp.health > 50:
		print("  [ok] REGEN buff healed Health over time (50 -> %d)" % hp.health)
	else:
		_err("REGEN buff did not heal (hp still %d)" % hp.health)

	# --- 4. Eating a dish heals and lands its buff -----------------------------
	hp.health = 60
	var skewer: Resource = load("res://resources/items/produce/grilled_skewer.tres")
	if skewer == null:
		_err("grilled_skewer.tres missing")
	else:
		var consumed: bool = (skewer as ConsumableItem).use(host)
		if not consumed:
			_err("eating the skewer reported not-consumed")
		if hp.health <= 60:
			_err("eating the skewer did not heal (hp %d)" % hp.health)
		if rb.bonus(MELEE) <= 0:
			_err("eating the skewer did not apply its melee buff")
		if _fail == 0 or rb.bonus(MELEE) > 0:
			print("  [ok] eating a dish heals and applies its buff (+%d melee)" % rb.bonus(MELEE))
	host.free()

	if _fail == 0:
		print("\nRESULT: PASS — cooking yields buff dishes that heal, buff, and expire")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

## Build the set of every item id under resources/items (recursively) so recipe
## ingredients can be validated against real content.
func _collect_item_ids() -> Dictionary:
	var ids := {}
	_scan_items("res://resources/items/", ids)
	return ids

func _scan_items(path: String, ids: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if dir.current_is_dir():
			if not fn.begins_with("."):
				_scan_items(path + fn + "/", ids)
		elif fn.ends_with(".tres"):
			var res: Resource = load(path + fn)
			if res != null and "id" in res and res.id != &"":
				ids[res.id] = true
		fn = dir.get_next()

func _err(m: String) -> void:
	_fail += 1
	print("  [FAIL] " + m)
