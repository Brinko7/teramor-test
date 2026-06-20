extends CanvasLayer

## HUD clock readout. Top-centre of gameplay scenes; mirrors TimeManager, showing
## the current day and a Stardew-style 12-hour clock and refreshing on its
## signals. Instanced per world scene like the coin HUD so it never shows on menus.

var _day_label: Label = null
var _time_label: Label = null

func _ready() -> void:
	layer = 80
	_build()
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	_on_day_changed(TimeManager.get_day())
	_on_time_changed(TimeManager.get_time_minutes())

func _build() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_top = 6.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := UITheme.panel_style(0.85)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	_day_label = Label.new()
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var day_settings := LabelSettings.new()
	day_settings.font_size = 9
	day_settings.font_color = UITheme.PROMPT
	_day_label.label_settings = day_settings
	box.add_child(_day_label)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var time_settings := LabelSettings.new()
	time_settings.font_size = 13
	time_settings.font_color = UITheme.PARCHMENT
	_time_label.label_settings = time_settings
	box.add_child(_time_label)

func _on_day_changed(_day: int) -> void:
	if _day_label != null:
		_day_label.text = TimeManager.format_date()

func _on_time_changed(_minutes: int) -> void:
	if _time_label != null:
		_time_label.text = TimeManager.format_time()
