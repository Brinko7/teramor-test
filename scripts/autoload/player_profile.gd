extends Node

## Autoload `PlayerProfile`. Holds the player's chosen identity (name + cosmetic
## appearance) created at the character-creation screen and read by the player
## paper-doll when it spawns. Persisted through the SaveManager contract so a
## loaded game restores the same look.

signal changed

const HAIR_STYLES: Array[String] = ["short", "long", "spiky"]
const BEARD_STYLES: Array[String] = ["none", "stubble", "goatee", "full"]

const SKIN_TONES: Array[Color] = [
	Color("f4d6b8"), Color("e2b286"), Color("a6724e"), Color("6e4a32"),
]
## Names of the baked body sheets (assets/remaster/char/body_<name>.png), aligned
## index-for-index with SKIN_TONES. The remaster model picks a body sheet by tone
## rather than modulating one greyscale body, so the face/eyes stay right.
const SKIN_TONE_NAMES: Array[String] = ["fair", "tan", "brown", "deep"]
const HAIR_COLORS: Array[Color] = [
	Color("2c2624"), Color("603e22"), Color("d8b262"),
	Color("7e3a24"), Color("b0b2b8"), Color("e0e0e4"),
]

var char_name: String = "Zayn"
var skin_tone: Color = Color("e2b286")
var hair_color: Color = Color("603e22")
var hair_style: String = "short"
var beard_style: String = "none"

func _ready() -> void:
	add_to_group("persistent")

## The body sheet name for the chosen skin tone (nearest of SKIN_TONES). Used by
## the remaster paper-doll, which swaps body sheets instead of modulating.
func skin_tone_name() -> String:
	return skin_tone_name_for(skin_tone)

## Nearest baked body-sheet name for an arbitrary colour (creator + player share it).
func skin_tone_name_for(col: Color) -> String:
	var best := 0
	var best_d := INF
	for i in SKIN_TONES.size():
		var c: Color = SKIN_TONES[i]
		var d: float = (c.r - col.r) ** 2 + (c.g - col.g) ** 2 + (c.b - col.b) ** 2
		if d < best_d:
			best_d = d
			best = i
	return SKIN_TONE_NAMES[best]

func hair_texture() -> Texture2D:
	return load("res://assets/placeholder/char/hair_%s.png" % hair_style) as Texture2D

## The facial-hair sheet for the chosen beard, or null for "none" (the layer is
## hidden). Tinted by `hair_color` like the hair, so the beard matches the mane.
func beard_texture() -> Texture2D:
	if beard_style == "none":
		return null
	return load("res://assets/placeholder/char/beard_%s.png" % beard_style) as Texture2D

## --- Remaster paper-doll layers (assets/remaster/char/) ----------------------
## The new 4-dir model renders as stacked layers: a full-colour body sheet picked
## by skin tone (no modulate), and neutral hair/beard tinted by hair colour. The
## creator and the live player both pull from here.
const REMASTER_CHAR := "res://assets/remaster/char/"

func body_layer() -> Texture2D:
	return load(REMASTER_CHAR + "body_%s.png" % skin_tone_name()) as Texture2D

func hair_layer() -> Texture2D:
	return load(REMASTER_CHAR + "hair_%s.png" % hair_style) as Texture2D

func beard_layer() -> Texture2D:
	if beard_style == "none":
		return null
	return load(REMASTER_CHAR + "beard_%s.png" % beard_style) as Texture2D

func apply(p_name: String, p_skin: Color, p_hair_color: Color, p_style: String,
		p_beard: String = "none") -> void:
	char_name = p_name.strip_edges() if not p_name.strip_edges().is_empty() else "Ranger"
	skin_tone = p_skin
	hair_color = p_hair_color
	hair_style = p_style
	beard_style = p_beard
	changed.emit()

## --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "player_profile"

func save_state() -> Dictionary:
	return {
		"name": char_name,
		"skin": skin_tone.to_html(),
		"hair_color": hair_color.to_html(),
		"hair_style": hair_style,
		"beard_style": beard_style,
	}

func load_state(data: Dictionary) -> void:
	char_name = str(data.get("name", char_name))
	skin_tone = Color(str(data.get("skin", skin_tone.to_html())))
	hair_color = Color(str(data.get("hair_color", hair_color.to_html())))
	hair_style = str(data.get("hair_style", hair_style))
	beard_style = str(data.get("beard_style", beard_style))
	changed.emit()
