extends SceneTree

## Headless check for the recruit-the-camp loop + camp economy (CampManager):
##   1. A FARMHAND keeps a planted crop watered across days and carries the ripe
##      harvest to the stash — no player action.
##   2. A FORAGER deposits wild goods, a WOODCUTTER deposits materials.
##   3. A COOK turns stash produce into Camp Stew.
##   4. A RESTING member does no chores.
##   5. UPGRADES: the recruit cap is enforced; buying a bunkhouse spends stash
##      goods and raises the cap; irrigation widens a farmhand's reach.
##   6. The roster + owned upgrades survive a save/load round-trip.
##
## Run: godot --headless -s tools/validate_camp.gd

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _ok(m: String) -> void:
	print("  ok: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	var camp = get_root().get_node_or_null("CampManager")
	var farm = get_root().get_node_or_null("FarmManager")
	var storage = get_root().get_node_or_null("StorageManager")
	var time = get_root().get_node_or_null("TimeManager")
	if camp == null or farm == null or storage == null or time == null:
		_err("a required autoload is missing (camp/farm/storage/time)")
		_finish()
		return

	var crop = load("res://resources/crops/turnip.tres") as CropData
	if crop == null or crop.produce == null:
		_err("turnip crop/produce failed to load")
		_finish()
		return
	var produce_id: StringName = crop.produce.id

	# --- 1. Farmhand tends + harvests ---------------------------------------
	camp.reset()
	farm.reset()
	storage.reset()
	var plot := "camp_test_plot"
	farm.till(plot)
	farm.plant(plot, crop)
	farm.water(plot)
	camp.recruit(&"test_hand", "Test Hand", camp.ROLE_FARMHAND)
	if not camp.is_recruited(&"test_hand"):
		_err("recruit() did not enlist the farmhand")
	var start: int = storage.stash.count_of(produce_id)
	for _i in range(5):
		time.sleep()
		await process_frame
	if storage.stash.count_of(produce_id) - start > 0:
		_ok("farmhand harvested produce into the stash unattended")
	else:
		_err("farmhand never delivered a harvest to the stash")

	# --- 2. Forager + woodcutter gather -------------------------------------
	camp.reset()
	storage.reset()
	var herb := load("res://resources/items/herb.tres") as Item
	var stone := load("res://resources/items/stone.tres") as Item
	camp.recruit(&"f", "Forager", camp.ROLE_FORAGER)
	camp.recruit(&"w", "Woodcutter", camp.ROLE_WOODCUTTER)
	time.sleep()
	await process_frame
	if storage.stash.count_of(herb.id) > 0:
		_ok("forager deposited wild goods")
	else:
		_err("forager brought back nothing")
	if storage.stash.count_of(stone.id) > 0:
		_ok("woodcutter deposited materials")
	else:
		_err("woodcutter brought back nothing")

	# --- 3. Cook turns produce into stew ------------------------------------
	camp.reset()
	storage.reset()
	storage.stash.add_item(crop.produce, 4)  # 4 turnips -> up to 2 stews
	camp.recruit(&"cook", "Cook", camp.ROLE_COOK)
	time.sleep()
	await process_frame
	var stew := load("res://resources/items/produce/camp_stew.tres") as Item
	if storage.stash.count_of(stew.id) > 0 and storage.stash.count_of(produce_id) < 4:
		_ok("cook turned %d produce into %d stew" % [4 - storage.stash.count_of(produce_id), storage.stash.count_of(stew.id)])
	else:
		_err("cook produced no stew (stew=%d, produce left=%d)" % [storage.stash.count_of(stew.id), storage.stash.count_of(produce_id)])

	# --- 4. A resting member does nothing -----------------------------------
	camp.reset()
	storage.reset()
	farm.reset()
	farm.till(plot)
	farm.plant(plot, crop)
	farm.water(plot)
	camp.recruit(&"lazy", "Lazy", camp.ROLE_FARMHAND)
	camp.set_active(&"lazy", false)
	time.sleep()
	await process_frame
	if camp.get_last_report().is_empty():
		_ok("resting member skipped chores")
	else:
		_err("resting member did chores anyway: %s" % str(camp.get_last_report()))

	# --- 5. Recruit cap + upgrade purchase ----------------------------------
	camp.reset()
	storage.reset()
	var base_cap: int = camp.get_recruit_cap()
	camp.recruit(&"a", "A", camp.ROLE_FARMHAND)
	camp.recruit(&"b", "B", camp.ROLE_FORAGER)
	if camp.count() == base_cap and not camp.recruit(&"c", "C", camp.ROLE_COOK):
		_ok("recruit cap (%d) is enforced" % base_cap)
	else:
		_err("recruit cap not enforced (cap %d, count %d)" % [base_cap, camp.count()])
	# Stock the stash and buy the bunkhouse (+1 slot).
	var wood := load("res://resources/items/wood.tres") as Item
	storage.stash.add_item(wood, 30)
	if camp.can_afford(&"bunkhouse") and camp.purchase(&"bunkhouse"):
		if camp.get_recruit_cap() == base_cap + 1 and camp.is_owned(&"bunkhouse") and storage.stash.count_of(wood.id) < 30:
			_ok("bunkhouse spent stash wood and raised the cap to %d" % camp.get_recruit_cap())
		else:
			_err("bunkhouse effect/cost did not apply")
		if camp.recruit(&"c", "C", camp.ROLE_COOK):
			_ok("the freed slot allowed a third recruit")
		else:
			_err("could not recruit after raising the cap")
	else:
		_err("could not afford/purchase bunkhouse with 30 wood")
	# Irrigation widens farmhand reach.
	var ppf: int = camp.get_plots_per_farmhand()
	storage.stash.add_item(wood, 20)
	storage.stash.add_item(load("res://resources/items/stone.tres"), 20)
	if camp.purchase(&"irrigation") and camp.get_plots_per_farmhand() > ppf:
		_ok("irrigation widened farmhand reach to %d plots" % camp.get_plots_per_farmhand())
	else:
		_err("irrigation did not raise plots-per-farmhand")

	# --- 6. Persistence round-trip ------------------------------------------
	var snap: Dictionary = camp.save_state()
	camp.reset()
	if camp.is_recruited(&"c") or camp.is_owned(&"bunkhouse"):
		_err("reset did not clear roster/upgrades")
	camp.load_state(snap)
	if camp.is_recruited(&"c") and camp.is_owned(&"bunkhouse") and camp.is_owned(&"irrigation"):
		_ok("roster + owned upgrades survived a save/load round-trip")
	else:
		_err("save/load did not restore roster/upgrades")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - camp loop + economy work (roles, upgrades, cap, persist)")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
