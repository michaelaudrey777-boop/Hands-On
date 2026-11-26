extends Node

const JuiceUtil := preload("res://scripts/juice_util.gd")

@export var area_half_size: Vector2 = Vector2(1500, 900)  # a bit bigger than the screen
@export var dust_amount: int = 90
@export var pollen_amount: int = 18
@export var lifetime: float = 10.0
@export var wind: Vector2 = Vector2(1.0, -0.25)           # drift direction

func _ready() -> void:
	_build.call_deferred()

func _build() -> void:
	var host := get_parent() as Node2D
	if host == null:
		return

	# tiny pale motes
	#host.add_child(_make_emitter(
		#"AmbientDust", dust_amount,
		#Color(1.0, 0.95, 0.85, 0.40),
		#0.15, 0.30,
		#6.0, 16.0, 30.0, 4.0))
	host.add_child(_make_emitter(
		"AmbientDust", dust_amount,
		Color(1, 1, 1, 1.0),
		0.75, 1.3,
		6.0, 16.0, 30.0, 4.0))

	# bigger yellow pollen, drifts a bit faster and swirls more
	host.add_child(_make_emitter(
		"AmbientPollen", pollen_amount,
		Color(1.0, 0.90, 0.45, 0.9),
		1.0, 2.0,
		10.0, 22.0, 60.0, 10.0))

func _make_emitter(emitter_name: String, amount: int, color: Color,
		scale_min: float, scale_max: float,
		speed_min: float, speed_max: float,
		spread: float, swirl: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = emitter_name
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime       # start already filled, no empty first seconds
	p.local_coords = false
	p.z_index = 6                 # above ants, below hazards
	p.texture = JuiceUtil.soft_circle()

	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area_half_size
	p.direction = wind.normalized()
	p.spread = spread
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.tangential_accel_min = -swirl
	p.tangential_accel_max = swirl

	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color = color
	p.color_ramp = JuiceUtil.fade_in_out_ramp(1.0, 0.2)
	return p
