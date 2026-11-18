extends Area2D

@export var delay_seconds: float = 0.25
@export var follow_distance: float = 128.0
@export var move_speed: float = 400.0
@export var turn_speed: float = 12.0

var target: Node2D = null
var position_history: Array[Vector2] = []

func _ready() -> void:
	add_to_group("followers")
	body_entered.connect(_on_body_entered)
	if target == null:
		modulate = Color(1, 1, 1, 0.5)

func _physics_process(delta: float) -> void:
	if target == null:
		return

	position_history.append(target.global_position)

	var delay_frames := int(delay_seconds * Engine.physics_ticks_per_second)
	if position_history.size() <= delay_frames:
		return

	var delayed_target_pos: Vector2 = position_history.pop_front()

	if global_position.distance_to(delayed_target_pos) > follow_distance + 0.5:
		var direction := global_position.direction_to(delayed_target_pos)
		rotation = lerp_angle(rotation, direction.angle(), turn_speed * delta)
		global_position = global_position.move_toward(delayed_target_pos, move_speed * delta)

func set_target(new_target: Node2D) -> void:
	target = new_target
	position_history.clear()
	modulate = Color.WHITE

func _on_body_entered(body: Node2D) -> void:
	if target == null and body.has_method("recruit_follower"):
		body.recruit_follower(self)
