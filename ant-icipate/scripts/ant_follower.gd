extends Area2D

@export var delay_seconds: float = 0.25
@export var follow_distance: float = 128.0
@export var move_speed: float = 400.0
@export var shadow_offset: Vector2 = Vector2(4, 33)
@export var recruit_ready_delay: float = 2.0
@export var sprite_faces_left: bool = false

@export_group("Huddle Settings")
@export var huddle_radius: float = 65.0
@export var huddle_move_speed: float = 900.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shadow: Sprite2D = $Shadow

var line_target: Node2D = null
var leader_ref: Node2D = null
var position_history: Array[Vector2] = []
var can_be_recruited: bool = false
var was_huddling: bool = false
var is_dying: bool = false
var flash_tween: Tween = null

func _ready() -> void:
	add_to_group("followers")
	body_entered.connect(_on_body_entered)
	_update_animation(false)

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

	if line_target == null and not is_dying:
		can_be_recruited = true
		for body in get_overlapping_bodies():
			_on_body_entered(body)

func _physics_process(delta: float) -> void:
	if is_dying:
		_sync_shadow()
		return

	var is_moving := false

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
				_face(dir)
				global_position = global_position.move_toward(circle_pos, huddle_move_speed * delta)
				is_moving = true
			else:
				global_position = circle_pos
		else:
			position_history.append(line_target.global_position)

			var delay_frames := int(delay_seconds * Engine.physics_ticks_per_second)
			if position_history.size() > delay_frames:
				var delayed_target_pos: Vector2 = position_history.pop_front()

				if global_position.distance_to(delayed_target_pos) > follow_distance + 0.5:
					var direction := global_position.direction_to(delayed_target_pos)
					_face(direction)
					global_position = global_position.move_toward(delayed_target_pos, move_speed * delta)
					is_moving = true

	_update_animation(is_moving)
	_sync_shadow()

func _update_animation(is_moving: bool) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim_name := &"walking" if is_moving else &"idle"
	if sprite.sprite_frames.has_animation(anim_name) and sprite.animation != anim_name:
		sprite.play(anim_name)

func _sync_shadow() -> void:
	if shadow == null or sprite == null:
		return
	shadow.global_position = sprite.global_position + shadow_offset
	shadow.flip_h = sprite.flip_h
	shadow.scale = sprite.scale
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
		if frame_count > 0:
			var safe_frame := clampi(sprite.frame, 0, frame_count - 1)
			shadow.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, safe_frame)

func play_hit_flash() -> void:
	if sprite == null:
		return
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()

	sprite.modulate = Color(4.5, 4.5, 4.5, 1.0)
	flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color(2.5, 0.35, 0.35, 1.0), 0.07)
	flash_tween.tween_property(sprite, "modulate", Color(4.0, 4.0, 4.0, 1.0), 0.06)
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

func die_with_flash() -> void:
	if is_dying:
		return
	is_dying = true
	line_target = null
	can_be_recruited = false
	remove_from_group("followers")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_update_animation(false)

	if sprite != null:
		if flash_tween != null and flash_tween.is_valid():
			flash_tween.kill()
		sprite.modulate = Color(5.0, 5.0, 5.0, 1.0)
		flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color(2.5, 0.3, 0.3, 1.0), 0.07)
		flash_tween.tween_property(sprite, "modulate", Color(5.0, 5.0, 5.0, 0.0), 0.13)
		if shadow != null:
			flash_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.20)
		await flash_tween.finished

	if is_instance_valid(self):
		queue_free()

func set_target(new_target: Node2D, leader: Node2D = null) -> void:
	if is_dying:
		return
	line_target = new_target
	if leader != null:
		leader_ref = leader
	can_be_recruited = true
	position_history.clear()
	modulate = Color.WHITE

func reset_follow_history() -> void:
	position_history.clear()
	if is_node_ready():
		_sync_shadow()

func _on_body_entered(body: Node2D) -> void:
	if not is_dying and line_target == null and can_be_recruited and body.has_method("recruit_follower"):
		body.recruit_follower(self)

func _face(dir: Vector2) -> void:
	if absf(dir.x) > 0.1:
		var moving_left := dir.x < 0.0
		sprite.flip_h = not moving_left if sprite_faces_left else moving_left
		shadow.flip_h = sprite.flip_h
