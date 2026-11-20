extends Node2D

@export var follower_scene: PackedScene
@export var leader: Node2D
@export var initial_spawn_delay: float = 15.0
@export var spawn_interval: float = 10.0

@export_group("Item Spawn Settings")
@export var item_scene: PackedScene
@export var initial_item_delay: float = 3.0
@export var item_spawn_interval: float = 9.0
@export var max_items_on_map: int = 10
@export var min_item_distance_from_leader: float = 600.0
@export var min_distance_between_items: float = 350.0

@export_group("Spawn Area & Distribution")
@export var spawn_area_min: Vector2 = Vector2(100, 100)
@export var spawn_area_max: Vector2 = Vector2(1800, 1000)
@export var grid_columns: int = 4
@export var grid_rows: int = 3
@export var min_distance_from_leader: float = 300.0

@export_group("UI & Quota")
@export var food_quota: int = 5
@export var water_quota: int = 3
@onready var status_label: Label = get_node_or_null("HUD/StatusLabel")

const ITEM_CATALOG: Array[Dictionary] = [
	{
		"name": "Bread Crumb",
		"weight": 1,
		"food": 1,
		"water": 0,
		"score": 3,
		"color": Color(0.95, 0.75, 0.35),
		"spawn_weight": 40
	},
	{
		"name": "Water Droplet",
		"weight": 2,
		"food": 0,
		"water": 1,
		"score": 4,
		"color": Color(0.30, 0.75, 1.00),
		"spawn_weight": 30
	},
	{
		"name": "Fruit Piece",
		"weight": 10,
		"food": 2,
		"water": 2,
		"score": 12,
		"color": Color(0.90, 0.25, 0.35),
		"spawn_weight": 15
	},
	{
		"name": "Sugar Cube",
		"weight": 60,
		"food": 6,
		"water": 0,
		"score": 25,
		"color": Color(0.95, 0.95, 1.00),
		"spawn_weight": 9
	},
	{
		"name": "Meat",
		"weight": 80,
		"food": 8,
		"water": 0,
		"score": 35,
		"color": Color(0.75, 0.20, 0.20),
		"spawn_weight": 4
	}
]

var ui_followers: int = 3
var ui_max_followers: int = 5
var ui_weight: int = 0
var ui_max_capacity: int = 32
var ui_food: int = 0
var ui_water: int = 0
var ui_overweight: bool = false

var available_follower_cells: Array[Vector2i] = []
var available_item_cells: Array[Vector2i] = []

func _ready() -> void:
	if leader != null:
		if leader.has_signal("inventory_updated"):
			leader.inventory_updated.connect(_on_inventory_updated)
		if leader.has_signal("squad_updated"):
			leader.squad_updated.connect(_on_squad_updated)
	_refresh_hud()

	_refill_cells(available_follower_cells)
	_refill_cells(available_item_cells)

	_start_item_spawn_loop()

	await get_tree().create_timer(initial_spawn_delay).timeout
	if not is_inside_tree():
		return

	_on_spawn_timer_timeout()

	var follower_timer := Timer.new()
	follower_timer.wait_time = spawn_interval
	follower_timer.autostart = true
	follower_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(follower_timer)

func _start_item_spawn_loop() -> void:
	await get_tree().create_timer(initial_item_delay).timeout
	if not is_inside_tree():
		return

	_on_item_spawn_timer_timeout()

	var item_timer := Timer.new()
	item_timer.wait_time = item_spawn_interval
	item_timer.autostart = true
	item_timer.timeout.connect(_on_item_spawn_timer_timeout)
	add_child(item_timer)

func _refill_cells(cells_pool: Array[Vector2i]) -> void:
	cells_pool.clear()
	for x in range(grid_columns):
		for y in range(grid_rows):
			cells_pool.append(Vector2i(x, y))
	cells_pool.shuffle()

func _on_spawn_timer_timeout() -> void:
	if follower_scene == null:
		return

	var current_count := get_tree().get_nodes_in_group("followers").size()
	var max_limit: int = leader.get("max_followers") if (leader != null and leader.get("max_followers") != null) else 5
	if current_count >= max_limit:
		return

	var wild_follower := follower_scene.instantiate() as Node2D
	wild_follower.global_position = _get_follower_spawn_position()
	add_child(wild_follower)

	var waktu_spawn := Time.get_ticks_msec() / 1000.0
	var pos := wild_follower.global_position
	var urutan := current_count + 1
	print("[%.1f detik] AntFollower #%d spawn di koordinat: (%.0f, %.0f)" % [waktu_spawn, urutan, pos.x, pos.y])

