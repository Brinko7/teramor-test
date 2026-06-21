extends CanvasLayer

## Autoload `WeatherFX`. Paints the active weather and the world's ambient life as
## screen-space particles — the visual twin of WeatherManager (which only decides
## the sky). It sits just under the HUD and shows nothing indoors: precipitation and
## ambience are gated to the open-air zones (via MusicManager), and each effect keys
## off the weather, season and time of day:
##   * rain / snow — the current precipitation,
##   * fog — a soft overcast veil,
##   * fireflies — warm motes at dusk/night in the growing seasons,
##   * leaves — drifting amber in autumn.
##
## All effects are code-built CPUParticles2D over tiny runtime textures (no assets),
## so tuning weather feel lives entirely here.

const VW := 480.0
const VH := 270.0

var _rain: CPUParticles2D
var _snow: CPUParticles2D
var _leaves: CPUParticles2D
var _fireflies: CPUParticles2D
var _fog: ColorRect

func _ready() -> void:
	layer = 79  # under the HUD (80+), over the world
	_build()
	WeatherManager.weather_changed.connect(func(_w: int) -> void: _update())
	TimeManager.period_changed.connect(func(_p: int) -> void: _update())
	TimeManager.season_changed.connect(func(_s: int) -> void: _update())
	MusicManager.zone_changed.connect(func(_z: StringName) -> void: _update())
	_update()

# --- State ------------------------------------------------------------------

func _update() -> void:
	var outdoor: bool = MusicManager.is_outdoor()
	var weather: int = WeatherManager.get_weather()
	var season: int = TimeManager.get_season()       # 0 spring .. 3 winter
	var period: int = TimeManager.get_period()
	var dusk_or_night: bool = period == TimeManager.Period.EVENING or period == TimeManager.Period.NIGHT
	var precip: bool = weather == WeatherManager.Weather.RAIN or weather == WeatherManager.Weather.SNOW

	_rain.emitting = outdoor and weather == WeatherManager.Weather.RAIN
	_snow.emitting = outdoor and weather == WeatherManager.Weather.SNOW
	_leaves.emitting = outdoor and season == 2 and not precip          # autumn
	_fireflies.emitting = outdoor and dusk_or_night and (season == 0 or season == 1) and not precip
	_fade_fog(outdoor and weather == WeatherManager.Weather.FOG)

func _fade_fog(on: bool) -> void:
	var target: float = 0.16 if on else 0.0
	create_tween().tween_property(_fog, "color:a", target, 1.2)

# --- Build ------------------------------------------------------------------

func _build() -> void:
	_fog = ColorRect.new()
	_fog.color = Color(0.62, 0.66, 0.72, 0.0)
	_fog.size = Vector2(VW, VH)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fog)

	# Rain — fast, faintly angled blue-grey streaks filling from above-left.
	_rain = _make(160, _tex(1, 6, Color(0.62, 0.72, 0.86, 0.55)))
	_top_emitter(_rain, 0.6)
	_rain.direction = Vector2(0.18, 1.0)
	_rain.spread = 4.0
	_rain.gravity = Vector2(0, 1500)
	_rain.initial_velocity_min = 320.0
	_rain.initial_velocity_max = 380.0
	_rain.lifetime = 0.7
	_rain.preprocess = 0.7

	# Snow — slow, wandering, soft white flakes.
	_snow = _make(90, _tex(2, 2, Color(0.92, 0.94, 1.0, 0.85)))
	_top_emitter(_snow, 0.6)
	_snow.direction = Vector2(0, 1)
	_snow.spread = 25.0
	_snow.gravity = Vector2(0, 16)
	_snow.initial_velocity_min = 10.0
	_snow.initial_velocity_max = 26.0
	_snow.angular_velocity_min = -40.0
	_snow.angular_velocity_max = 40.0
	_snow.scale_amount_min = 1.0
	_snow.scale_amount_max = 1.6
	_snow.lifetime = 7.0
	_snow.preprocess = 7.0

	# Leaves — amber, tumbling, drifting down across autumn.
	_leaves = _make(20, _tex(3, 2, Color(0.80, 0.50, 0.22, 0.9)))
	_top_emitter(_leaves, 0.6)
	_leaves.direction = Vector2(0.35, 1.0)
	_leaves.spread = 28.0
	_leaves.gravity = Vector2(10, 26)
	_leaves.initial_velocity_min = 14.0
	_leaves.initial_velocity_max = 32.0
	_leaves.angular_velocity_min = -120.0
	_leaves.angular_velocity_max = 120.0
	_leaves.scale_amount_min = 1.0
	_leaves.scale_amount_max = 1.5
	_leaves.lifetime = 8.0
	_leaves.preprocess = 8.0

	# Fireflies — warm motes drifting anywhere on screen, fading in and out.
	_fireflies = _make(16, _tex(2, 2, Color(1.0, 0.92, 0.55, 1.0)))
	_fireflies.position = Vector2(VW * 0.5, VH * 0.5)
	_fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fireflies.emission_rect_extents = Vector2(VW * 0.5, VH * 0.45)
	_fireflies.direction = Vector2(0, -1)
	_fireflies.spread = 180.0
	_fireflies.gravity = Vector2(0, -3)
	_fireflies.initial_velocity_min = 3.0
	_fireflies.initial_velocity_max = 9.0
	_fireflies.lifetime = 4.0
	_fireflies.preprocess = 4.0
	_fireflies.color_ramp = _pulse_ramp()

func _make(amount: int, texture: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.texture = texture
	p.emitting = false
	p.randomness = 0.6
	add_child(p)
	return p

## Configure a particle node to rain down from a wide band above the screen.
func _top_emitter(p: CPUParticles2D, width_frac: float) -> void:
	p.position = Vector2(VW * 0.5, -10)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(VW * width_frac, 4)

func _tex(w: int, h: int, c: Color) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

## Fade each firefly in and out over its life so they twinkle rather than pop.
func _pulse_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1.0, 0.92, 0.55, 0.0))
	g.add_point(0.5, Color(1.0, 0.95, 0.6, 0.95))
	g.set_offset(g.get_point_count() - 1, 1.0)
	g.set_color(g.get_point_count() - 1, Color(1.0, 0.92, 0.55, 0.0))
	return g
