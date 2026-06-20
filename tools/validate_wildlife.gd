extends SceneTree

## Headless validation for passive wildlife + the faction-clash encounter (tasks
## #36/#37). Run:
##   godot --headless --path <project> -s res://tools/validate_wildlife.gd
##
## NOTE: in `-s` mode the project autoloads (Events, etc.) only register as global
## identifiers once the tree has ticked, so the enemy script chain won't compile on
## frame 0 — we await a couple of frames before instantiating anything Enemy-derived.

const DEER := "res://scenes/entities/wildlife_deer.tscn"
const RABBIT := "res://scenes/entities/wildlife_rabbit.tscn"
const CLASH := "res://resources/world/encounters/wild_clash.tres"
const DEEPWOOD := "res://resources/world/biomes/deepwood.tres"
const MEAT := "res://resources/items/raw_meat.tres"
const HIDE := "res://resources/items/hide.tres"
const MUSH := "res://resources/items/wild_mushroom.tres"

var _fail := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	# Let autoloads register before touching Enemy-derived scripts.
	await process_frame
	await process_frame
	print("=== wildlife validation ===")
	_check_items()
	_check_animal(DEER, &"deer", true)
	_check_animal(RABBIT, &"rabbit", false)
	_check_clash()
	_check_biome()
	_done()

# --- Items ------------------------------------------------------------------

func _check_items() -> void:
	var meat := load(MEAT) as Item
	if meat == null or meat.id != &"raw_meat":
		_err("raw_meat.tres did not load as an Item with id raw_meat")
	elif not (meat is ConsumableItem) or (meat as ConsumableItem).heal <= 0:
		_err("raw_meat should be a healing ConsumableItem")
	elif meat.icon == null:
		_err("raw_meat has no icon")
	else:
		print("  [ok] raw_meat loads (heal %d)" % (meat as ConsumableItem).heal)
	var hide := load(HIDE) as Item
	if hide == null or hide.id != &"hide" or hide.icon == null:
		_err("hide.tres did not load as an Item with an icon")
	else:
		print("  [ok] hide loads")
	var mush := load(MUSH) as Item
	if mush == null or mush.id != &"wild_mushroom":
		_err("wild_mushroom.tres did not load as an Item")
	elif not (mush is ConsumableItem) or (mush as ConsumableItem).heal <= 0:
		_err("wild_mushroom should be a healing ConsumableItem")
	elif mush.icon == null:
		_err("wild_mushroom has no icon")
	else:
		print("  [ok] wild_mushroom loads (heal %d)" % (mush as ConsumableItem).heal)

# --- Animal behaviour -------------------------------------------------------

func _check_animal(path: String, want_id: StringName, want_hide: bool) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		_err("cannot load %s" % path)
		return
	var animal := ps.instantiate()
	root.add_child(animal)  # triggers _ready -> faction + _base_speed

	# Duck-typed on purpose: referencing the `Enemy` class_name here would force
	# enemy.gd (which uses the `Events` autoload) to compile on frame 0, before the
	# tree has registered autoloads — poisoning the compile cache. We probe for the
	# Enemy/Wildlife surface instead, and bail loudly if the script didn't compile.
	if not animal.has_method("_decide_input") or animal.get("enemy_id") == null:
		_err("%s scene didn't compile as Wildlife/Enemy (broken script chain?)" % want_id)
		animal.queue_free()
		return
	if not animal.is_in_group("enemy"):
		_err("%s is not in the 'enemy' group (player couldn't hunt it)" % want_id)
	var fac: StringName = animal.get("faction")
	if fac != Faction.WILDLIFE:
		_err("%s faction is %s, want wildlife" % [want_id, fac])
	else:
		print("  [ok] %s is a neutral WILDLIFE enemy-group member" % want_id)
	if animal.get("enemy_id") != want_id:
		_err("%s enemy_id mismatch: %s" % [want_id, animal.get("enemy_id")])
	for child in ["Sprite2D", "Health", "TouchBox"]:
		if animal.get_node_or_null(child) == null:
			_err("%s is missing required child %s" % [want_id, child])

	# Authored loot must survive (the generator must NOT have a chance to override it).
	var loot: Array = animal.get("loot_table")
	var ids: Array = []
	for it in loot:
		if it != null:
			ids.append(it.id)
	if not (&"raw_meat" in ids):
		_err("%s loot_table is missing raw_meat (got %s)" % [want_id, ids])
	elif want_hide and not (&"hide" in ids):
		_err("deer loot_table is missing hide (got %s)" % [ids])
	else:
		print("  [ok] %s keeps authored loot %s" % [want_id, ids])

	# apply_tier must be a no-op for wildlife.
	var hp := animal.get_node("Health")
	var max_before: int = int(hp.get("max_health"))
	animal.call("apply_tier", 4)
	if int(hp.get("max_health")) != max_before:
		_err("%s apply_tier(4) scaled HP %d -> %d (should be a no-op)" % [want_id, max_before, int(hp.get("max_health"))])
	else:
		print("  [ok] %s ignores tier scaling (HP stayed %d)" % [want_id, max_before])

	_check_flee(animal, want_id)
	animal.free()  # immediate, so it can't bleed into the next animal's checks

