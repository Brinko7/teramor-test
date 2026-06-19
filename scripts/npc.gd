extends Area2D

## A talkable NPC. Implements the shared INTERACT contract: it lives on
## collision layer 6 (the "interactable" group) and exposes `interact(player)`.
##
## When `data` (an NpcData resource) is set, the NPC drives the rich social loop:
## a branching menu of Talk / story topics / Give a gift / Goodbye, feeding the
## Relationships and Story autoloads. When `data` is null it falls back to the
## legacy flat `lines` list so older scenes keep working.

## Friendship points granted per gift category.
const GIFT_POINTS := {"loved": 80, "liked": 40, "neutral": 20, "disliked": -20}

@export var data: NpcData = null

# --- Legacy fallback (used only when `data` is null) -------------------------
@export var speaker_name: String = "Villager"
@export var lines: PackedStringArray = PackedStringArray()
@export var offered_quest: Quest = null

# --- Daily schedule (home + routed waypoints by time-of-day) ----------------
## `schedule` maps a TimeManager.Period (int 0-3) to the name of a Marker2D in
## the "npc_waypoint" group placed in the scene. Periods absent from the map (or
## an empty target) fall back to `home_waypoint`, then to the placed position.
## The NPC snaps to the right spot for the current time on load, then walks
## between waypoints as the day's periods change. NPCs with no schedule stay put
## (processing is disabled), so legacy townsfolk are unaffected.
@export var home_waypoint: String = ""
@export var schedule: Dictionary = {}
@export var walk_speed: float = 34.0

const _ROW_DOWN := 0
const _ROW_UP := 1
const _ROW_LEFT := 2
const _ROW_RIGHT := 3
const _WALK_FRAMES := [0, 1, 0, 2]
const _ANIM_FPS := 6.0
const _ARRIVE_DIST := 2.0

var _inventory: Inventory = null
var _sprite: Sprite2D = null
var _home_position: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO
var _facing_row: int = _ROW_DOWN
var _anim_time: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	_sprite = $Sprite2D as Sprite2D
	if data != null and _sprite != null:
		if data.sprite_texture != null:
			_sprite.texture = data.sprite_texture
		_sprite.modulate = data.tint
	_setup_schedule()

func _setup_schedule() -> void:
	_home_position = global_position
	var routed: bool = not schedule.is_empty() or home_waypoint != ""
	if not routed:
		set_process(false)
		return
	# Snap to the spot appropriate for the current time, then walk from there.
	_target_position = _resolve_target(TimeManager.get_period())
	global_position = _target_position
	TimeManager.period_changed.connect(_on_period_changed)

func _on_period_changed(period: int) -> void:
	_target_position = _resolve_target(period)

func _resolve_target(period: int) -> Vector2:
	var point_name: String = String(schedule.get(period, home_waypoint))
	if point_name == "":
		return _home_position
	var marker := _find_waypoint(point_name)
	return marker.global_position if marker != null else _home_position

func _find_waypoint(point_name: String) -> Node2D:
	for n: Node in get_tree().get_nodes_in_group("npc_waypoint"):
		if n is Node2D and n.name == point_name:
			return n as Node2D
	return null

func _process(delta: float) -> void:
	var to_target: Vector2 = _target_position - global_position
	var dist: float = to_target.length()
	if dist <= _ARRIVE_DIST:
		_animate(delta, false)
		return
	var dir: Vector2 = to_target / dist
	var step: float = walk_speed * delta
	if step >= dist:
		global_position = _target_position
	else:
		global_position += dir * step
	_update_facing(dir)
	_animate(delta, true)

func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_facing_row = _ROW_RIGHT if dir.x > 0.0 else _ROW_LEFT
	else:
		_facing_row = _ROW_DOWN if dir.y > 0.0 else _ROW_UP

func _animate(delta: float, moving: bool) -> void:
	if _sprite == null:
		return
	if not moving:
		_anim_time = 0.0
		_sprite.frame = _facing_row * _sprite.hframes
		return
	_anim_time += delta * _ANIM_FPS
	var col: int = _WALK_FRAMES[int(_anim_time) % _WALK_FRAMES.size()]
	_sprite.frame = _facing_row * _sprite.hframes + col

## Called by the player when interacted with.
func interact(player) -> void:
	if data == null:
		_legacy_interact()
		return
	_inventory = player.get_node_or_null("Inventory") as Inventory

	var first_meet: bool = not Relationships.is_known(data.id)
	Relationships.meet(data.id, data.display_name)

	var intro: Array = []
	if first_meet and data.met_line != "":
		intro.append({"text": data.met_line})

	UIManager.dialogue.start_conversation(intro, _build_main_menu, data.display_name)

