extends CanvasLayer

## The Cursed Wilds reveal — a one-time cinematic the first time the player crosses
## the threshold. A cutscene is a composed full-screen shot, so it isn't bound by the
## gameplay camera's no-sky clamp: we paint the whole vista (sky / distant Great Tree /
## foreground treeline, baked by tools/gen_wilds_reveal.py) and slow-push in on Tera
## looming above the lesser forest, with a line of narration, then fade to play.
##
## Built code-first (like WeatherFX/CanopyFX). `_ready` composes the layers; `play()`
## runs the sequence, pauses the tree while it runs, and frees itself at the end.

const VW := 480.0
const VH := 270.0
const CENTER := Vector2(240, 135)
const PARCHMENT := Color(0.92, 0.86, 0.72)

var _vista: Node2D
var _treeline: Sprite2D
var _title: Label
var _subtitle: Label
var _fade: ColorRect
var _done: bool = false
# The vista art is composed in a 480x270 space; scale it up to fill the actual
# (now hi-fi 1280x720) viewport. Both are 16:9, so one uniform factor fits exactly.
var _fill: float = 1.0
var _center: Vector2 = Vector2(240, 135)

func _ready() -> void:
	layer = 95  # above the world, HUD and weather; below dialogue (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	var vw := float(int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)))
	var vh := float(int(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	_fill = vw / VW
	_center = Vector2(vw, vh) * 0.5
	_vista = Node2D.new()
	add_child(_vista)
	_add_layer("res://assets/placeholder/wilds_sky.png", Vector2(0, 0))
	# distant tree: base low so only the towering crown clears the treeline
	_add_layer("res://assets/placeholder/great_tree_far.png", Vector2(240 - 110, 286 - 300))
	_add_layer("res://assets/placeholder/wilds_haze.png", Vector2(0, 0))
	_treeline = _add_layer("res://assets/placeholder/wilds_treeline.png", Vector2(-120, 160))

	_title = _make_label("THE GREAT TREE", 206, 18)
	_subtitle = _make_label("Tera — the dying heart of the world, beyond the Thornwall.", 230, 9)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)   # start black; play() reveals
	_fade.size = _center * 2.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_set_zoom(1.0)   # apply the base fill scale so the vista covers the viewport

func _add_layer(path: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.position = pos
	_vista.add_child(s)
	return s

func _make_label(text: String, y: float, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(round(size * _fill)))
	l.add_theme_color_override("font_color", PARCHMENT)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.position = Vector2(0, y * _fill)
	l.size = Vector2(_center.x * 2.0, 24 * _fill)
	l.modulate = Color(1, 1, 1, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

## Run the cinematic: pause the tree, reveal, slow push-in, narration, fade out.
func play() -> void:
	get_tree().paused = true

	var zoom := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	zoom.tween_method(_set_zoom, 1.0, 1.10, 9.5)

	var titles := create_tween()
	titles.tween_interval(1.6)
	titles.tween_property(_title, "modulate:a", 1.0, 1.4)
	titles.tween_interval(0.5)
	titles.tween_property(_subtitle, "modulate:a", 1.0, 1.4)

	# gentle horizontal drift on the foreground forest for parallax life
	var drift := create_tween()
	drift.tween_property(_treeline, "position:x", -132.0, 9.5)

	var seq := create_tween()
	seq.tween_property(_fade, "color:a", 0.0, 1.6)
	seq.tween_interval(5.8)
	seq.tween_property(_fade, "color:a", 1.0, 1.4)
	seq.tween_callback(_finish)

func _set_zoom(z: float) -> void:
	if _vista == null:
		return
	# base fill scale (480x270 -> viewport) times the cinematic push-in z, about centre
	_vista.scale = Vector2(z * _fill, z * _fill)
	_vista.position = _center * (1.0 - z)

func _input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventKey and event.pressed) \
			or (event is InputEventMouseButton and event.pressed) \
			or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_skip()

func _skip() -> void:
	if _done:
		return
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.3)
	t.tween_callback(_finish)

func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().paused = false
	queue_free()
