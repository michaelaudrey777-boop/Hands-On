extends Node2D
## Stomping foot hazard.

@export var radius: float = 140.0            # kill zone radius
@export var telegraph_time: float = 1.75
@export var linger_time: float = 1.0
@export var start_shadow_scale: float = 1.4
@export var hit_offset: Vector2 = Vector2(0, -33)  # ant sprite sit above its node origin

@export_group("Visual Sprites")
@export var shadow_texture: Texture2D = null
@export var shadow_offset: Vector2 = Vector2(0, 18)
@export var shadow_visual_scale_multiplier: float = 1.0
@export var foot_texture: Texture2D = null
@export var foot_textures: Array[Texture2D] = []
@export var foot_visual_scale_multiplier: float = 1.1
@export var stomp_swap_delay: float = 0.25
@export var stomp_swap_interval: float = 0.08

var leader: Node2D = null

enum State { TELEGRAPH, STOMPED }
var state: State = State.TELEGRAPH
var timer: float = 0.0
var swap_timer: float = 0.0
var active_foot_textures: Array[Texture2D] = []
var current_foot_index: int = 0

func _ready() -> void:
	z_index = -1  # shadow under the ants

func _process(delta: float) -> void:
	timer += delta
	match state:
		State.TELEGRAPH:
			if timer >= telegraph_time:
				_stomp()
		State.STOMPED:
			if active_foot_textures.size() > 1 and timer >= stomp_swap_delay:
				swap_timer += delta
				if swap_timer >= stomp_swap_interval:
					swap_timer -= stomp_swap_interval
					current_foot_index = (current_foot_index + 1) % active_foot_textures.size()
			if timer >= linger_time:
				queue_free()
	queue_redraw()

func _stomp() -> void:
	state = State.STOMPED
	timer = 0.0
	swap_timer = 0.0
	z_index = 10  # foot over the ants

	active_foot_textures.clear()
	for tex in foot_textures:
		if tex != null:
			active_foot_textures.append(tex)
	if active_foot_textures.is_empty() and foot_texture != null:
		active_foot_textures.append(foot_texture)

	if not active_foot_textures.is_empty():
		current_foot_index = randi() % active_foot_textures.size()

	_kill_ants_underneath()

func _is_under_foot(pos: Vector2) -> bool:
	return (pos + hit_offset).distance_to(global_position) <= radius

func _kill_ants_underneath() -> void:
	if leader == null or not is_instance_valid(leader):
		return
	if leader.get("is_dead") == true:
		return

	var killed := 0
	var squad: Array = leader.followers.duplicate()
	for ant in squad:
		if is_instance_valid(ant) and _is_under_foot(ant.global_position):
			leader.remove_follower(ant)
			killed += 1

	# Jika AntLeader berada di dalam area injakan:
	# - Memicu efek hit flash pada AntLeader
	# - Bila follower habis (0), AntLeader gugur (Game Over)
	# - Bila belum ada follower yang terinjak, korbankan follower paling belakang
	if _is_under_foot(leader.global_position):
		if leader.has_method("play_hit_flash"):
			leader.play_hit_flash()

		if leader.followers.is_empty():
			if leader.has_method("die"):
				leader.die("Ant Leader terinjak saat tidak ada follower tersisa!")
		elif killed == 0:
			leader.remove_follower(leader.followers.back())

func _draw_centered_texture(tex: Texture2D, target_diameter: float, modulate_color: Color, offset: Vector2 = Vector2.ZERO) -> void:
	var tex_size := tex.get_size()
	var max_dim := maxf(tex_size.x, tex_size.y)
	if max_dim <= 0.0:
		return
	var draw_size := tex_size * (target_diameter / max_dim)
	draw_texture_rect(tex, Rect2(-draw_size * 0.5 + offset, draw_size), false, modulate_color)

func _draw() -> void:
	match state:
		State.TELEGRAPH:
			var t := clampf(timer / telegraph_time, 0.0, 1.0)
			var r := lerpf(radius * start_shadow_scale, radius, t)
			var alpha := lerpf(0.15, 0.85, t * t)

			if shadow_texture != null:
				_draw_centered_texture(shadow_texture, r * 2.0 * shadow_visual_scale_multiplier, Color(1, 1, 1, alpha), shadow_offset)
			else:
				draw_circle(shadow_offset, r, Color(0, 0, 0, alpha))
				draw_arc(shadow_offset, r, 0.0, TAU, 64, Color(0, 0, 0, minf(alpha + 0.2, 1.0)), 3.0)
		State.STOMPED:
			if shadow_texture != null:
				_draw_centered_texture(shadow_texture, radius * 2.0 * shadow_visual_scale_multiplier, Color(1, 1, 1, 0.85), shadow_offset)

			if not active_foot_textures.is_empty():
				var current_tex := active_foot_textures[current_foot_index]
				_draw_centered_texture(current_tex, radius * 2.0 * foot_visual_scale_multiplier, Color.WHITE)
			else:
				draw_circle(Vector2.ZERO, radius, Color(0.35, 0.20, 0.14))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.15, 0.08, 0.05), 6.0)