func _check_flee(animal: Node, want_id: StringName) -> void:
	var base: float = float(animal.get("speed"))
	var mult: float = float(animal.get("flee_speed_mult"))
	# Stage a threat (a fake player) just inside flee range.
	var dummy := Node2D.new()
	dummy.add_to_group("player")
	root.add_child(dummy)
	(animal as Node2D).global_position = Vector2.ZERO
	dummy.global_position = Vector2(50, 0)
	var dir: Vector2 = animal.call("_decide_input", 0.1)
	# Should bolt away from the threat (negative x) and ramp speed to the sprint.
	if dir.dot(Vector2(-1, 0)) <= 0.0:
		_err("%s did not flee away from the threat (dir=%s)" % [want_id, dir])
	elif absf(float(animal.get("speed")) - base * mult) > 0.5:
		_err("%s did not sprint while fleeing (speed=%s, want %s)" % [want_id, animal.get("speed"), base * mult])
	else:
		print("  [ok] %s flees away from threats at sprint speed" % want_id)
	# Pull the threat far away; after the spook decays it should graze at base speed.
	dummy.global_position = Vector2(99999, 99999)
	animal.call("_decide_input", float(animal.get("spook_time")) + 1.0)
	if absf(float(animal.get("speed")) - base) > 0.5:
		_err("%s did not settle to graze speed once safe (speed=%s, want %s)" % [want_id, animal.get("speed"), base])
	else:
		print("  [ok] %s settles to a calm graze when no threat is near" % want_id)
	# A hit should spook it into bolting along the knockback.
	animal.call("take_damage", 1, Vector2(1, 0) * 120.0)
	var hurt_dir: Vector2 = animal.call("_decide_input", 0.05)
	if hurt_dir.dot(Vector2(1, 0)) <= 0.0:
		_err("%s did not bolt along knockback when struck (dir=%s)" % [want_id, hurt_dir])
	else:
		print("  [ok] %s bolts along the knockback when struck" % want_id)
	# Free immediately (not queue_free): the next animal's check runs in this same
	# frame, and a lingering dummy in the "player" group would be picked up by
	# get_first_node_in_group() and mask the next animal's threat response.
	dummy.free()

# --- Faction clash ----------------------------------------------------------

func _check_clash() -> void:
	var enc := load(CLASH) as EncounterData
	if enc == null:
		_err("cannot load wild_clash.tres as EncounterData")
		return
	var factions := {}
	for path in enc.enemy_paths:
		var ps := load(path) as PackedScene
		if ps == null:
			_err("clash references missing enemy scene %s" % path)
			continue
		var e := ps.instantiate()
		var f: StringName = e.get("faction")
		factions[f] = true
		e.queue_free()
	if not (Faction.BEAST in factions) or not (Faction.BANDIT in factions):
		_err("wild_clash should mix BEAST and BANDIT (got %s)" % [factions.keys()])
	elif not Faction.hostile(Faction.BEAST, Faction.BANDIT):
		_err("BEAST and BANDIT are not hostile — the clash wouldn't fight")
	else:
		print("  [ok] wild_clash mixes mutually-hostile BEAST + BANDIT")

# --- Biome wiring -----------------------------------------------------------

func _check_biome() -> void:
	var biome := load(DEEPWOOD) as BiomeData
	if biome == null:
		_err("cannot load deepwood biome")
		return
	if biome.max_wildlife <= 0 or biome.wildlife_paths.is_empty():
		_err("deepwood has no wildlife wired in")
	else:
		var rng := RandomNumberGenerator.new()
		var picked: String = biome.pick_wildlife_path(rng)
		if picked.is_empty() or not ResourceLoader.exists(picked):
			_err("deepwood.pick_wildlife_path returned no valid scene")
		else:
			print("  [ok] deepwood spawns wildlife (%d-%d)" % [biome.min_wildlife, biome.max_wildlife])
	var has_herb := false
	var has_mush := false
	for g in biome.gather_paths:
		if String(g).ends_with("herb.tres"):
			has_herb = true
		if String(g).ends_with("wild_mushroom.tres"):
			has_mush = true
	if has_herb and has_mush and biome.max_gather > 0:
		print("  [ok] deepwood scatters herb + mushroom forage (%d-%d)" % [biome.min_gather, biome.max_gather])
	else:
		_err("deepwood forage missing (herb=%s mushroom=%s max_gather=%d)" % [has_herb, has_mush, biome.max_gather])

# --- Helpers ----------------------------------------------------------------

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)

func _done() -> void:
	if _fail == 0:
		print("\nRESULT: PASS - wildlife flee/graze/loot, tier no-op, clash factions, biome wiring all hold")
	else:
		print("\nRESULT: FAIL - %d problem(s)" % _fail)
	quit(_fail)
