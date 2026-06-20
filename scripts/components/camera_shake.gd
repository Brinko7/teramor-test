extends Camera2D

## The player camera. Two effects share its `offset`:
##   * Aim-lead — the view drifts a little toward the cursor, so you see more of
##     where you're aiming. Smoothed, and clamped so it never runs away.
##   * Screen shake — listens for Events.screen_shake(strength) and jolts the
##     offset by a decaying random amount. Strength is roughly the peak offset in
##     pixels; a shake takes the strongest pending value so a flurry of hits
##     doesn't sum into nausea.
## Each frame the offset is the smoothed lead plus the current shake jolt.

const DECAY := 12.0
const MAX_SHAKE := 8.0

## Aim-lead: fraction of the cursor's distance from the camera, capped, eased in.
const LEAD_FACTOR := 0.18
const LEAD_MAX := 26.0
const LEAD_SMOOTH := 6.0

var _shake: float = 0.0
var _lead: Vector2 = Vector2.ZERO

func _ready() -> void:
	Events.screen_shake.connect(_on_screen_shake)

func _on_screen_shake(strength: float) -> void:
	_shake = minf(MAX_SHAKE, maxf(_shake, strength))

func _process(delta: float) -> void:
	# Ease the lead toward the (clamped) cursor offset.
	var target_lead: Vector2 = ((get_global_mouse_position() - global_position) * LEAD_FACTOR).limit_length(LEAD_MAX)
	_lead = _lead.lerp(target_lead, 1.0 - exp(-LEAD_SMOOTH * delta))

	var jolt: Vector2 = Vector2.ZERO
	if _shake > 0.05:
		jolt = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-DECAY * delta))
	else:
		_shake = 0.0

	offset = _lead + jolt
