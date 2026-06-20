extends SceneTree

## Headless check for the season layer:
##   1. The calendar derives season / day-of-season / year correctly from the day,
##      and rolls over (Spring 28 -> Summer 1, and into Year 2).
##   2. season_changed fires on a season crossing.
##   3. CropData.grows_in honours a crop's authored seasons.
##   4. FarmManager pauses an out-of-season crop and advances an in-season one.
##   5. Every authored festival has a valid season + day, and SeasonManager loads them.
##
## Run: godot --headless -s tools/validate_seasons.gd
##
## Season ints: SPRING=0, SUMMER=1, AUTUMN=2, WINTER=3.

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

	var time = get_root().get_node_or_null("TimeManager")
	var farm = get_root().get_node_or_null("FarmManager")
	var seasons = get_root().get_node_or_null("SeasonManager")
	if time == null or farm == null or seasons == null:
		_err("a required autoload is missing (time/farm/seasons)")
		_finish()
		return

	# --- 1. Calendar math ----------------------------------------------------
	time.reset()
	if time.get_day() == 1 and time.get_season() == 0 and time.get_day_of_season() == 1 \
			and time.get_year() == 1 and time.format_date() == "Spring 1":
		_ok("day 1 is Spring 1, Year 1")
	else:
		_err("day 1 calendar wrong: '%s' (season %d, dos %d, yr %d)" %
			[time.format_date(), time.get_season(), time.get_day_of_season(), time.get_year()])

	# --- 2. season_changed on the Spring -> Summer crossing ------------------
	var hits: Array = []
	time.season_changed.connect(func(s: int) -> void: hits.append(s))
	for _i in range(27):
		time.sleep()                      # -> day 28
	if time.get_day() == 28 and time.get_season() == 0 and time.get_day_of_season() == 28:
		_ok("day 28 is Spring 28 (still spring all season)")
	else:
		_err("day 28 wrong: '%s'" % time.format_date())
	time.sleep()                          # -> day 29
	if time.get_day() == 29 and time.get_season() == 1 and time.get_day_of_season() == 1:
		_ok("day 29 rolls into Summer 1")
	else:
		_err("day 29 did not roll into Summer 1: '%s'" % time.format_date())
	if hits.has(1):
		_ok("season_changed fired on the Summer crossing")
	else:
		_err("season_changed not emitted crossing into Summer (hits=%s)" % str(hits))

	# --- 1b. Year roll-over --------------------------------------------------
	while time.get_day() < 113:           # 4 seasons * 28 + 1
		time.sleep()
	if time.get_season() == 0 and time.get_day_of_season() == 1 and time.get_year() == 2 \
			and time.format_date() == "Spring 1, Year 2":
		_ok("day 113 is Spring 1, Year 2")
	else:
		_err("year roll wrong: '%s' (yr %d)" % [time.format_date(), time.get_year()])

	# --- 3. CropData.grows_in ------------------------------------------------
	var turnip = load("res://resources/crops/turnip.tres") as CropData
	var wheat = load("res://resources/crops/wheat.tres") as CropData
	if turnip == null or wheat == null:
		_err("turnip/wheat crops failed to load")
		_finish()
		return
	if turnip.grows_in(&"spring") and not turnip.grows_in(&"winter"):
		_ok("turnip grows in spring, not winter")
	else:
		_err("turnip seasons wrong (spring=%s winter=%s)" %
			[turnip.grows_in(&"spring"), turnip.grows_in(&"winter")])
	if wheat.grows_in(&"autumn") and not wheat.grows_in(&"spring"):
		_ok("wheat grows in autumn, not spring")
	else:
		_err("wheat seasons wrong (autumn=%s spring=%s)" %
			[wheat.grows_in(&"autumn"), wheat.grows_in(&"spring")])

	# --- 4. FarmManager pauses out-of-season, advances in-season -------------
	time.reset()                          # Spring, day 1
	farm.reset()
	farm.till("p_wheat"); farm.plant("p_wheat", wheat); farm.water("p_wheat")
	farm.till("p_turnip"); farm.plant("p_turnip", turnip); farm.water("p_turnip")
	time.sleep()                          # -> day 2, still spring
	await process_frame
	if farm.get_days("p_wheat") == 0:
		_ok("wheat paused out of season (spring)")
	else:
		_err("wheat grew out of season: days=%d" % farm.get_days("p_wheat"))
	if farm.get_days("p_turnip") == 1:
		_ok("turnip grew in season (spring)")
	else:
		_err("turnip did not grow in season: days=%d" % farm.get_days("p_turnip"))

	# --- 5. Festival catalog integrity ---------------------------------------
	var fests: Array = seasons.get_festivals()
	if fests.size() >= 1:
		_ok("SeasonManager loaded %d festival(s)" % fests.size())
	else:
		_err("no festivals loaded")
	var valid := true
	for f in fests:
		if not time.SEASON_IDS.has(f.season) or f.day < 1 or f.day > time.DAYS_PER_SEASON:
			valid = false
			_err("festival '%s' has an invalid date (%s %d)" % [String(f.id), String(f.season), f.day])
	if valid and not fests.is_empty():
		_ok("all festivals have a valid season + day")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - season layer works (calendar, signals, crops, festivals)")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
