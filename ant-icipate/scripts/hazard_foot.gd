extends Node2D
## Stomping foot hazard.

@export var radius: float = 140.0            # kill zone radius
@export var telegraph_time: float = 1.75
@export var linger_time: float = 1.0
@export var start_shadow_scale: float = 1.4
@export var hit_offset: Vector2 = Vector2(0, -33)  # ant sprite sit above its node origin
@export var foot_texture: Texture2D = null
@export var foot_visual_scale_multiplier: float = 1.1

var leader: Node2D = null

enum State { TELEGRAPH, STOMPED }
var state: State = State.TELEGRAPH
var timer: float = 0.0

func _ready() -> void:
	z_index = -1  # shadow under the ants

func _process(delta: float) -> void:
	timer += delta
	match state:
		State.TELEGRAPH:
			if timer >= telegraph_time:
				_stomp()
		State.STOMPED:
			if timer >= linger_time:
				queue_free()
	queue_redraw()

func _stomp() -> void:
	state = State.STOMPED
	timer = 0.0
	z_index = 10  # foot over the ants
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

	if _is_under_foot(leader.global_position):
		if leader.followers.is_empty():
			if leader.has_method("die"):
				leader.die("Ant Leader terinjak saat tidak ada follower tersisa!")
		elif killed == 0:
			leader.remove_follower(leader.followers.back())

func _draw() -> void:
	match state:
		State.TELEGRAPH:
			var t := clampf(timer / telegraph_time, 0.0, 1.0)
			var r := lerpf(radius * start_shadow_scale, radius, t)
			var alpha := lerpf(0.10, 0.80, t * t)
			draw_circle(Vector2.ZERO, r, Color(0, 0, 0, alpha))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0, 0, 0, minf(alpha + 0.2, 1.0)), 3.0)
		State.STOMPED:
			if foot_texture != null:
				var tex_size := foot_texture.get_size()
				var max_dim := maxf(tex_size.x, tex_size.y)
				if max_dim > 0.0:
					var target_diam := radius * 2.0 * foot_visual_scale_multiplier
					var draw_size := tex_size * (target_diam / max_dim)
					draw_texture_rect(foot_texture, Rect2(-draw_size * 0.5, draw_size), false)
			else:
				# placeholder foot, swap for real sprite later
				draw_circle(Vector2.ZERO, radius, Color(0.35, 0.20, 0.14))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.15, 0.08, 0.05), 6.0)
