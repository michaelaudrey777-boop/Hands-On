class_name VFX
extends RefCounted

static func _get_dot_texture() -> Texture2D:
	if Engine.has_meta(&"_vfx_soft_dot_tex"):
		var cached := Engine.get_meta(&"_vfx_soft_dot_tex") as Texture2D
		if cached != null:
			return cached

	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size - 1, size - 1) * 0.5
	var max_r := float(size) * 0.5

	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(center) / max_r
			var alpha := clampf(1.0 - smoothstep(0.35, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(&"_vfx_soft_dot_tex", tex)
	return tex

static func _spawn_burst(
	parent: Node,
	world_pos: Vector2,
	amount: int,
	lifetime: float,
	color: Color,
	speed_min: float,
	speed_max: float,
	scale_min: float,
	scale_max: float,
	spread_deg: float = 180.0,
	direction: Vector2 = Vector2.UP,
	gravity: Vector2 = Vector2.ZERO,
	z_idx: int = 8
) -> void:
	if parent == null or not parent.is_inside_tree():
		return

	var p := CPUParticles2D.new()
	p.global_position = world_pos
	p.z_index = z_idx
	p.texture = _get_dot_texture()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = true

	p.direction = direction
	p.spread = spread_deg
	p.gravity = gravity
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.damping_min = 90.0
	p.damping_max = 180.0
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max

	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, color.a))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = grad

	parent.add_child(p)
	parent.get_tree().create_timer(lifetime + 0.25).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)

static func spawn_pickup(parent: Node, world_pos: Vector2, item_color: Color) -> void:
	var bright := item_color.lightened(0.25)
	_spawn_burst(parent, world_pos, 14, 0.42, bright, 75.0, 175.0, 0.45, 0.95, 180.0, Vector2.UP, Vector2(0, 140), 9)

static func spawn_step_dust(parent: Node, world_pos: Vector2) -> void:
	var dust := Color(0.76, 0.62, 0.52, 0.42)
	_spawn_burst(parent, world_pos + Vector2(0, 18), 3, 0.30, dust, 18.0, 45.0, 0.30, 0.55, 180.0, Vector2.UP, Vector2.ZERO, -2)

static func spawn_recruit_sparkle(parent: Node, world_pos: Vector2) -> void:
	var sparkle := Color(0.42, 0.96, 0.55, 0.95)
	_spawn_burst(parent, world_pos, 18, 0.55, sparkle, 85.0, 195.0, 0.45, 0.95, 180.0, Vector2.UP, Vector2(0, -40), 10)

static func spawn_hit_burst(parent: Node, world_pos: Vector2) -> void:
	_spawn_burst(parent, world_pos, 16, 0.45, Color(0.95, 0.24, 0.20, 0.95), 110.0, 250.0, 0.45, 0.90, 180.0, Vector2.UP, Vector2(0, 180), 11)
	_spawn_burst(parent, world_pos, 10, 0.50, Color(0.55, 0.42, 0.35, 0.65), 60.0, 140.0, 0.60, 1.10, 180.0, Vector2.UP, Vector2.ZERO, 10)

static func spawn_stomp_dust(parent: Node, world_pos: Vector2, radius: float = 150.0) -> void:
	var dust := Color(0.68, 0.52, 0.42, 0.72)
	var scale_boost := clampf(radius / 150.0, 0.8, 1.8)
	_spawn_burst(parent, world_pos, 28, 0.62, dust, 180.0 * scale_boost, 360.0 * scale_boost, 0.85 * scale_boost, 1.65 * scale_boost, 180.0, Vector2.RIGHT, Vector2.ZERO, 9)

static func spawn_swipe_wind(parent: Node, world_pos: Vector2, sweep_dir: float) -> void:
	var wind := Color(0.95, 0.88, 0.78, 0.55)
	var dir := Vector2(1.0 if sweep_dir >= 0.0 else -1.0, 0.0)
	_spawn_burst(parent, world_pos, 22, 0.45, wind, 260.0, 520.0, 0.55, 1.15, 28.0, dir, Vector2.ZERO, 11)

static func spawn_celebration(parent: Node, world_pos: Vector2) -> void:
	_spawn_burst(parent, world_pos, 32, 0.85, Color(1.0, 0.86, 0.32, 1.0), 140.0, 340.0, 0.55, 1.15, 180.0, Vector2.UP, Vector2(0, 120), 15)
	_spawn_burst(parent, world_pos, 20, 0.85, Color(0.38, 0.98, 0.52, 1.0), 120.0, 290.0, 0.50, 1.00, 180.0, Vector2.UP, Vector2(0, 120), 15)
