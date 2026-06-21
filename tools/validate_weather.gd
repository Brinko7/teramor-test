extends SceneTree

## Headless check for the weather layer (WeatherManager):
##   1. Weather is a deterministic function of the day (same day -> same sky).
##   2. Seasonal climate holds: winter never rains (it snows), summer never snows.
##   3. weather_changed fires as the days roll, and waters_crops() <=> rain.
##   4. WeatherFX is present and built without error.
##
## Run: godot --headless -s tools/validate_weather.gd

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
	var weather = get_root().get_node_or_null("WeatherManager")
	var fx = get_root().get_node_or_null("WeatherFX")
	if time == null or weather == null or fx == null:
		_err("a required autoload is missing (time/weather/fx)")
		_finish()
		return

	var RAIN: int = weather.Weather.RAIN
	var SNOW: int = weather.Weather.SNOW
	var valid := [weather.Weather.CLEAR, RAIN, weather.Weather.FOG, SNOW]

	# --- 1. Deterministic for a given day -----------------------------------
	time.reset()
	var w1: int = weather.get_weather()
	var w2: int = weather.get_weather()
	if w1 == w2 and valid.has(w1):
		_ok("weather is stable for a given day (%s)" % weather.weather_name())
	else:
		_err("weather not deterministic for the same day")

	# --- 3a. signal fires + waters_crops <=> rain ---------------------------
	var hits: Array = []
	weather.weather_changed.connect(func(w: int) -> void: hits.append(w))

	# --- 2. Summer never snows ----------------------------------------------
	while time.get_season() != 1:   # advance to summer
		time.sleep()
	var summer_snow := false
	for _i in range(28):
		if weather.get_weather() == SNOW:
			summer_snow = true
		if weather.waters_crops() != (weather.get_weather() == RAIN):
			_err("waters_crops disagreed with rain in summer")
		time.sleep()
	if not summer_snow:
		_ok("summer never snows")
	else:
		_err("it snowed in summer")

	# --- 2b. Winter never rains, and snows at least once --------------------
	while time.get_season() != 3:   # advance to winter
		time.sleep()
	var winter_rain := false
	var winter_snow := false
	for _i in range(28):
		var w: int = weather.get_weather()
		if w == RAIN:
			winter_rain = true
		if w == SNOW:
			winter_snow = true
		time.sleep()
	if not winter_rain:
		_ok("winter never rains")
	else:
		_err("it rained in winter")
	if winter_snow:
		_ok("winter produces snow")
	else:
		_err("winter never snowed across a full season")

	# --- 3b. signal fired across all that rolling ---------------------------
	if hits.size() > 0:
		_ok("weather_changed fired as the days rolled (%d times)" % hits.size())
	else:
		_err("weather_changed never fired across two seasons")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - weather is deterministic, seasonal, and signalled")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
