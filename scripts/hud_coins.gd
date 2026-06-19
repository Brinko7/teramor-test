extends CanvasLayer

## HUD purse readout. Sits in the top-right corner of gameplay scenes and mirrors
## the Wallet autoload's balance, refreshing on its `changed` signal. Instanced
## per world scene (like the health bar) so it never bleeds onto menu screens.

const COIN_ICON: Texture2D = preload("res://assets/placeholder/ui/coin.png")

var _label: Label = null

func _ready() -> void:
	layer = 80
	_build()
	Wallet.changed.connect(_on_changed)
	_on_changed(Wallet.get_gold())

func _build() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_right = -6.0
	panel.offset_top = 6.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.164706, 0.12549, 0.094118, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color(0.482353, 0.337255, 0.188235, 1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var icon := TextureRect.new()
	icon.texture = COIN_ICON
	icon.custom_minimum_size = Vector2(12, 12)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)

	_label = Label.new()
	var settings := LabelSettings.new()
	settings.font_size = 12
	settings.font_color = Color(0.95, 0.85, 0.45, 1)
	_label.label_settings = settings
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_label)

func _on_changed(balance: int) -> void:
	if _label != null:
		_label.text = str(balance)
