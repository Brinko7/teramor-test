extends CanvasLayer

## Global dialogue box. Pauses gameplay while open. Supports two modes:
##
##   start(lines, speaker)                  — legacy linear playback, one line per
##                                            `interact` press.
##   start_conversation(intro, menu_provider, speaker)
##                                          — plays the intro lines, then shows a
##                                            choice menu rebuilt each time from
##                                            `menu_provider` (a Callable returning
##                                            a menu node). Picking a choice runs
##                                            its effect, plays its follow-up
##                                            lines, then returns to the menu until
##                                            a choice marked `close` is taken.
##
## Conversation data shapes:
##   line node   := { "text": String, "speaker"?: String }
##   menu node   := { "text": String, "speaker"?: String, "choices": Array }
##   choice      := { "text": String, "effect"?: Callable, "then"?: Array,
##                    "submenu"?: Callable, "back"?: bool, "close"?: bool }
##
## `submenu` pushes a nested menu provider; `back` pops to the parent menu;
## `close` ends the conversation. A choice's `then` lines play before the
## navigation takes effect.

signal finished

const LINE_TOP := -78.0

@onready var _panel: PanelContainer = $Panel
@onready var _speaker_label: Label = $Panel/Margin/VBox/Speaker
@onready var _body_label: RichTextLabel = $Panel/Margin/VBox/Body
@onready var _prompt_label: Label = $Panel/Margin/VBox/Prompt
var _choices_box: VBoxContainer

var _queue: Array = []
var _continuation: Callable = Callable()
var _menu_stack: Array[Callable] = []
var _default_speaker: String = ""
var _active: bool = false
var _choosing: bool = false
## Frame dialogue opened on; input that same frame is ignored so the opening key
## press does not also advance.
var _start_frame: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_panel.visible = false
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 2)
	_choices_box.visible = false
	# Insert the choice list between Body and Prompt.
	var vbox: VBoxContainer = $Panel/Margin/VBox
	vbox.add_child(_choices_box)
	vbox.move_child(_choices_box, _prompt_label.get_index())

func is_active() -> bool:
	return _active

# --- Public entry points ----------------------------------------------------

func start(lines, speaker: String = "") -> void:
	var packed := PackedStringArray(lines)
	if packed.is_empty():
		return
	var nodes: Array = []
	for line: String in packed:
		nodes.append({"text": line})
	_default_speaker = speaker
	_menu_stack.clear()
	_open()
	_play(nodes, _close)

func start_conversation(intro: Array, menu_provider: Callable, speaker: String = "") -> void:
	_default_speaker = speaker
	_menu_stack = [menu_provider]
	_open()
	_play(intro, _show_menu)

# --- Flow -------------------------------------------------------------------

func _open() -> void:
	_active = true
	_start_frame = Engine.get_process_frames()
	_panel.visible = true
	get_tree().paused = true

func _play(nodes: Array, continuation: Callable) -> void:
	_queue = nodes.duplicate()
	_continuation = continuation
	_advance_queue()

func _advance_queue() -> void:
	if _queue.is_empty():
		if _continuation.is_valid():
			_continuation.call()
		else:
			_close()
		return
	var node: Dictionary = _queue.pop_front()
	_render_line(node)

func _render_line(node: Dictionary) -> void:
	_choosing = false
	_clear_choices()
	_choices_box.visible = false
	_panel.offset_top = LINE_TOP
	_speaker_label.text = node.get("speaker", _default_speaker)
	_speaker_label.visible = _speaker_label.text != ""
	_body_label.text = node.get("text", "")
	var last: bool = _queue.is_empty() and not _has_menu()
	_prompt_label.visible = true
	_prompt_label.text = "[E] Close" if last else "[E] Continue"

func _has_menu() -> bool:
	return not _menu_stack.is_empty()

func _show_menu() -> void:
	if _menu_stack.is_empty():
		_close()
		return
	var provider: Callable = _menu_stack.back()
	if not provider.is_valid():
		_close()
		return
	var node: Dictionary = provider.call()
	var choices: Array = node.get("choices", [])
	if choices.is_empty():
		_close()
		return
	_render_choices(node, choices)

func _render_choices(node: Dictionary, choices: Array) -> void:
	_choosing = true
	_speaker_label.text = node.get("speaker", _default_speaker)
	_speaker_label.visible = _speaker_label.text != ""
	_body_label.text = node.get("text", "")
	_prompt_label.visible = false
	_clear_choices()
	_choices_box.visible = true
	_panel.offset_top = clampf(-(54.0 + choices.size() * 20.0), -210.0, LINE_TOP)
	var first: Button = null
	for choice: Dictionary in choices:
		var button := Button.new()
		button.text = String(choice.get("text", "..."))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_on_choice_pressed.bind(choice))
		_choices_box.add_child(button)
		if first == null:
			first = button
	if first != null:
		first.grab_focus()

func _on_choice_pressed(choice: Dictionary) -> void:
	_choosing = false
	_clear_choices()
	_choices_box.visible = false
	var effect: Variant = choice.get("effect")
	if effect is Callable and (effect as Callable).is_valid():
		(effect as Callable).call()
	# Apply menu navigation before the follow-up lines play, so when the line
	# queue drains the continuation lands on the right menu.
	var closing: bool = bool(choice.get("close", false))
	if not closing:
		var submenu: Variant = choice.get("submenu")
		if submenu is Callable and (submenu as Callable).is_valid():
			_menu_stack.push_back(submenu)
		elif bool(choice.get("back", false)) and _menu_stack.size() > 1:
			_menu_stack.pop_back()
	var follow: Array = choice.get("then", [])
	var cont: Callable = _close if closing else _show_menu
	_play(follow, cont)

func _clear_choices() -> void:
	for child: Node in _choices_box.get_children():
		child.queue_free()

func _close() -> void:
	_active = false
	_choosing = false
	_menu_stack.clear()
	_clear_choices()
	_choices_box.visible = false
	_panel.visible = false
	_panel.offset_top = LINE_TOP
	get_tree().paused = false
	finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _choosing:
		return
	if Engine.get_process_frames() == _start_frame:
		return
	if event.is_action_pressed("interact"):
		_advance_queue()
		get_viewport().set_input_as_handled()
