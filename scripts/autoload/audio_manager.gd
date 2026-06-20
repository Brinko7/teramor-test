extends Node

## Autoload `AudioManager`. Turns gameplay into sound the same way CombatFX turns it
## into juice: it listens on the `Events` bus and plays SFX, so gameplay code stays
## clean — it just reports outcomes. SFX are the bespoke audioforge bakes
## (assets/audio/sfx/, regenerate via `python3 tools/audioforge.py`), played on the
## **SFX** bus through a small round-robin pool so overlapping one-shots don't cut
## each other off. A little random pitch per shot keeps repeats from machine-gunning.
##
## Combat SFX are **player-gated** exactly like CombatFX: a faction brawl off in the
## trees deals real damage but stays silent, so the soundscape tracks *your* fight.
## Bus volumes are settable (set_bus_volume_linear) for the options sliders to come.

const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 12

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}  # name -> AudioStream (null if missing)

func _ready() -> void:
	# Keep playing while the tree is paused (menus), like the other feedback autoloads.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	Events.damage_dealt.connect(_on_damage)
	Events.enemy_killed.connect(_on_kill)
	Events.melee_swung.connect(_on_swing)
	Events.step_puff.connect(_on_step)
	Events.item_collected.connect(_on_pickup)
	Events.item_crafted.connect(_on_craft)
	Events.player_leveled_up.connect(_on_level_up)
	Events.player_dodged.connect(_on_dodge)

# --- Playback ---------------------------------------------------------------

## Play a baked SFX by name (no extension), optionally trimmed/boosted and pitched.
func play(sfx_name: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _stream(sfx_name)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

## UI feedback (clicks/confirms), a touch quieter than gameplay SFX.
func play_ui(sfx_name: StringName = &"ui_click") -> void:
	play(sfx_name, -3.0)

func _stream(sfx_name: StringName) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var path := SFX_DIR + String(sfx_name) + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[sfx_name] = s
	return s

func _wobble(spread: float = 0.06) -> float:
	return 1.0 + randf_range(-spread, spread)

# --- Options hooks (for the future sliders) ---------------------------------

## Set a bus's volume from a 0..1 slider value (0 = silent).
func set_bus_volume_linear(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var l := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, l <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(l, 0.0001)))

func get_bus_volume_linear(bus_name: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 0.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

# --- Events handlers --------------------------------------------------------

func _on_damage(_pos: Vector2, _amount: int, to_enemy: bool, player_involved: bool) -> void:
	if not player_involved:
		return  # ambient faction fights stay silent, mirroring CombatFX
	play(&"hit_enemy" if to_enemy else &"hit_player", 0.0, _wobble())

func _on_kill(_enemy_id: StringName, _xp: int, _pos: Vector2, by_player: bool) -> void:
	if not by_player:
		return
	play(&"death", 0.0, _wobble(0.05))

func _on_swing(_pos: Vector2, _dir: Vector2, by_player: bool) -> void:
	if not by_player:
		return
	play(&"swing", -2.0, _wobble())

func _on_step(_pos: Vector2) -> void:
	play(&"step", -8.0, _wobble(0.1))  # footsteps sit low under everything

func _on_pickup(_item_id: StringName, _count: int) -> void:
	play(&"pickup", -2.0, _wobble(0.04))

func _on_craft(_item_id: StringName) -> void:
	play(&"craft", -1.0)

func _on_level_up(_new_level: int) -> void:
	play(&"levelup", 0.0)

func _on_dodge(_pos: Vector2) -> void:
	play(&"dodge", -3.0, _wobble(0.05))
