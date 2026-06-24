class_name LPCCharacter
extends Node2D

## Renders an LPC (Liberated Pixel Cup) paper-doll: stacked Sprite2D layers
## (body / legs / feet / torso / hair, drawn bottom-to-top), each animation its own
## 64px sheet. Plays walk / slash / shoot / spellcast / hurt / idle for a game facing
## (0 down, 1 up, 2 left, 3 right), mapped to LPC's row order (0 up, 1 left, 2 down,
## 3 right). Looping anims hold; one-shots emit `anim_finished` and freeze on the
## last frame until something else is played.

signal anim_finished(anim: String)

const BASE := "res://assets/lpc/char/"
## Bottom-to-front draw order. The bare LPC body has a blank head, so eyes + nose +
## eyebrows are separate layers that build the face.
const LAYERS: Array[String] = ["body", "head", "eyes", "eyebrows", "nose", "legs", "feet", "torso", "hair"]
## Per-attack weapon OVERLAY. LPC's sword slash uses OVERSIZED 192px frames (the blade
## arcs well beyond the 64px body), so it's centred over the character with its own
## offset. [sheet, cols, offset]. (Shoot/bow added later.)
const WEAPON_ANIM := {
	"slash": ["sword/slash.png", 6, Vector2(-96, -124)],
}
## anim -> [cols, rows, fps, loop]
const ANIMS := {
	"idle":      [2, 4, 4.0, true],
	"walk":      [9, 4, 10.0, true],
	"slash":     [6, 4, 15.0, false],
	"shoot":     [13, 4, 16.0, false],
	"spellcast": [7, 4, 12.0, false],
	"hurt":      [6, 1, 8.0, false],
}
## game facing (down/up/left/right) -> LPC row index (up/left/down/right)
const FACING_ROW: Array[int] = [2, 0, 1, 3]
const FOOT_OFFSET := Vector2(-32, -60)

## Tints applied per layer (e.g. hair colour). Layers default to white.
@export var hair_color: Color = Color(0.42, 0.30, 0.20)

var _sprites: Dictionary = {}
var _weapon: Sprite2D
var _anim: String = ""
var _facing: int = 0
var _t: float = 0.0
var _done: bool = false

func _ready() -> void:
	for layer in LAYERS:
		var s := Sprite2D.new()
		s.name = layer.capitalize()
		s.centered = false
		s.offset = FOOT_OFFSET
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if layer == "hair":
			s.modulate = hair_color
		add_child(s)
		_sprites[layer] = s
	_weapon = Sprite2D.new()
	_weapon.name = "Weapon"
	_weapon.centered = false
	_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weapon.visible = false
	add_child(_weapon)
	play("idle")

func set_facing(game_facing: int) -> void:
	_facing = clampi(game_facing, 0, 3)

## Start an animation. A looping anim already playing is a no-op (keeps phase).
func play(anim: String) -> void:
	if not ANIMS.has(anim):
		return
	if anim == _anim and bool(ANIMS[anim][3]):
		return
	_anim = anim
	_t = 0.0
	_done = false
	var cols: int = int(ANIMS[anim][0])
	var rows: int = int(ANIMS[anim][1])
	for layer in LAYERS:
		var s: Sprite2D = _sprites[layer]
		var path := BASE + layer + "/" + anim + ".png"
		s.texture = load(path) if ResourceLoader.exists(path) else null
		s.hframes = cols
		s.vframes = rows
	# Weapon overlay (the swinging blade) for attack anims; hidden otherwise.
	if WEAPON_ANIM.has(anim):
		var wc: Array = WEAPON_ANIM[anim]
		var wpath: String = BASE + str(wc[0])
		_weapon.texture = load(wpath) if ResourceLoader.exists(wpath) else null
		_weapon.hframes = int(wc[1])
		_weapon.vframes = 4
		_weapon.offset = wc[2]
		_weapon.visible = _weapon.texture != null
	else:
		_weapon.visible = false

func is_done() -> bool:
	return _done

func _process(delta: float) -> void:
	if _anim == "":
		return
	var cfg: Array = ANIMS[_anim]
	var cols: int = int(cfg[0])
	var loop: bool = bool(cfg[3])
	_t += delta * float(cfg[2])
	var idx: int = int(_t)
	if idx >= cols:
		if loop:
			idx = idx % cols
		else:
			idx = cols - 1
			if not _done:
				_done = true
				anim_finished.emit(_anim)
	var row: int = 0 if int(cfg[1]) == 1 else FACING_ROW[_facing]
	for layer in LAYERS:
		var s: Sprite2D = _sprites[layer]
		if s.texture != null:
			s.frame = row * cols + idx
	if _weapon.visible:
		_weapon.frame = row * _weapon.hframes + idx
