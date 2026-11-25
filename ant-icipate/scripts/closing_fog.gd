extends Node2D

signal fog_started_closing

@export var leader: Node2D
@export var start_delay: float = 30.0
@export var warning_lead_time: float = 5.0
@export var round_fog_speeds: Array[float] = [48.0, 52.0, 56.0]
@export var fallback_fog_speed: float = 52.0
@export var damage_interval: float = 1.2

@export_group("Visual & Map Bounds")
@export var fog_top_y: float = -8500.0
@export var fog_bottom_y: float = 1500.0
@export var fog_color: Color = Color(0.07, 0.10, 0.08, 0.88)
@export var fog_edge_color: Color = Color(0.16, 0.23, 0.19, 0.55)

var is_running: bool = false
var is_closing: bool = false
var elapsed_time: float = 0.0
var anim_time: float = 0.0
var damage_timer: float = 0.0

var zone_min_x: float = 0.0
var zone_max_x: float = 8000.0
var fog_front_x: float = 0.0
var current_speed: float = 48.0

func _ready() -> void:
	z_index = 20

func start_round(min_x: float, max_x: float, round_num: int) -> void:
	zone_min_x = min_x
	zone_max_x = max_x
	fog_front_x = min_x
	elapsed_time = 0.0
	damage_timer = 0.0
	is_closing = false
	is_running = true

	var idx := round_num - 1
	if idx >= 0 and idx < round_fog_speeds.size():
		current_speed = round_fog_speeds[idx]
	elif not round_fog_speeds.is_empty():
		current_speed = round_fog_speeds.back()
	else:
		current_speed = fallback_fog_speed

	queue_redraw()

func stop() -> void:
	is_running = false

func is_in_fog(pos: Vector2, margin: float = 0.0) -> bool:
	if not is_closing:
		return false
	return pos.x <= (fog_front_x + margin)

func get_safe_min_x(padding: float = 300.0) -> float:
	if not is_closing:
		return zone_min_x
	return maxf(zone_min_x, fog_front_x + padding)

func _process(delta: float) -> void:
	anim_time += delta

	if not is_running:
		return

	elapsed_time += delta

	if not is_closing:
		if elapsed_time >= start_delay:
			is_closing = true
			fog_started_closing.emit()
	else:
		if fog_front_x < zone_max_x:
			fog_front_x = minf(zone_max_x, fog_front_x + current_speed * delta)
		_cleanup_wild_followers_in_fog()
		_apply_fog_damage(delta)

	if is_closing or elapsed_time >= (start_delay - warning_lead_time):
		queue_redraw()

func _cleanup_wild_followers_in_fog() -> void:
	for f in get_tree().get_nodes_in_group("followers"):
		if is_instance_valid(f) and f.get("line_target") == null:
			if f.global_position.x <= fog_front_x:
				f.queue_free()

func _apply_fog_damage(delta: float) -> void:
	if leader == null or not is_instance_valid(leader) or leader.get("is_dead") == true:
		return

	var squad: Array = leader.get("followers")
	var followers_in_fog: Array[Node2D] = []
	for f in squad:
		if is_instance_valid(f) and f.global_position.x <= fog_front_x:
			followers_in_fog.append(f)

	var leader_in_fog := leader.global_position.x <= fog_front_x

	if followers_in_fog.is_empty() and not leader_in_fog:
		damage_timer = 0.0
		return

	damage_timer += delta
	if damage_timer < damage_interval:
		return

	damage_timer = 0.0

	if not followers_in_fog.is_empty():
		leader.remove_follower(followers_in_fog.back())
	elif leader_in_fog:
		if squad.is_empty():
			if leader.has_method("die"):
				leader.die("Pasukan semut tertelan kabut beracun!")
		else:
			leader.remove_follower(squad.back())

func _draw() -> void:
	var fade := 1.0
	if not is_closing:
		var warn_start := start_delay - warning_lead_time
		if elapsed_time < warn_start:
			return
		fade = clampf((elapsed_time - warn_start) / maxf(0.1, warning_lead_time), 0.0, 1.0) * 0.45

	var left_x := zone_min_x - 800.0
	var height := fog_bottom_y - fog_top_y

	# Badan utama kabut dari sisi awal zona hingga garis depan kabut
	var body_col := Color(fog_color.r, fog_color.g, fog_color.b, fog_color.a * fade)
	var body_width := maxf(260.0, fog_front_x - left_x)
	draw_rect(Rect2(Vector2(fog_front_x - body_width, fog_top_y), Vector2(body_width, height)), body_col, true)

	# Lapisan gradasi peringatan di depan garis batas kabut
	var warn_col := Color(fog_edge_color.r, fog_edge_color.g, fog_edge_color.b, fog_edge_color.a * 0.55 * fade)
	draw_rect(Rect2(Vector2(fog_front_x, fog_top_y), Vector2(180.0, height)), warn_col, true)

	# Gumpalan awan kabut bergerak di sepanjang garis depan
	var puff_col := Color(fog_edge_color.r, fog_edge_color.g, fog_edge_color.b, fog_edge_color.a * fade)
	var step := 180.0
	var y := fog_top_y
	var idx := 0
	while y <= fog_bottom_y:
		var wave_x := sin(anim_time * 1.8 + float(idx) * 0.9) * 55.0
		var puff_radius := 210.0 + cos(anim_time * 1.3 + float(idx) * 1.2) * 35.0
		draw_circle(Vector2(fog_front_x + wave_x, y), puff_radius, puff_col)
		y += step
		idx += 1