# --- Menu construction ------------------------------------------------------

func _build_main_menu() -> Dictionary:
	var hearts: int = Relationships.get_hearts(data.id)
	var choices: Array = []

	choices.append({"text": "Talk", "effect": _do_talk, "then": _talk_lines(hearts)})

	for topic: Dictionary in data.topics:
		if _topic_available(topic, hearts):
			choices.append({
				"text": String(topic.get("label", "...")),
				"effect": _apply_topic.bind(topic),
				"then": _lines_from(topic.get("lines", [])),
			})

	if not Relationships.has_gifted_today(data.id) and _has_giftables():
		choices.append({"text": "Give a gift", "submenu": _build_gift_menu})
	elif Relationships.has_gifted_today(data.id):
		choices.append({
			"text": "Give a gift",
			"then": [{"text": "You've already given me something today."}],
		})

	choices.append({"text": "Goodbye", "close": true, "then": [{"text": data.farewell}]})
	return {"text": data.greeting, "choices": choices}

func _build_gift_menu() -> Dictionary:
	var choices: Array = []
	if _inventory != null:
		var seen: Dictionary = {}
		for slot: Dictionary in _inventory.slots:
			if slot.is_empty():
				continue
			var item: Item = slot["item"]
			if seen.has(item.id):
				continue
			seen[item.id] = true
			var count: int = _inventory.count_of(item.id)
			choices.append({
				"text": "%s (x%d)" % [item.name, count],
				"effect": _give_gift.bind(item),
				"then": [{"text": _reaction_line(item)}],
				"back": true,
			})
	choices.append({"text": "Never mind", "back": true})
	return {"text": "What would you like to give?", "choices": choices}

# --- Effects ----------------------------------------------------------------

func _do_talk() -> void:
	Relationships.try_talk(data.id)

func _apply_topic(topic: Dictionary) -> void:
	var affinity: int = int(topic.get("affinity", 0))
	if affinity != 0:
		Relationships.add_points(data.id, affinity)
	var set_flag: String = String(topic.get("set_flag", ""))
	if set_flag != "":
		Story.set_flag(StringName(set_flag))
	var quest_path: String = String(topic.get("start_quest", ""))
	if quest_path != "":
		var quest := load(quest_path) as Quest
		if quest != null:
			QuestManager.start_quest(quest)

func _give_gift(item: Item) -> void:
	if _inventory == null:
		return
	if not _inventory.consume_items(item.id, 1):
		return
	var category: String = data.gift_reaction(item.id)
	Relationships.add_points(data.id, int(GIFT_POINTS.get(category, GIFT_POINTS["neutral"])))
	Relationships.mark_gifted(data.id)

# --- Helpers ----------------------------------------------------------------

func _talk_lines(hearts: int) -> Array:
	var packed: PackedStringArray = data.talk_lines_for_hearts(hearts)
	if packed.is_empty():
		return [{"text": "..."}]
	return _lines_from(packed)

func _lines_from(raw) -> Array:
	var nodes: Array = []
	for line: String in PackedStringArray(raw):
		nodes.append({"text": line})
	return nodes

func _reaction_line(item: Item) -> String:
	var category: String = data.gift_reaction(item.id)
	var template: String = ""
	match category:
		"loved": template = data.loved_line
		"liked": template = data.liked_line
		"disliked": template = data.disliked_line
		_: template = data.neutral_line
	if template.contains("%s"):
		return template % item.name
	return template

func _topic_available(topic: Dictionary, hearts: int) -> bool:
	var require_flag: String = String(topic.get("require_flag", ""))
	if require_flag != "" and not Story.has_flag(StringName(require_flag)):
		return false
	var forbid_flag: String = String(topic.get("forbid_flag", ""))
	if forbid_flag != "" and Story.has_flag(StringName(forbid_flag)):
		return false
	var set_flag: String = String(topic.get("set_flag", ""))
	if set_flag != "" and Story.has_flag(StringName(set_flag)):
		return false  # one-shot topic already seen
	if hearts < int(topic.get("require_hearts", 0)):
		return false
	return true

func _has_giftables() -> bool:
	if _inventory == null:
		return false
	for slot: Dictionary in _inventory.slots:
		if not slot.is_empty():
			return true
	return false

func _legacy_interact() -> void:
	if offered_quest != null and not QuestManager.is_active(offered_quest.id) \
			and not QuestManager.is_completed(offered_quest.id):
		QuestManager.start_quest(offered_quest)
	UIManager.dialogue.start(lines, speaker_name)