func _on_item_spawn_timer_timeout() -> void:
	if item_scene == null:
		return

	var current_items := get_tree().get_nodes_in_group("items").size()
	if current_items >= max_items_on_map:
		return

	var spawn_pos := _get_spaced_item_position()
	if spawn_pos == Vector2.INF:
		return

	var item_data := _pick_random_item_data()
	var new_item := item_scene.instantiate() as Area2D
	new_item.global_position = spawn_pos
	if new_item.has_method("apply_data"):
		new_item.apply_data(item_data)
	add_child(new_item)

	var waktu_spawn := Time.get_ticks_msec() / 1000.0
	var jarak := leader.global_position.distance_to(spawn_pos) if leader != null else 0.0
	print("[%.1f detik] Item '%s' (%d CC) spawn di (%.0f, %.0f) | Jarak dari Leader: %.0f px" % [
		waktu_spawn, item_data["name"], item_data["weight"], spawn_pos.x, spawn_pos.y, jarak
	])

func _pick_random_item_data() -> Dictionary:
	var total_weight := 0
	for entry in ITEM_CATALOG:
		total_weight += entry["spawn_weight"]

	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for entry in ITEM_CATALOG:
		cumulative += entry["spawn_weight"]
		if roll <= cumulative:
			return entry

	return ITEM_CATALOG[0]

func _get_follower_spawn_position() -> Vector2:
	var cell_size := Vector2(
		(spawn_area_max.x - spawn_area_min.x) / float(grid_columns),
		(spawn_area_max.y - spawn_area_min.y) / float(grid_rows)
	)
	var padding := cell_size * 0.15

	for attempt in range(grid_columns * grid_rows):
		if available_follower_cells.is_empty():
			_refill_cells(available_follower_cells)

		var cell: Vector2i = available_follower_cells.pop_front()
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

func _get_spaced_item_position() -> Vector2:
	var cell_size := Vector2(
		(spawn_area_max.x - spawn_area_min.x) / float(grid_columns),
		(spawn_area_max.y - spawn_area_min.y) / float(grid_rows)
	)
	var padding := cell_size * 0.2

	for attempt in range(grid_columns * grid_rows):
		if available_item_cells.is_empty():
			_refill_cells(available_item_cells)

		var cell: Vector2i = available_item_cells.pop_front()
		var cell_min := spawn_area_min + Vector2(cell.x * cell_size.x, cell.y * cell_size.y) + padding
		var cell_max := cell_min + cell_size - (padding * 2.0)

		var candidate_pos := Vector2(
			randf_range(cell_min.x, cell_max.x),
			randf_range(cell_min.y, cell_max.y)
		)

		if _is_valid_item_position(candidate_pos):
			return candidate_pos

	for i in range(30):
		var random_pos := Vector2(
			randf_range(spawn_area_min.x, spawn_area_max.x),
			randf_range(spawn_area_min.y, spawn_area_max.y)
		)
		if _is_valid_item_position(random_pos):
			return random_pos

	return Vector2.INF

func _is_valid_item_position(pos: Vector2) -> bool:
	if leader != null and pos.distance_to(leader.global_position) < min_item_distance_from_leader:
		return false

	for existing_item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(existing_item) and pos.distance_to(existing_item.global_position) < min_distance_between_items:
			return false

	return true

func _on_inventory_updated(w: int, max_cap: int, f: int, wa: int, overweight: bool) -> void:
	ui_weight = w
	ui_max_capacity = max_cap
	ui_food = f
	ui_water = wa
	ui_overweight = overweight
	_refresh_hud()

func _on_squad_updated(curr: int, max_f: int) -> void:
	ui_followers = curr
	ui_max_followers = max_f
	_refresh_hud()

func _refresh_hud() -> void:
	if status_label == null:
		return
	var warning := " [OVERWEIGHT -90% SPEED!]" if ui_overweight else ""
	status_label.text = (
		"Semut Follower: %d / %d\n" % [ui_followers, ui_max_followers] +
		"Kapasitas: %d / %d CC%s\n" % [ui_weight, ui_max_capacity, warning] +
		"Food: %d / %d  |  Water: %d / %d" % [ui_food, food_quota, ui_water, water_quota]
	)
