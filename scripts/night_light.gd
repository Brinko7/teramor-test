extends PointLight2D

## A light that turns itself on after dusk and off around dawn, driven by
## TimeManager — for street lamps and warm window glow. Energy crossfades
## between a (usually zero) daytime level and a full nighttime level, with an
## optional flicker layered on top and scaled by how "night" it currently is, so
## lit windows and lamps never glow in broad daylight.

@export var base_energy: float = 1.0   # energy at full night
@export var day_energy: float = 0.0    # energy at full day
@export var sway: float = 0.0          # slow breathing amplitude
@export var jitter: float = 0.0        # fast random flicker amplitude
@export var speed: float = 5.0

var _t: float = 0.0
var _night: float = 0.0

func _ready() -> void:
	_t = randf() * 10.0
	TimeManager.time_changed.connect(_on_time_changed)
	_night = _night_factor(TimeManager.get_time_minutes())
	energy = lerpf(day_energy, base_energy, _night)

func _on_time_changed(minutes: int) -> void:
	_night = _night_factor(minutes)

func _process(delta: float) -> void:
	_t += delta * speed
	var lvl: float = lerpf(day_energy, base_energy, _night)
	var flick: float = (sin(_t) * sway + (randf() - 0.5) * jitter) * _night
	energy = maxf(0.0, lvl + flick)

## 1.0 = full night (lit), 0.0 = full day (dark). Ramps on at dusk (18:00->
## 19:30) and off at dawn (05:30->07:00). Post-midnight minutes fold back.
func _night_factor(minutes: int) -> float:
	var t: int = clampi(minutes, 0, 26 * 60)
	if t >= 24 * 60:
		t -= 24 * 60
	if t <= 330:
		return 1.0
	if t < 420:
		return 1.0 - float(t - 330) / 90.0
	if t <= 1080:
		return 0.0
	if t < 1170:
		return float(t - 1080) / 90.0
	return 1.0
