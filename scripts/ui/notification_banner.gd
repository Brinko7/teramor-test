extends CanvasLayer

## Transient top-of-screen banner for story beats and other one-off announcements
## (chapter changes, awakenings). UIManager-owned; call UIManager.notify(title,
## subtitle). Fades in, holds, fades out — queueing messages so rapid beats don't
## stomp each other. Processes while paused so it works during menus/transitions.

const HOLD := 2.4
const FADE := 0.4

var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _queue: Array = []
var _busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	_build()

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 24.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UITheme.panel_style(0.95)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	_title = UITheme.make_label("", 13, UITheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_subtitle = UITheme.make_label("", 9, UITheme.TEXT)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size = Vector2(260, 0)
	box.add_child(_subtitle)

## Queue a banner. Safe to call any time.
func notify(title: String, subtitle: String = "") -> void:
	_queue.append({"title": title, "subtitle": subtitle})
	if not _busy:
		_play_next()

func _play_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var msg: Dictionary = _queue.pop_front()
	_title.text = String(msg["title"])
	_subtitle.text = String(msg["subtitle"])
	_subtitle.visible = _subtitle.text != ""
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, FADE)
	tw.tween_interval(HOLD)
	tw.tween_property(_panel, "modulate:a", 0.0, FADE)
	tw.tween_callback(_play_next)
