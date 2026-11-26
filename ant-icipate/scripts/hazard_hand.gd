extends Node2D

@export var hand_radius: float = 180.0
@export var sweep_distance: float = 2350.0
@export var telegraph_time: float = 1.6
@export var sweep_speed: float = 2800.0
@export var hit_offset: Vector2 = Vector2(0, -33)

@export_group("Visual Sprites")
@export var charge_hand_texture: Texture2D = null
@export var sweep_hand_texture: Texture2D = null
@export var hand_texture: Texture2D = null
@export var hand_visual_scale_multiplier: float = 1.30
@export var sprite_faces_left: bool = false

@export_group("Wind-Up & Shadow Settings")
@export var windup_max_degrees: float = 24.0
@export var windup_pullback_distance: float = 65.0
@export var sweep_forward_tilt_degrees: float = 8.0
@export var charge_shadow_offset: Vector2 = Vector2(10.0, 56.0)
@export var sweep_shadow_offset: Vector2 = Vector2(10.0, 32.0)
@export var shadow_scale_multiplier: float = 0.96
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.44)

var leader: Node2D = null
var sweep_direction: int = 1

enum State { TELEGRAPH, SWEEPING }
var state: State = State.TELEGRAPH
var timer: float = 0.0
var sweep_progress: float = 0.0
var prev_hand_local_x: float = 0.0
var current_hand_local_x: float = 0.0

var hit_ants: Array[Node2D] = []
var leader_already_hit: bool = false

func _ready() -> void:
	z_index = 10
	sweep_direction = 1 if randf() < 0.5 else -1
	var half_dist := sweep_distance * 0.5
	prev_hand_local_x = -half_dist * float(sweep_direction)
	current_hand_local_x = prev_hand_local_x

func _process(delta: float) -> void:
	timer += delta

	match state:
		State.TELEGRAPH:
			if timer >= telegraph_time:
				_start_sweep()
		State.SWEEPING:
			prev_hand_local_x = current_hand_local_x
			sweep_progress += sweep_speed * delta
			var half_dist := sweep_distance * 0.5
			var start_x := -half_dist * float(sweep_direction)
			current_hand_local_x = start_x + (sweep_progress * float(sweep_direction))

			_check_sweep_hits()

			if sweep_progress >= sweep_distance:
				queue_free()
				return

	queue_redraw()

func _start_sweep() -> void:
	state = State.SWEEPING
	timer = 0.0
	sweep_progress = 0.0
	z_index = 12

	if leader != null and is_instance_valid(leader) and leader.has_method("trigger_swipe_effect"):
		leader.trigger_swipe_effect(float(sweep_direction), global_position, 1.15)

	var audio := AudioManager.get_instance(get_tree())
	if audio != null:
		audio.play_hand_swoop(global_position)

	var start_pos := global_position + Vector2(-sweep_distance * 0.35 * float(sweep_direction), 0.0)
	VFX.spawn_swipe_wind(get_parent(), start_pos, float(sweep_direction))

func _get_active_hand_texture() -> Texture2D:
	if state == State.TELEGRAPH:
		if charge_hand_texture != null:
			return charge_hand_texture
		if hand_texture != null:
			return hand_texture
		return sweep_hand_texture
	else:
		if sweep_hand_texture != null:
			return sweep_hand_texture
		if hand_texture != null:
			return hand_texture
		return charge_hand_texture

func _is_point_swept(world_pos: Vector2) -> bool:
	var p := world_pos + hit_offset
	var seg_a := global_position + Vector2(prev_hand_local_x, 0.0)
	var seg_b := global_position + Vector2(current_hand_local_x, 0.0)
	var closest := Geometry2D.get_closest_point_to_segment(p, seg_a, seg_b)
	return p.distance_to(closest) <= hand_radius

func _check_sweep_hits() -> void:
	if leader == null or not is_instance_valid(leader):
		return
	if leader.get("is_dead") == true:
		return

	var killed_this_step := 0
	var squad: Array = leader.followers.duplicate()
	for ant in squad:
		if is_instance_valid(ant) and ant not in hit_ants:
			if _is_point_swept(ant.global_position):
				hit_ants.append(ant)
				leader.remove_follower(ant)
				killed_this_step += 1

	if not leader_already_hit and _is_point_swept(leader.global_position):
		leader_already_hit = true
		if leader.has_method("play_hit_flash"):
			leader.play_hit_flash()

		if leader.followers.is_empty():
			if leader.has_method("die"):
				leader.die("Ant Leader was swept away by a human hand!")
		elif killed_this_step == 0:
			leader.remove_follower(leader.followers.back())

