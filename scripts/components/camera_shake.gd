extends Camera2D

## Adds screen shake to the player camera. Listens for Events.screen_shake(strength)
## and jolts the camera `offset` by a decaying random amount. Strength is roughly
## the peak offset in pixels; shakes take the strongest pending value so a flurry
## of hits doesn't sum into nausea.

const DECAY := 12.0
const MAX_SHAKE := 8.0

var _shake: float = 0.0

func _ready() -> void:
	Events.screen_shake.connect(_on_screen_shake)

func _on_screen_shake(strength: float) -> void:
	_shake = minf(MAX_SHAKE, maxf(_shake, strength))

func _process(delta: float) -> void:
	if _shake <= 0.05:
		_shake = 0.0
		offset = Vector2.ZERO
		return
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	_shake = lerpf(_shake, 0.0, 1.0 - exp(-DECAY * delta))
