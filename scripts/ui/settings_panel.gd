extends CanvasLayer

## The options overlay (Audio / Display / Controls). A thin view over
## SettingsManager: every widget reads its current value and writes back through the
## manager, which applies + persists immediately. Reachable from the title screen and
## from the in-game player menu; it processes while paused and restores the prior
## pause state on close, so it layers cleanly over the (already paused) player menu.

enum Tab { AUDIO, DISPLAY, CONTROLS }
const TAB_NAMES := {Tab.AUDIO: "Audio", Tab.DISPLAY: "Display", Tab.CONTROLS: "Controls"}

var _tab: int = Tab.AUDIO
var _open: bool = false
var _prev_paused: bool = false
var _listening_action: StringName = &""

var _tab_bar: HBoxContainer
var _content: MarginContainer
var _hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	_build_shell()
	visible = false

# --- Open / close -----------------------------------------------------------

func open() -> void:
	_open = true
	_listening_action = &""
	_prev_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_tab = Tab.AUDIO
	_rebuild_tab_bar()
	_refresh()

func is_active() -> bool:
	return _open

func _close() -> void:
	_open = false
	_listening_action = &""
	visible = false
	get_tree().paused = _prev_paused

func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Capturing a key for a rebind takes priority over everything else.
	if _listening_action != &"":
		if event is InputEventKey and event.pressed and not event.echo:
			var code: int = (event as InputEventKey).physical_keycode
			if code != KEY_ESCAPE and code != 0:
				SettingsManager.rebind(_listening_action, code)
			_listening_action = &""
			_refresh()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("player_menu"):
		_close()
		get_viewport().set_input_as_handled()

# --- Shell ------------------------------------------------------------------

func _build_shell() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(0.98))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size = Vector2(300, 0)
	margin.add_child(vbox)

	var title := UITheme.make_label("Options", 14, UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_tab_bar)

	vbox.add_child(HSeparator.new())

	_content = MarginContainer.new()
	_content.custom_minimum_size = Vector2(300, 170)
	vbox.add_child(_content)

	_hint = UITheme.make_label("", 8, UITheme.PROMPT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hint)

	vbox.add_child(HSeparator.new())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	vbox.add_child(footer)
	var reset := Button.new()
	reset.text = "Reset to Defaults"
	reset.add_theme_font_size_override("font_size", 10)
	reset.pressed.connect(_on_reset)
	footer.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 10)
	close.pressed.connect(_close)
	footer.add_child(close)

func _rebuild_tab_bar() -> void:
	for child: Node in _tab_bar.get_children():
		child.queue_free()
	for tab: int in [Tab.AUDIO, Tab.DISPLAY, Tab.CONTROLS]:
		var btn := Button.new()
		btn.text = TAB_NAMES[tab]
		btn.add_theme_font_size_override("font_size", 10)
		btn.disabled = tab == _tab
		btn.pressed.connect(_switch_tab.bind(tab))
		_tab_bar.add_child(btn)

func _switch_tab(tab: int) -> void:
	_tab = tab
	_listening_action = &""
	_rebuild_tab_bar()
	_refresh()

func _refresh() -> void:
	for child: Node in _content.get_children():
		child.queue_free()
	match _tab:
		Tab.AUDIO:
			_hint.text = "Drag to set volume."
			_content.add_child(_build_audio())
		Tab.DISPLAY:
			_hint.text = ""
			_content.add_child(_build_display())
		Tab.CONTROLS:
			_hint.text = "Click a key, then press the new key (Esc cancels)."
			_content.add_child(_build_controls())

# --- Audio tab --------------------------------------------------------------

func _build_audio() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	for bus: StringName in SettingsManager.BUSES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := UITheme.make_label(String(bus), 11)
		name_label.custom_minimum_size = Vector2(80, 0)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = SettingsManager.get_volume(bus)
		slider.custom_minimum_size = Vector2(150, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(slider)
		var pct := UITheme.make_label("%d%%" % roundi(slider.value * 100.0), 10, UITheme.SAND)
		pct.custom_minimum_size = Vector2(36, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct)
		slider.value_changed.connect(func(v: float) -> void:
			SettingsManager.set_volume(bus, v)
			pct.text = "%d%%" % roundi(v * 100.0))
		box.add_child(row)
	return box

# --- Display tab ------------------------------------------------------------

func _build_display() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_toggle_row("Fullscreen", SettingsManager.is_fullscreen(),
		func(on: bool) -> void: SettingsManager.set_fullscreen(on)))
	box.add_child(_toggle_row("V-Sync", SettingsManager.is_vsync(),
		func(on: bool) -> void: SettingsManager.set_vsync(on)))
	box.add_child(_toggle_row("Screen Shake", SettingsManager.screen_shake_enabled(),
		func(on: bool) -> void: SettingsManager.set_screen_shake(on)))
	return box

func _toggle_row(label: String, value: bool, on_toggle: Callable) -> Control:
	var row := HBoxContainer.new()
	var name_label := UITheme.make_label(label, 11)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var check := CheckButton.new()
	check.button_pressed = value
	check.add_theme_font_size_override("font_size", 10)
	check.toggled.connect(on_toggle)
	row.add_child(check)
	return row

# --- Controls tab -----------------------------------------------------------

func _build_controls() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 165)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for action: StringName in SettingsManager.REBINDABLE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := UITheme.make_label(String(SettingsManager.ACTION_LABELS.get(action, action)), 10)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var key_btn := Button.new()
		key_btn.custom_minimum_size = Vector2(96, 0)
		key_btn.add_theme_font_size_override("font_size", 10)
		if _listening_action == action:
			key_btn.text = "Press a key…"
		else:
			key_btn.text = SettingsManager.key_name(action)
		key_btn.pressed.connect(func() -> void:
			_listening_action = action
			_refresh())
		row.add_child(key_btn)
		box.add_child(row)
	return scroll

# --- Footer -----------------------------------------------------------------

func _on_reset() -> void:
	SettingsManager.reset_defaults()
	_listening_action = &""
	_refresh()
