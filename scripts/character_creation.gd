extends Control

## Character-creation screen. The player picks a name, skin tone, hair style and
## hair colour while watching a live animated paper-doll. "Begin" writes the
## choices into PlayerProfile and enters the world; "Back" returns to the menu.
## The skin/hair palettes are read from PlayerProfile so adding a tone or colour
## there is enough to surface it here.

const BODY_TEX := "res://assets/placeholder/char/body.png"
const OUTFIT_TEX := "res://assets/placeholder/char/outfit_ranger.png"
const STYLE_LABELS := {"short": "Short", "long": "Long", "spiky": "Spiky"}
const WALK_FRAMES := [0, 1, 0, 2]
const PREVIEW_FPS := 6.0
const SELECT_BORDER := Color(0.95, 0.92, 0.7)

@onready var preview_body: Sprite2D = $Preview/Body
@onready var preview_outfit: Sprite2D = $Preview/Outfit
@onready var preview_hair: Sprite2D = $Preview/Hair
@onready var name_field: LineEdit = %NameField
@onready var skin_row: HBoxContainer = %SkinRow
@onready var style_row: HBoxContainer = %StyleRow
@onready var hair_color_row: HBoxContainer = %HairColorRow

var _skin: Color = PlayerProfile.skin_tone
var _hair_color: Color = PlayerProfile.hair_color
var _hair_style: String = PlayerProfile.hair_style

var _skin_swatches: Array[Button] = []
var _hair_swatches: Array[Button] = []
var _style_buttons: Array[Button] = []

var _anim_time: float = 0.0

func _ready() -> void:
	get_tree().paused = false
	preview_body.texture = load(BODY_TEX) as Texture2D
	preview_outfit.texture = load(OUTFIT_TEX) as Texture2D
	name_field.text = PlayerProfile.char_name
	name_field.text_submitted.connect(_on_name_submitted)
	_build_skin_swatches()
	_build_style_buttons()
	_build_hair_swatches()
	_apply_preview()
	name_field.grab_focus()
	name_field.select_all()

func _process(delta: float) -> void:
	_anim_time += delta * PREVIEW_FPS
	var frame: int = WALK_FRAMES[int(_anim_time) % WALK_FRAMES.size()]
	preview_body.frame = frame
	preview_outfit.frame = frame
	preview_hair.frame = frame

# --- Palette construction ---------------------------------------------------

func _build_skin_swatches() -> void:
	for tone: Color in PlayerProfile.SKIN_TONES:
		var swatch := _make_swatch(tone)
		swatch.pressed.connect(_on_skin_picked.bind(tone, swatch))
		skin_row.add_child(swatch)
		_skin_swatches.append(swatch)
	_highlight(_skin_swatches, _swatch_for(_skin_swatches, _skin))

func _build_hair_swatches() -> void:
	for col: Color in PlayerProfile.HAIR_COLORS:
		var swatch := _make_swatch(col)
		swatch.pressed.connect(_on_hair_color_picked.bind(col, swatch))
		hair_color_row.add_child(swatch)
		_hair_swatches.append(swatch)
	_highlight(_hair_swatches, _swatch_for(_hair_swatches, _hair_color))

func _build_style_buttons() -> void:
	for style: String in PlayerProfile.HAIR_STYLES:
		var button := Button.new()
		button.text = STYLE_LABELS.get(style, style.capitalize())
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = style == _hair_style
		button.pressed.connect(_on_style_picked.bind(style, button))
		style_row.add_child(button)
		_style_buttons.append(button)

func _make_swatch(color: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(22, 22)
	button.focus_mode = Control.FOCUS_NONE
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = SELECT_BORDER
	box.set_border_width_all(0)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	return button

# --- Selection handlers -----------------------------------------------------

func _on_skin_picked(color: Color, button: Button) -> void:
	_skin = color
	_highlight(_skin_swatches, button)
	_apply_preview()

func _on_hair_color_picked(color: Color, button: Button) -> void:
	_hair_color = color
	_highlight(_hair_swatches, button)
	_apply_preview()

func _on_style_picked(style: String, button: Button) -> void:
	_hair_style = style
	for other: Button in _style_buttons:
		other.button_pressed = other == button
	_apply_preview()

func _on_name_submitted(_text: String) -> void:
	_on_begin_pressed()

func _on_begin_pressed() -> void:
	PlayerProfile.apply(name_field.text, _skin, _hair_color, _hair_style)
	GameManager.enter_world()

func _on_back_pressed() -> void:
	GameManager.to_menu()

# --- Preview / helpers ------------------------------------------------------

func _apply_preview() -> void:
	preview_body.modulate = _skin
	preview_hair.texture = load("res://assets/placeholder/char/hair_%s.png" % _hair_style) as Texture2D
	preview_hair.modulate = _hair_color

func _highlight(buttons: Array[Button], selected: Button) -> void:
	for button: Button in buttons:
		var box: StyleBoxFlat = button.get_theme_stylebox("normal")
		box.set_border_width_all(3 if button == selected else 0)

## Finds the swatch built from a given colour (matched on its style-box bg) so
## the initial selection border lands on the right one.
func _swatch_for(buttons: Array[Button], color: Color) -> Button:
	for button: Button in buttons:
		var box: StyleBoxFlat = button.get_theme_stylebox("normal")
		if box.bg_color.is_equal_approx(color):
			return button
	return buttons[0] if not buttons.is_empty() else null