func _draw_hand_transformed(tex: Texture2D, local_pos: Vector2, rot_rad: float, target_diameter: float, modulate_color: Color, flip_h: bool, is_charging_fallback: bool) -> void:
	var scale_vec := Vector2(-1.0 if flip_h else 1.0, 1.0)
	draw_set_transform(local_pos, rot_rad, scale_vec)

	if tex != null:
		var tex_size := tex.get_size()
		var max_dim := maxf(tex_size.x, tex_size.y)
		if max_dim > 0.0:
			var draw_size := tex_size * (target_diameter / max_dim)
			draw_texture_rect(tex, Rect2(-draw_size * 0.5, draw_size), false, modulate_color)
	else:
		var base_col := Color(0.95, 0.65, 0.45) if is_charging_fallback else Color(0.92, 0.72, 0.58)
		var final_col := Color(base_col.r * modulate_color.r, base_col.g * modulate_color.g, base_col.b * modulate_color.b, modulate_color.a)
		var palm_rect := Rect2(-Vector2(hand_radius, hand_radius * 0.85), Vector2(hand_radius * 2.0, hand_radius * 1.7))
		draw_rect(palm_rect, final_col, true)
		if modulate_color.a > 0.5:
			draw_rect(palm_rect, Color(0.45, 0.28, 0.20), false, 6.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	var half_dist := sweep_distance * 0.5
	var lane_rect := Rect2(Vector2(-half_dist, -hand_radius), Vector2(sweep_distance, hand_radius * 2.0))
	var flip_h := (sweep_direction < 0) if not sprite_faces_left else (sweep_direction > 0)
	var diam := hand_radius * 2.0 * hand_visual_scale_multiplier
	var shadow_diam := diam * shadow_scale_multiplier
	var active_tex := _get_active_hand_texture()

	match state:
		State.TELEGRAPH:
			var t := clampf(timer / telegraph_time, 0.0, 1.0)
			var pulse := 0.5 + 0.5 * sin(timer * 18.0)
			var bg_alpha := lerpf(0.08, 0.24, t)
			var border_alpha := lerpf(0.35, 0.90, t)

			draw_rect(lane_rect, Color(0.95, 0.25, 0.15, bg_alpha), true)
			draw_line(Vector2(-half_dist, -hand_radius), Vector2(half_dist, -hand_radius), Color(1.0, 0.35, 0.2, border_alpha), 5.0)
			draw_line(Vector2(-half_dist, hand_radius), Vector2(half_dist, hand_radius), Color(1.0, 0.35, 0.2, border_alpha), 5.0)

			var fill_w := sweep_distance * t
			var fill_x := -half_dist if sweep_direction > 0 else (half_dist - fill_w)
			draw_rect(Rect2(Vector2(fill_x, -hand_radius), Vector2(fill_w, hand_radius * 2.0)), Color(1.0, 0.2, 0.1, 0.14), true)

			var arrow_col := Color(1.0, 0.85, 0.3, lerpf(0.35, 0.95, pulse))
			var step := 320.0
			var x := -half_dist + 200.0
			while x <= half_dist - 200.0:
				var tip := Vector2(x + 48.0 * float(sweep_direction), 0.0)
				var top_wing := Vector2(x - 32.0 * float(sweep_direction), -46.0)
				var bot_wing := Vector2(x - 32.0 * float(sweep_direction), 46.0)
				draw_line(top_wing, tip, arrow_col, 7.5)
				draw_line(bot_wing, tip, arrow_col, 7.5)
				x += step

			var windup_t := clampf(t / 0.8, 0.0, 1.0)
			var eased_charge := 1.0 - pow(1.0 - windup_t, 2.0)
			var tremor := sin(timer * 55.0) * 4.5 if t > 0.8 else 0.0

			var start_x := -half_dist * float(sweep_direction)
			var pullback_x := -windup_pullback_distance * float(sweep_direction) * eased_charge
			var charge_pos := Vector2(start_x + pullback_x + tremor, 0.0)
			var charge_rot := -deg_to_rad(windup_max_degrees) * float(sweep_direction) * eased_charge

			_draw_hand_transformed(active_tex, charge_pos + charge_shadow_offset, charge_rot, shadow_diam, shadow_color, flip_h, true)
			_draw_hand_transformed(active_tex, charge_pos, charge_rot, diam, Color.WHITE, flip_h, true)

		State.SWEEPING:
			draw_rect(lane_rect, Color(0.95, 0.25, 0.15, 0.08), true)

			var hand_pos := Vector2(current_hand_local_x, 0.0)
			var sweep_rot := deg_to_rad(sweep_forward_tilt_degrees) * float(sweep_direction)

			_draw_hand_transformed(active_tex, hand_pos + sweep_shadow_offset, sweep_rot, shadow_diam, shadow_color, flip_h, false)
			_draw_hand_transformed(active_tex, hand_pos, sweep_rot, diam, Color.WHITE, flip_h, false)
