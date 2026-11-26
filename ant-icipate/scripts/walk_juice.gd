extends Node

const JuiceUtil := preload("res://scripts/juice_util.gd")

@export var bob_height: float = 5.0        # hop height in px
@export var sway_amount: float = 0.07      # waddle, in radians
@export var hop_distance: float = 130.0    # px walked per hop. Bigger = slower bob.
@export var move_threshold: float = 40.0   # px/s. Below this the ant counts as standing still.
@export var dust_color: Color = Color(0.576, 0.465, 0.243, 0.9)

var _ant: Node2D
var _sprite: Node2D
var _base_offset: Vector2 = Vector2.ZERO
var _base_skew: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _phase: float = 0.0
var _strength: float = 0.0   # 0 = standing, 1 = walking (smoothed)
var _dust: CPUParticles2D

func _ready() -> void:
	_ant = get_parent() as Node2D
	if _ant == null:
		queue_free()
		return

	_sprite = JuiceUtil.find_sprite(_ant)
	print("WalkJuice on ", _ant.name, " sprite = ", _sprite)
	if _sprite != null:
		_base_offset = _sprite.get("offset")
		_base_skew = _sprite.get("skew")

	_last_pos = _ant.global_position
	_phase = randf() * PI  # ants do not hop in sync
	_build_dust.call_deferred()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_ant):
		return

	var moved := _ant.global_position - _last_pos
	_last_pos = _ant.global_position
	if moved.length() / maxf(delta, 0.0001) > 3000.0:
		moved = Vector2.ZERO  # teleport (new round)

	var speed := moved.length() / maxf(delta, 0.0001)
	var walking := speed > move_threshold

	_strength = lerpf(_strength, 1.0 if walking else 0.0, clampf(10.0 * delta, 0.0, 1.0))
	_phase += moved.length() / hop_distance * PI  # steps follow distance, not time

	var hop := absf(sin(_phase))
	var sway := sin(_phase)
	if _sprite != null:
		_sprite.set("offset", _base_offset + Vector2(0.0, -hop * bob_height * _strength))
		_sprite.set("skew", _base_skew + sway * sway_amount * _strength)

	if _dust != null:
		_dust.emitting = walking

func _build_dust() -> void:
	if not is_instance_valid(_ant):
		return

	_dust = CPUParticles2D.new()
	_dust.name = "WalkDust"
	_dust.emitting = false
	_dust.amount = 10
	_dust.lifetime = 0.6
	_dust.local_coords = false          # puffs stay where they were kicked up
	_dust.show_behind_parent = true     # under the ant, over the ground
	_dust.position = Vector2(0, -4)     # feet
	_dust.texture = JuiceUtil.soft_circle()

	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 8.0
	_dust.direction = Vector2(0, -1)
	_dust.spread = 180.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 8.0
	_dust.initial_velocity_max = 26.0
	_dust.damping_min = 20.0
	_dust.damping_max = 40.0

	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 1.8
	var grow := Curve.new()
	grow.min_value = 0.0
	grow.max_value = 2.0
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 1.6))
	_dust.scale_amount_curve = grow
	_dust.z_index = 0
	_dust.z_as_relative = true

	_dust.color = dust_color
	_dust.color_ramp = JuiceUtil.fade_ramp(1.0)

	_ant.add_child(_dust)
	_ant.move_child(_dust, 0)
