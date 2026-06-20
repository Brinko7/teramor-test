extends Node

## Autoload `MusicManager`. The single owner of the **Music** and **Ambience**
## buses — the audio twin of CombatFX/AudioManager for the soundscape's bed rather
## than its hits. It holds one looping layer per bus and **crossfades** between
## tracks as the player moves between zones and day turns to night.
##
## Tracks are the bespoke audioforge loops (`assets/audio/music/`,
## `assets/audio/ambience/`; regenerate via `python3 tools/audioforge.py`). Like the
## rest of the audio stack, gameplay never references this directly: each world
## scene just announces its mood in `_ready` via `enter_zone(zone)`, and the
## day/night bed follows `TimeManager`. Volumes ride the Music/Ambience buses, so
## the options sliders (AudioManager.set_bus_volume_linear) drive them for free.

const MUSIC_DIR := "res://assets/audio/music/"
const AMB_DIR := "res://assets/audio/ambience/"

## Zone id -> music track. Zones are declared by scene roots (see enter_zone).
const ZONE_MUSIC := {
	&"title": &"theme_camp", &"camp": &"theme_camp", &"interior": &"theme_camp",
	&"town": &"theme_town", &"wild": &"theme_wild", &"cave": &"theme_wild",
	&"cursed": &"theme_cursed", &"finale": &"theme_cursed",
}

## Outdoor zones whose ambience bed tracks the time of day.
const OUTDOOR: Array[StringName] = [&"camp", &"town", &"wild"]

var _music: _Layer
var _amb: _Layer
var _zone: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing/fading while paused (menus)
	_music = _Layer.new("Music", MUSIC_DIR)
	_amb = _Layer.new("Ambience", AMB_DIR)
	add_child(_music)
	add_child(_amb)
	TimeManager.period_changed.connect(_on_period_changed)

## A scene announces its mood. Re-entering the same zone is a no-op (the layer
## only crossfades when the chosen track actually changes), so walking through a
## door into the same kind of place never restarts the music.
func enter_zone(zone: StringName) -> void:
	_zone = zone
	_music.play(ZONE_MUSIC.get(zone, &"theme_town"))
	_amb.play(_ambience_for(zone))

func get_zone() -> StringName:
	return _zone

## Stop both layers (e.g. a silent beat). Kept for future cutscene control.
func silence() -> void:
	_music.play(&"")
	_amb.play(&"")

func _ambience_for(zone: StringName) -> StringName:
	if OUTDOOR.has(zone):
		return &"amb_night" if TimeManager.is_night() else &"amb_day"
	if zone == &"cave":
		return &"amb_cave"
	if zone == &"cursed" or zone == &"finale":
		return &"amb_cursed"
	return &""  # interior / title: no outdoor bed

func _on_period_changed(_period: int) -> void:
	if OUTDOOR.has(_zone):
		_amb.play(_ambience_for(_zone))

# --- One looping bus layer with an A/B crossfade ----------------------------

class _Layer extends Node:
	const FADE := 1.4          # crossfade seconds
	const QUIET := -60.0       # "off" volume

	var _bus: String
	var _dir: String
	var _a: AudioStreamPlayer
	var _b: AudioStreamPlayer
	var _active: AudioStreamPlayer
	var _current: StringName = &""
	var _cache: Dictionary = {}

	func _init(bus: String, dir: String) -> void:
		_bus = bus
		_dir = dir

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_a = _make_player()
		_b = _make_player()
		_active = _a

	func _make_player() -> AudioStreamPlayer:
		var p := AudioStreamPlayer.new()
		p.bus = _bus
		p.volume_db = QUIET
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		return p

	## Crossfade to `track` (a file stem). &"" fades the layer out to silence.
	func play(track: StringName) -> void:
		if track == _current:
			return
		_current = track
		var incoming: AudioStreamPlayer = _b if _active == _a else _a
		var outgoing: AudioStreamPlayer = _active

		if outgoing.playing:
			var out_tw := create_tween()
			out_tw.tween_property(outgoing, "volume_db", QUIET, FADE)
			out_tw.tween_callback(outgoing.stop)

		if track == &"":
			_active = incoming
			return

		var stream := _load(track)
		if stream == null:
			_active = incoming
			return
		incoming.stop()
		incoming.stream = stream
		incoming.volume_db = QUIET
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", 0.0, FADE)
		_active = incoming

	func _load(track: StringName) -> AudioStream:
		if _cache.has(track):
			return _cache[track]
		var path: String = _dir + String(track) + ".wav"
		var s: AudioStream = null
		if ResourceLoader.exists(path):
			s = load(path)
			# Force a seamless forward loop on the imported WAV (the bake is already
			# crossfade-wrapped; this just turns looping on).
			if s is AudioStreamWAV:
				var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(round(w.get_length() * w.mix_rate))
				s = w
		_cache[track] = s
		return s
