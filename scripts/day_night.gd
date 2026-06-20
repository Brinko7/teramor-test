extends CanvasModulate

## Tints the world by time of day, driven by TimeManager. Lives in world scenes
## as a CanvasModulate so it darkens the map (not the HUD CanvasLayers) toward
## night and clears back to daylight in the morning. Interpolates between key
## colours on every clock tick.

# Grounded, naturalistic key colours. DAY is a touch warm-neutral rather than
# pure white so noon never feels clinical; NIGHT is deep and desaturated so
# firelight and lamps actually read after dark.
const NIGHT := Color(0.3, 0.35, 0.52, 1)    # deep cool dark
const DAWN := Color(0.64, 0.58, 0.62, 1)    # cool mauve first light
const DAY := Color(0.99, 0.97, 0.92, 1)     # soft warm-neutral noon
const GOLDEN := Color(0.95, 0.76, 0.54, 1)  # warm golden hour
const DUSK := Color(0.52, 0.44, 0.56, 1)    # violet twilight

## A subtle per-season multiplier folded over the time-of-day colour so the whole
## world shifts hue with the calendar: fresh spring, warm summer, amber autumn,
## pale-cold winter. Kept gentle (near white) so night and lamplight still read.
const SEASON_TINT: Array[Color] = [
	Color(0.95, 1.0, 0.95),    # SPRING — fresh, faintly green
	Color(1.0, 0.98, 0.90),    # SUMMER — warm, golden
	Color(1.0, 0.91, 0.78),    # AUTUMN — amber
	Color(0.88, 0.93, 1.0),    # WINTER — pale, cold blue
]

var _season_tint: Color = SEASON_TINT[0]

func _ready() -> void:
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.season_changed.connect(_on_season_changed)
	_season_tint = _tint_for(TimeManager.get_season())
	color = _color_for(TimeManager.get_time_minutes())

func _on_time_changed(minutes: int) -> void:
	color = _color_for(minutes)

func _on_season_changed(season: int) -> void:
	_season_tint = _tint_for(season)
	color = _color_for(TimeManager.get_time_minutes())

func _tint_for(season: int) -> Color:
	return SEASON_TINT[clampi(season, 0, SEASON_TINT.size() - 1)]

## Piecewise-linear tint across the day: night -> cool dawn -> day -> golden
## hour -> violet dusk -> night. Minutes past 24:00 (post-midnight) fold back to
## the small hours so 25:00 reads like 01:00.
func _color_for(minutes: int) -> Color:
	var t: int = clampi(minutes, 0, 26 * 60)
	if t >= 24 * 60:
		t -= 24 * 60
	var stop_min: Array[int] = [0, 270, 360, 450, 1020, 1110, 1200, 1290, 1440]
	var stop_col: Array[Color] = [
		NIGHT, NIGHT, DAWN, DAY, DAY, GOLDEN, DUSK, NIGHT, NIGHT,
	]
	for i in range(stop_min.size() - 1):
		if t >= stop_min[i] and t <= stop_min[i + 1]:
			var span: int = stop_min[i + 1] - stop_min[i]
			var f: float = 0.0 if span == 0 else float(t - stop_min[i]) / float(span)
			return stop_col[i].lerp(stop_col[i + 1], f) * _season_tint
	return DAY * _season_tint
