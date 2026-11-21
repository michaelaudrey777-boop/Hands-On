extends Node2D

@export var follower_scene: PackedScene
@export var leader: Node2D
@export var initial_spawn_delay: float = 15.0
@export var spawn_interval: float = 10.0

@export_group("Round Loop & Ant Dens")
@export var ant_dens: Array[Area2D] = []
@export var round_max_items: Array[int] = [10, 15, 20]
@export var round_spawn_mins: Array[Vector2] = []
@export var round_spawn_maxs: Array[Vector2] = []

@export_group("Item Spawn Settings")
@export var item_scene: PackedScene
@export var initial_item_delay: float = 3.0
@export var item_spawn_interval: float = 9.0
@export var max_items_on_map: int = 10
@export var min_item_distance_from_leader: float = 600.0
@export var min_distance_between_items: float = 350.0

@export_group("Default Spawn Area & Distribution")
@export var spawn_area_min: Vector2 = Vector2(100, 100)
@export var spawn_area_max: Vector2 = Vector2(1800, 1000)
@export var grid_columns: int = 4
@export var grid_rows: int = 3
@export var min_distance_from_leader: float = 300.0

@onready var status_label: Label = get_node_or_null("HUD/StatusLabel")

@export_group("Hazard Settings")
@export var foot_scene: PackedScene
@export var initial_hazard_delay: float = 20.0
@export var hazard_interval: float = 20.0
@export var hazard_spawn_range: float = 1200.0
@export var target_squad_chance: float = 0.5

const ITEM_CATALOG: Array[Dictionary] = [
	{
		"name": "Bread Crumb",
		"weight": 1,
		"food": 3,
		"water": 0,
		"score": 3,
		"color": Color(0.95, 0.75, 0.35),
		"spawn_weight": 40
	},
	{
		"name": "Water Droplet",
		"weight": 2,
		"food": 0,
		"water": 3,
		"score": 4,
		"color": Color(0.30, 0.75, 1.00),
		"spawn_weight": 35
	},
	{
		"name": "Fruit Piece",
		"weight": 10,
		"food": 4,
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
		"spawn_weight": 6
	},
	{
		"name": "Meat",
		"weight": 80,
		"food": 8,
		"water": 3,
		"score": 35,
		"color": Color(0.75, 0.20, 0.20),
		"spawn_weight": 4
	}
]

var current_round: int = 1
var total_points: int = 0
var food_quota: int = 32
var water_quota: int = 21
var game_finished: bool = false

var ui_followers: int = 3
var ui_max_followers: int = 5
var ui_weight: int = 0
var ui_max_capacity: int = 32
var ui_food: int = 0
var ui_water: int = 0
var ui_overweight: bool = false
var hud_alert_message: String = ""

var available_follower_cells: Array[Vector2i] = []
var available_item_cells: Array[Vector2i] = []

func _ready() -> void:
	if leader != null:
		if leader.has_signal("inventory_updated"):
			leader.inventory_updated.connect(_on_inventory_updated)
		if leader.has_signal("squad_updated"):
			leader.squad_updated.connect(_on_squad_updated)

	for den in ant_dens:
		if den != null and den.has_signal("den_reached"):
			den.den_reached.connect(_on_den_reached)

	_setup_round(1)

	_start_item_spawn_loop()
	_start_hazard_loop()

	await get_tree().create_timer(initial_spawn_delay).timeout
	if not is_inside_tree():
		return

	_on_spawn_timer_timeout()

	var follower_timer := Timer.new()
	follower_timer.wait_time = spawn_interval
	follower_timer.autostart = true
	follower_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(follower_timer)

func _setup_round(round_num: int) -> void:
	current_round = round_num
	var idx := round_num - 1

	for i in range(ant_dens.size()):
		var den := ant_dens[i]
		if den == null:
			continue
		if i < idx:
			den.set_den_state(false, true)
		elif i == idx:
			den.set_den_state(true, false)
			food_quota = den.get("required_food")
			water_quota = den.get("required_water")
		else:
			den.set_den_state(false, false)

	if idx >= 0 and idx < round_max_items.size():
		max_items_on_map = round_max_items[idx]

	if idx >= 0 and idx < round_spawn_mins.size() and idx < round_spawn_maxs.size():
		spawn_area_min = round_spawn_mins[idx]
		spawn_area_max = round_spawn_maxs[idx]

	_refill_cells(available_follower_cells)
	_refill_cells(available_item_cells)
	_refresh_hud()

