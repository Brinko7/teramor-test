extends SceneTree

## Headless check for the options/settings layer (SettingsManager):
##   1. A volume change applies to the audio bus and persists to settings.cfg.
##   2. A rebind rewrites the action's keyboard event in the InputMap and persists.
##   3. Reset restores the default volume mix and the default key.
##   4. The accessibility screen-shake toggle round-trips.
##
## Run: godot --headless -s tools/validate_settings.gd

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

	var sm = get_root().get_node_or_null("SettingsManager")
	var audio = get_root().get_node_or_null("AudioManager")
	if sm == null or audio == null:
		_err("SettingsManager/AudioManager autoload missing")
		_finish()
		return

	var default_key: int = sm.key_for(&"interact")

	# --- 1. Volume applies + persists ---------------------------------------
	sm.set_volume(&"Music", 0.5)
	if absf(audio.get_bus_volume_linear(&"Music") - 0.5) < 0.05:
		_ok("Music volume applied to the bus")
	else:
		_err("Music bus volume not applied (got %.3f)" % audio.get_bus_volume_linear(&"Music"))
	var cfg := ConfigFile.new()
	if cfg.load(sm.PATH) == OK and absf(float(cfg.get_value("audio", "Music", 1.0)) - 0.5) < 0.001:
		_ok("volume persisted to %s" % sm.PATH)
	else:
		_err("volume did not persist to settings.cfg")

	# --- 2. Rebind rewrites the InputMap + persists -------------------------
	sm.rebind(&"interact", KEY_F)
	if sm.key_for(&"interact") == KEY_F and _action_has_physical(&"interact", KEY_F):
		_ok("rebind set interact -> F in the InputMap")
	else:
		_err("rebind did not update interact in the InputMap")
	cfg = ConfigFile.new()
	if cfg.load(sm.PATH) == OK and int(cfg.get_value("controls", "interact", 0)) == KEY_F:
		_ok("rebind persisted to settings.cfg")
	else:
		_err("rebind did not persist")

	# --- 3. Reset restores defaults -----------------------------------------
	sm.reset_defaults()
	if sm.key_for(&"interact") == default_key and _action_has_physical(&"interact", default_key):
		_ok("reset restored the default interact key")
	else:
		_err("reset did not restore the default key")
	if absf(sm.get_volume(&"Music") - float(sm.DEFAULT_VOLUMES[&"Music"])) < 0.001:
		_ok("reset restored the default volume mix")
	else:
		_err("reset did not restore the default volume")

	# --- 4. Screen-shake accessibility toggle -------------------------------
	sm.set_screen_shake(false)
	var off: bool = not sm.screen_shake_enabled()
	sm.set_screen_shake(true)
	if off and sm.screen_shake_enabled():
		_ok("screen-shake toggle round-trips")
	else:
		_err("screen-shake toggle did not round-trip")

	_finish()

func _action_has_physical(action: StringName, code: int) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == code:
			return true
	return false

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - settings apply, persist, rebind and reset")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
