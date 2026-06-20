extends SceneTree

## Headless check for the recruit-the-camp loop (CampManager). Proves that:
##   1. A recruited FARMHAND keeps a planted crop watered across days and carries
##      the ripe harvest into the shared stash — with no player action.
##   2. A recruited FORAGER deposits wild goods into the stash each dawn.
##   3. A RESTING member does no chores.
##   4. The roster survives a save/load round-trip.
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
	# A turnip matures in 3 watered days; the farmhand re-waters each night, so
	# a few sleeps should yield a harvest into the stash with no player input.
	for _i in range(5):
		time.sleep()
		await process_frame
	var gained: int = storage.stash.count_of(produce_id) - start
	if gained > 0:
		_ok("farmhand harvested %d %s into the stash unattended" % [gained, crop.produce.name])
	else:
		_err("farmhand never delivered a harvest to the stash (gained %d)" % gained)

	# --- 2. Forager gathers --------------------------------------------------
	camp.reset()
	storage.reset()
	var herb := load("res://resources/items/herb.tres") as Item
	camp.recruit(&"test_forager", "Test Forager", camp.ROLE_FORAGER)
	var herb_before: int = storage.stash.count_of(herb.id)
	time.sleep()
	await process_frame
	if storage.stash.count_of(herb.id) > herb_before:
		_ok("forager deposited wild goods into the stash")
	else:
		_err("forager brought back nothing")

	# --- 3. A resting member does nothing -----------------------------------
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

	# --- 4. Persistence round-trip ------------------------------------------
	camp.reset()
	camp.recruit(&"keepme", "Keep Me", camp.ROLE_FORAGER)
	var snap: Dictionary = camp.save_state()
	camp.reset()
	if camp.is_recruited(&"keepme"):
		_err("reset did not clear the roster")
	camp.load_state(snap)
	if camp.is_recruited(&"keepme") and String(camp.get_role(&"keepme")) == "forager":
		_ok("roster survived a save/load round-trip")
	else:
		_err("roster did not restore from save_state")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - recruit-the-camp loop works (tend, forage, rest, persist)")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