func _on_den_reached(den: Area2D, leader_body: Node2D) -> void:
	if game_finished:
		return

	var current_food: int = leader_body.get_total_food()
	var current_water: int = leader_body.get_total_water()
	var req_food: int = den.get("required_food")
	var req_water: int = den.get("required_water")

	if current_food < req_food or current_water < req_water:
		_show_hud_alert("Kuota belum cukup! Butuh %d Food & %d Water." % [req_food, req_water], 3.5)
		return

	var deposit: Dictionary = leader_body.deposit_all_items()
	var surplus_food: int = max(0, deposit["food"] - req_food)
	var surplus_water: int = max(0, deposit["water"] - req_water)
	var surviving_ants: int = leader_body.followers.size()

	var earned_points: int = (
		deposit["base_score"] +
		(surplus_food * 10) +
		(surplus_water * 10) +
		(surviving_ants * 5)
	)
	total_points += earned_points

	print("=== %s SELESAI! Poin didapat: +%d (Surplus Food: %d, Surplus Water: %d) | Total Poin: %d ===" % [
		den.get("den_name"), earned_points, surplus_food, surplus_water, total_points
	])

	if current_round < ant_dens.size():
		var upgrade_msg := ""
		if leader_body.has_method("apply_random_upgrade"):
			upgrade_msg = leader_body.apply_random_upgrade()

		_setup_round(current_round + 1)
		_show_hud_alert("ROUND %d SELESAI! (+%d Poin)\nUpgrade Acak: %s" % [current_round - 1, earned_points, upgrade_msg], 5.0)
	else:
		game_finished = true
		den.set_den_state(false, true)
		_show_hud_alert("SEMUA ANT DEN SELESAI! Total Poin Akhir: %d" % total_points, 999.0)

func _show_hud_alert(msg: String, duration: float) -> void:
	hud_alert_message = msg
	_refresh_hud()

	if duration < 900.0:
		await get_tree().create_timer(duration).timeout
		if hud_alert_message == msg:
			hud_alert_message = ""
			_refresh_hud()

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
	if follower_scene == null or game_finished:
		return

	var current_count := get_tree().get_nodes_in_group("followers").size()
	var max_limit: int = leader.get("max_followers") if (leader != null and leader.get("max_followers") != null) else 5
	if current_count >= max_limit:
		return

	var wild_follower := follower_scene.instantiate() as Node2D
	wild_follower.global_position = _get_follower_spawn_position()
	add_child(wild_follower)

func _on_item_spawn_timer_timeout() -> void:
	if item_scene == null or game_finished:
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
	var alert_line := ("\n>>> %s <<<" % hud_alert_message) if hud_alert_message != "" else ""
	status_label.text = (
		"ROUND %d / %d  |  Poin: %d\n" % [current_round, ant_dens.size(), total_points] +
		"Semut Follower: %d / %d\n" % [ui_followers, ui_max_followers] +
		"Kapasitas: %d / %d CC%s\n" % [ui_weight, ui_max_capacity, warning] +
		"Food: %d / %d  |  Water: %d / %d%s" % [ui_food, food_quota, ui_water, water_quota, alert_line]
	)

func _start_hazard_loop() -> void:
	await get_tree().create_timer(initial_hazard_delay).timeout
	while is_inside_tree() and not game_finished:
		_spawn_foot()
		# hazards scale up each nest: less wait every round, min 5 sec
		var wait := maxf(5.0, hazard_interval - (current_round - 1) * 5.0)
		await get_tree().create_timer(wait).timeout

func _spawn_foot() -> void:
	if foot_scene == null or leader == null:
		return
	var foot := foot_scene.instantiate() as Node2D
	foot.leader = leader
	foot.global_position = _get_foot_position()
	add_child(foot)

func _get_foot_position() -> Vector2:
	var squad: Array = leader.get("followers")
	if not squad.is_empty() and randf() < target_squad_chance:
		return squad.pick_random().global_position

	var targets: Array = []
	for item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(item) and item.global_position.distance_to(leader.global_position) <= hazard_spawn_range:
			targets.append(item)

	var base: Vector2 = leader.global_position
	if not targets.is_empty():
		base = targets.pick_random().global_position
	return base + Vector2(randf_range(-120, 120), randf_range(-120, 120))
