extends Node

@export var bob_height: float = 4.0      
@export var bob_period: float = 1.8       
@export var pulse_amount: float = 0.05    
@export var pulse_period: float = 1.3     

const JuiceUtil := preload("res://scripts/juice_util.gd")
var _sprite: Node2D
var _base_offset: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE
var _t: float = 0.0
var _phase_bob: float = 0.0
var _phase_pulse: float = 0.0

func _ready() -> void:
	var item := get_parent()
	_sprite = JuiceUtil.find_sprite(item)
	if _sprite == null:
		push_warning("ItemJuice: no sprite on " + item.name)
		set_process(false)
		return
	_base_offset = _sprite.get("offset")
	_base_scale = _sprite.scale
	_phase_bob = randf() * TAU     # every item got its own random bob rythm
	_phase_pulse = randf() * TAU

func _process(delta: float) -> void:
	_t += delta
	var bob := sin(_t * TAU / bob_period + _phase_bob)
	var pulse := sin(_t * TAU / pulse_period + _phase_pulse)
	_sprite.set("offset", _base_offset + Vector2(0.0, bob * bob_height))
	_sprite.scale = _base_scale * (1.0 + pulse * pulse_amount)
