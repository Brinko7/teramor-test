extends PointLight2D

## Subtle fire flicker for the hearth light: a slow "breathing" sine plus a small
## per-frame jitter around a base energy, so the firelight feels alive without
## strobing. Tune via the exports.

@export var base_energy: float = 1.3
@export var sway: float = 0.12      # slow breathing amplitude
@export var jitter: float = 0.10    # fast random flicker amplitude
@export var speed: float = 7.0

var _t: float = 0.0

func _ready() -> void:
	_t = randf() * 10.0

func _process(delta: float) -> void:
	_t += delta * speed
	energy = base_energy + sin(_t) * sway + (randf() - 0.5) * jitter
