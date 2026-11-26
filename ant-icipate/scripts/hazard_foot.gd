extends Node2D

@export var foot_radius: float = 250.0
@export var telegraph_time: float = 1.55
@export var stomp_hold_time: float = 0.60
@export var lift_time: float = 0.38
@export var hit_offset: Vector2 = Vector2(0, -33)

@export_group("Visual Sprites")
@export var foot_textures: Array[Texture2D] = []
@export var foot_texture: Texture2D = null
@export var foot_visual_scale_multiplier: float = 1.40
@export var drop_start_height: float = 820.0
@export var shadow_offset: Vector2 = Vector2(10.0, 22.0)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.45)

var leader: Node2D = null

enum State { TELEGRAPH, STOMPED, LIFTING }
var state: State = State.TELEGRAPH
var timer: float = 0.0
var chosen_texture: Texture2D = null
var flip_horizontal: bool = false

func _ready() -> void:
	z_index = 10
	flip_horizontal = randf() < 0.5

	var valid_textures: Array[Texture2D] = []
	for t in foot_textures:
		if t != null:
			valid_textures.append(t)

	if not valid_textures.is_empty():
		chosen_texture = valid_textures.pick_random()
	elif foot_texture != null:
		chosen_texture = foot_texture
	else:
		var child_sprite := get_node_or_null("Sprite2D") as Sprite2D
		if child_sprite != null:
			if child_sprite.texture != null:
				chosen_texture = child_sprite.texture
			child_sprite.visible = false

func _process(delta: float) -> void:
	timer += delta

	match state:
		State.TELEGRAPH:
			if timer >= telegraph_time:
				_stomp()
		State.STOMPED:
			if timer >= stomp_hold_time:
				state = State.LIFTING
				timer = 0.0
		State.LIFTING:
			if timer >= lift_time:
				queue_free()
				return

	queue_redraw()

func _stomp() -> void:
	state = State.STOMPED
	timer = 0.0
	z_index = 12

	if leader != null and is_instance_valid(leader) and leader.has_method("trigger_stomp_effect"):
		leader.trigger_stomp_effect(global_position, 1.2)

	var audio := AudioManager.get_instance(get_tree())
	if audio != null:
		audio.play_foot_stomp(global_position)

	VFX.spawn_stomp_dust(get_parent(), global_position, foot_radius)
	_check_stomp_hits()

func _is_point_stomped(world_pos: Vector2) -> bool:
	var p := world_pos + hit_offset
	return p.distance_to(global_position) <= foot_radius

func _check_stomp_hits() -> void:
	if leader == null or not is_instance_valid(leader):
		return
	if leader.get("is_dead") == true:
		return

	var killed_count := 0
	var squad: Array = leader.followers.duplicate()
	for ant in squad:
		if is_instance_valid(ant) and _is_point_stomped(ant.global_position):
			leader.remove_follower(ant)
			killed_count += 1

	if _is_point_stomped(leader.global_position):
		if leader.has_method("play_hit_flash"):
			leader.play_hit_flash()

		if leader.followers.is_empty():
			if leader.has_method("die"):
				leader.die("Ant Leader was stomped by a human foot!")
		elif killed_count == 0:
			leader.remove_follower(leader.followers.back())

func _draw_foot_sprite(local_pos: Vector2, scale_mult: float, modulate_color: Color) -> void:
	var scale_vec := Vector2(-scale_mult if flip_horizontal else scale_mult, scale_mult)
	draw_set_transform(local_pos, 0.0, scale_vec)

	var diam := foot_radius * 2.0 * foot_visual_scale_multiplier
	if chosen_texture != null:
		var tex_size := chosen_texture.get_size()
		var max_dim := maxf(tex_size.x, tex_size.y)
		if max_dim > 0.0:
			var draw_size := tex_size * (diam / max_dim)
			draw_texture_rect(chosen_texture, Rect2(-draw_size * 0.5, draw_size), false, modulate_color)
	else:
		var sole_col := Color(0.86, 0.64, 0.50, modulate_color.a)
		draw_circle(Vector2.ZERO, foot_radius * 0.92, sole_col)
		if modulate_color.a > 0.4:
			draw_arc(Vector2.ZERO, foot_radius * 0.92, 0.0, TAU, 48, Color(0.45, 0.28, 0.20, modulate_color.a), 6.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	match state:
		State.TELEGRAPH:
			var t := clampf(timer / telegraph_time, 0.0, 1.0)
			var pulse := 0.5 + 0.5 * sin(timer * 18.0)

			var fill_alpha := lerpf(0.08, 0.26, t)
			var border_alpha := lerpf(0.35, 0.92, t)
			draw_circle(Vector2.ZERO, foot_radius, Color(0.95, 0.22, 0.14, fill_alpha))
			draw_arc(Vector2.ZERO, foot_radius, 0.0, TAU, 56, Color(1.0, 0.35, 0.2, border_alpha), 5.5, true)

			var inner_r := lerpf(foot_radius, 18.0, t)
			draw_arc(Vector2.ZERO, inner_r, 0.0, TAU, 48, Color(1.0, 0.85, 0.3, lerpf(0.35, 0.95, pulse)), 4.0, true)

			var shadow_scale := lerpf(0.42, 1.0, pow(t, 1.35))
			var shadow_alpha := lerpf(0.16, shadow_color.a, t)
			_draw_foot_sprite(shadow_offset, shadow_scale, Color(0.0, 0.0, 0.0, shadow_alpha))

			if t > 0.65:
				var drop_t := (t - 0.65) / 0.35
				var eased_drop := pow(drop_t, 2.2)
				var height := lerpf(drop_start_height, 0.0, eased_drop)
				var alpha := clampf(drop_t * 1.4, 0.0, 1.0)
				_draw_foot_sprite(Vector2(0.0, -height), 1.0, Color(1.0, 1.0, 1.0, alpha))

		State.STOMPED:
			var impact_t := clampf(timer / 0.14, 0.0, 1.0)
			var squash := lerpf(1.10, 1.0, impact_t)

			if impact_t < 1.0:
				var wave_r := lerpf(foot_radius * 0.95, foot_radius * 1.45, impact_t)
				draw_arc(Vector2.ZERO, wave_r, 0.0, TAU, 56, Color(0.85, 0.72, 0.58, (1.0 - impact_t) * 0.75), 7.5, true)

			_draw_foot_sprite(shadow_offset, squash, shadow_color)
			_draw_foot_sprite(Vector2.ZERO, squash, Color.WHITE)

		State.LIFTING:
			var t := clampf(timer / lift_time, 0.0, 1.0)
			var eased := pow(t, 1.6)
			var height := lerpf(0.0, drop_start_height * 0.75, eased)
			var alpha := 1.0 - eased
			var shadow_scale := lerpf(1.0, 0.48, eased)

			_draw_foot_sprite(shadow_offset, shadow_scale, Color(0.0, 0.0, 0.0, shadow_color.a * alpha))
			_draw_foot_sprite(Vector2(0.0, -height), 1.0, Color(1.0, 1.0, 1.0, alpha))
