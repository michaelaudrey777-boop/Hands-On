extends Area2D

@export var delay_seconds: float = 0.25
@export var follow_distance: float = 128.0
@export var move_speed: float = 400.0
@export var turn_speed: float = 12.0
@export var shadow_offset: Vector2 = Vector2(5, 8)
@export var recruit_ready_delay: float = 2.0

@export_group("Huddle Settings")
@export var huddle_radius: float = 65.0
@export var huddle_move_speed: float = 900.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow

var line_target: Node2D = null
var leader_ref: Node2D = null
var position_history: Array[Vector2] = []
var can_be_recruited: bool = false
var was_huddling: bool = false

func _ready() -> void:
	add_to_group("followers")
	body_entered.connect(_on_body_entered)

	if line_target != null:
		can_be_recruited = true
		modulate = Color.WHITE
	else:
		can_be_recruited = false
		modulate = Color(1, 1, 1, 0.2)
		_start_recruit_cooldown()

func _start_recruit_cooldown() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.6, recruit_ready_delay)
	await tween.finished

	if line_target == null:
		can_be_recruited = true
		for body in get_overlapping_bodies():
			_on_body_entered(body)

func _physics_process(delta: float) -> void:
	if line_target != null:
		var huddling: bool = leader_ref != null and leader_ref.get("is_huddling") == true

		if huddling != was_huddling:
			position_history.clear()
			was_huddling = huddling

		if huddling and leader_ref.has_method("get_huddle_position"):
			var circle_pos: Vector2 = leader_ref.get_huddle_position(self, huddle_radius)
			var dist := global_position.distance_to(circle_pos)

			if dist > 4.0:
				var dir := global_position.direction_to(circle_pos)
				rotation = lerp_angle(rotation, dir.angle(), turn_speed * delta)
				global_position = global_position.move_toward(circle_pos, huddle_move_speed * delta)
			else:
				global_position = circle_pos
				rotation = lerp_angle(rotation, leader_ref.rotation, turn_speed * delta)
		else:
			position_history.append(line_target.global_position)

			var delay_frames := int(delay_seconds * Engine.physics_ticks_per_second)
			if position_history.size() > delay_frames:
				var delayed_target_pos: Vector2 = position_history.pop_front()

				if global_position.distance_to(delayed_target_pos) > follow_distance + 0.5:
					var direction := global_position.direction_to(delayed_target_pos)
					rotation = lerp_angle(rotation, direction.angle(), turn_speed * delta)
					global_position = global_position.move_toward(delayed_target_pos, move_speed * delta)

	shadow.global_position = sprite.global_position + shadow_offset

func set_target(new_target: Node2D, leader: Node2D = null) -> void:
	line_target = new_target
	if leader != null:
		leader_ref = leader
	can_be_recruited = true
	position_history.clear()
	modulate = Color.WHITE

func _on_body_entered(body: Node2D) -> void:
	if line_target == null and can_be_recruited and body.has_method("recruit_follower"):
		body.recruit_follower(self)
