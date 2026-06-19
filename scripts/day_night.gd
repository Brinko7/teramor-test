extends CanvasModulate

## Tints the world by time of day, driven by TimeManager. Lives in world scenes
## as a CanvasModulate so it darkens the map (not the HUD CanvasLayers) toward
## night and clears back to daylight in the morning. Interpolates between key
## colours on every clock tick.

const DAY := Color(1, 1, 1, 1)
const EVENING := Color(0.86, 0.71, 0.6, 1)
const NIGHT := Color(0.4, 0.44, 0.68, 1)

func _ready() -> void:
	TimeManager.time_changed.connect(_on_time_changed)
	color = _color_for(TimeManager.get_time_minutes())

func _on_time_changed(minutes: int) -> void:
	color = _color_for(minutes)

## Piecewise-linear tint across the day. Minutes past 24:00 (post-midnight) fold
## back to the small hours so 25:00 reads like 01:00.
func _color_for(minutes: int) -> Color:
	var t: int = clampi(minutes, 0, 26 * 60)
	if t >= 24 * 60:
		t -= 24 * 60
	var stop_min: Array[int] = [0, 300, 420, 1020, 1140, 1260, 1440]
	var stop_col: Array[Color] = [NIGHT, NIGHT, DAY, DAY, EVENING, NIGHT, NIGHT]
	for i in range(stop_min.size() - 1):
		if t >= stop_min[i] and t <= stop_min[i + 1]:
			var span: int = stop_min[i + 1] - stop_min[i]
			var f: float = 0.0 if span == 0 else float(t - stop_min[i]) / float(span)
			return stop_col[i].lerp(stop_col[i + 1], f)
	return DAY
