extends Node

## Autoload `SettingsManager`. Owns the player's app-level preferences — audio bus
## volumes, display (fullscreen / vsync), an accessibility screen-shake toggle, and
## key rebindings — and persists them to `user://settings.cfg`, **separate** from the
## game save (settings belong to the install, not the run). It applies everything on
## startup and re-applies + saves whenever a value changes, so the options menu is a
## thin view: it reads/writes here and the effect is immediate and durable.

const PATH := "user://settings.cfg"

## The mixer buses exposed as sliders (Master folds the rest).
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Ambience"]

## Keyboard actions offered for rebinding (combat stays mouse-aimed, so it isn't
## here). Order is the display order in the Controls tab.
const REBINDABLE: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"interact", &"dodge", &"use_item", &"player_menu", &"crafting", &"ability_menu",
]
const ACTION_LABELS := {
	&"move_up": "Move Up", &"move_down": "Move Down", &"move_left": "Move Left",
	&"move_right": "Move Right", &"interact": "Interact", &"dodge": "Dodge",
	&"use_item": "Use Item", &"player_menu": "Open Menu", &"crafting": "Crafting",
	&"ability_menu": "Abilities",
}

## A pleasant default mix (music sits a little under SFX); these are also the
## "Reset to defaults" target.
const DEFAULT_VOLUMES := {&"Master": 1.0, &"Music": 0.8, &"SFX": 1.0, &"Ambience": 0.7}

signal changed   # any setting changed — open panels refresh from this

var _volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
var _fullscreen: bool = false
var _vsync: bool = true
var _screen_shake: bool = true
var _binds: Dictionary = {}          # action (String) -> physical keycode (int) override
var _default_keys: Dictionary = {}   # action (String) -> project-default keycode (int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_snapshot_defaults()
	_load()
	apply_all()

# --- Apply ------------------------------------------------------------------

func apply_all() -> void:
	apply_audio()
	apply_display()
	apply_keybinds()

func apply_audio() -> void:
	for bus: StringName in BUSES:
		AudioManager.set_bus_volume_linear(bus, float(_volumes[bus]))

func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync
		else DisplayServer.VSYNC_DISABLED)

func apply_keybinds() -> void:
	for action: String in _binds:
		_set_action_key(StringName(action), int(_binds[action]))

# --- Audio ------------------------------------------------------------------

func get_volume(bus: StringName) -> float:
	return float(_volumes.get(bus, 1.0))

func set_volume(bus: StringName, value: float) -> void:
	_volumes[bus] = clampf(value, 0.0, 1.0)
	AudioManager.set_bus_volume_linear(bus, _volumes[bus])
	_save()
	changed.emit()

# --- Display / accessibility ------------------------------------------------

func is_fullscreen() -> bool:
	return _fullscreen

func set_fullscreen(on: bool) -> void:
	_fullscreen = on
	apply_display()
	_save()
	changed.emit()

func is_vsync() -> bool:
	return _vsync

func set_vsync(on: bool) -> void:
	_vsync = on
	apply_display()
	_save()
	changed.emit()

## Honoured by the player camera (camera_shake.gd) so shake-sensitive players can
## turn the jolt off without losing the rest of the combat feedback.
func screen_shake_enabled() -> bool:
	return _screen_shake

func set_screen_shake(on: bool) -> void:
	_screen_shake = on
	_save()
	changed.emit()

# --- Key rebinding ----------------------------------------------------------

## Current physical keycode bound to an action (override, else project default).
func key_for(action: StringName) -> int:
	return int(_binds.get(String(action), _default_keys.get(String(action), 0)))

func key_name(action: StringName) -> String:
	var code: int = key_for(action)
	if code == 0:
		return "—"
	return OS.get_keycode_string(code)

func rebind(action: StringName, physical_keycode: int) -> void:
	if physical_keycode == 0:
		return
	_binds[String(action)] = physical_keycode
	_set_action_key(action, physical_keycode)
	_save()
	changed.emit()

# --- Reset ------------------------------------------------------------------

func reset_defaults() -> void:
	_volumes = DEFAULT_VOLUMES.duplicate()
	_fullscreen = false
	_vsync = true
	_screen_shake = true
	_binds.clear()
	for action: StringName in REBINDABLE:
		_set_action_key(action, int(_default_keys.get(String(action), 0)))
	apply_audio()
	apply_display()
	_save()
	changed.emit()

# --- Internals --------------------------------------------------------------

func _snapshot_defaults() -> void:
	for action: StringName in REBINDABLE:
		_default_keys[String(action)] = _first_key(action)

func _first_key(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			return k.physical_keycode if k.physical_keycode != 0 else k.keycode
	return 0

## Replace an action's keyboard event(s) with one physical key, leaving any
## mouse/joypad events intact.
func _set_action_key(action: StringName, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key)

func _save() -> void:
	var cfg := ConfigFile.new()
	for bus: StringName in BUSES:
		cfg.set_value("audio", String(bus), _volumes[bus])
	cfg.set_value("display", "fullscreen", _fullscreen)
	cfg.set_value("display", "vsync", _vsync)
	cfg.set_value("display", "screen_shake", _screen_shake)
	for action: String in _binds:
		cfg.set_value("controls", action, _binds[action])
	cfg.save(PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for bus: StringName in BUSES:
		_volumes[bus] = clampf(float(cfg.get_value("audio", String(bus), _volumes[bus])), 0.0, 1.0)
	_fullscreen = bool(cfg.get_value("display", "fullscreen", _fullscreen))
	_vsync = bool(cfg.get_value("display", "vsync", _vsync))
	_screen_shake = bool(cfg.get_value("display", "screen_shake", _screen_shake))
	if cfg.has_section("controls"):
		for action: String in cfg.get_section_keys("controls"):
			_binds[action] = int(cfg.get_value("controls", action))
