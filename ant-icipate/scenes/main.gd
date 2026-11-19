extends Node2D

@export var follower_scene: PackedScene
@export var leader: Node2D
@export var initial_spawn_delay: float = 15.0
@export var spawn_interval: float = 10.0
@export var max_total_followers: int = 10

@export_group("Spawn Area & Distribution")
@export var spawn_area_min: Vector2 = Vector2(100, 100)
@export var spawn_area_max: Vector2 = Vector2(1800, 1000)
@export var grid_columns: int = 3
@export var grid_rows: int = 3
@export var min_distance_from_leader: float = 300.0

var available_cells: Array[Vector2i] = []

func _ready() -> void:
	_refill_spawn_cells()

	await get_tree().create_timer(initial_spawn_delay).timeout
	if not is_inside_tree():
		return

	_on_spawn_timer_timeout()

	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(timer)

func _refill_spawn_cells() -> void:
	available_cells.clear()
	for x in range(grid_columns):
		for y in range(grid_rows):
			available_cells.append(Vector2i(x, y))
	available_cells.shuffle()

func _on_spawn_timer_timeout() -> void:
	if follower_scene == null:
		return

	var current_count := get_tree().get_nodes_in_group("followers").size()
	var max_limit: int = leader.get("max_followers") if (leader != null and leader.get("max_followers") != null) else 5
	if current_count >= max_limit:
		return

	var wild_follower := follower_scene.instantiate() as Node2D
	wild_follower.global_position = _get_even_spawn_position()
	add_child(wild_follower)

func _get_even_spawn_position() -> Vector2:
	var cell_size := Vector2(
		(spawn_area_max.x - spawn_area_min.x) / float(grid_columns),
		(spawn_area_max.y - spawn_area_min.y) / float(grid_rows)
	)
	var padding := cell_size * 0.15

	for attempt in range(grid_columns * grid_rows):
		if available_cells.is_empty():
			_refill_spawn_cells()

		var cell: Vector2i = available_cells.pop_front()
		var cell_min := spawn_area_min + Vector2(cell.x * cell_size.x, cell.y * cell_size.y) + padding
		var cell_max := cell_min + cell_size - (padding * 2.0)

		var candidate_pos := Vector2(
			randf_range(cell_min.x, cell_max.x),
			randf_range(cell_min.y, cell_max.y)
		)

		if leader == null or candidate_pos.distance_to(leader.global_position) >= min_distance_from_leader:
			return candidate_pos

	return Vector2(
		randf_range(spawn_area_min.x, spawn_area_max.x),
		randf_range(spawn_area_min.y, spawn_area_max.y)
	)
