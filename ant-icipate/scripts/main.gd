extends Node2D

@export var follower_scene: PackedScene
@export var leader: Node2D
@export var initial_spawn_delay: float = 8.0
@export var spawn_interval: float = 9.0

@export_group("Round Loop & Ant Dens")
@export var ant_dens: Array[Area2D] = []
@export var round_start_markers: Array[Marker2D] = []
@export var round_max_items: Array[int] = [30, 40, 50]
@export var initial_round_items: int = 18
@export var round_spawn_mins: Array[Vector2] = []
@export var round_spawn_maxs: Array[Vector2] = []

@export_group("Round Borders")
@export var forward_borders: Array[StaticBody2D] = []

@export_group("Item Spawn Settings")
@export var item_scene: PackedScene
@export var initial_item_delay: float = 2.0
@export var item_spawn_interval: float = 4.5
@export var max_items_on_map: int = 30
@export var min_item_distance_from_leader: float = 700.0
@export var min_distance_between_items: float = 650.0

@export_group("Item Sprites")
@export var tex_bread_crumb: Texture2D
@export var tex_water_droplet: Texture2D
@export var tex_fruit_piece: Texture2D
@export var tex_sugar_cube: Texture2D
@export var tex_meat_variants: Array[Texture2D] = []

@export_group("Default Spawn Area & Distribution")
@export var spawn_area_min: Vector2 = Vector2(350, -7650)
@export var spawn_area_max: Vector2 = Vector2(7650, 650)
@export var grid_columns: int = 6
@export var grid_rows: int = 6
@export var min_distance_from_leader: float = 450.0

@onready var status_label: Label = get_node_or_null("HUD/StatusLabel")
@onready var closing_fog: Node2D = get_node_or_null("ClosingFog")

@export_group("Hazard Foot Settings")
@export var foot_scene: PackedScene
@export var foot_textures: Array[Texture2D] = []
@export var initial_hazard_delay: float = 6.0
@export var round_hazard_intervals: Array[float] = [8.5, 5.5, 3.5]
@export var hazard_interval_fallback: float = 4.0
@export var hazard_spawn_range: float = 2200.0
@export var target_ants_chance: float = 0.55
@export var min_distance_between_hazards: float = 220.0

@export_group("Hazard Hand Settings")
@export var hand_scene: PackedScene
@export var charge_hand_texture: Texture2D
@export var sweep_hand_texture: Texture2D
@export var initial_hand_delay: float = 12.0
@export var round_hand_intervals: Array[float] = [16.0, 12.0, 8.5]
@export var hand_interval_fallback: float = 9.0

const ITEM_CATALOG: Array[Dictionary] = [
	{
		"name": "Bread Crumb",
		"weight": 1,
		"food": 2,
		"water": 0,
		"score": 3,
		"color": Color(0.95, 0.75, 0.35),
		"size_multiplier": 1.0,
		"spawn_weight": 40
	},
	{
		"name": "Water Droplet",
		"weight": 2,
		"food": 0,
		"water": 3,
		"score": 4,
		"color": Color(0.30, 0.75, 1.00),
		"size_multiplier": 1.0,
		"spawn_weight": 35
	},
	{
		"name": "Fruit Piece",
		"weight": 10,
		"food": 16,
		"water": 12,
		"score": 12,
		"color": Color(0.90, 0.25, 0.35),
		"size_multiplier": 1.0,
		"spawn_weight": 15,
		"max_on_map": 8
	},
	{
		"name": "Sugar Cube",
		"weight": 45,
		"food": 60,
		"water": 0,
		"score": 25,
		"color": Color(0.95, 0.95, 1.00),
		"size_multiplier": 1.0,
		"spawn_weight": 6,
		"max_on_map": 2
	},
	{
		"name": "Meat",
		"weight": 60,
		"food": 80,
		"water": 3,
		"score": 35,
		"color": Color(0.75, 0.20, 0.20),
		"size_multiplier": 1.0,
		"spawn_weight": 4,
		"max_on_map": 2
	}
]

var current_round: int = 1
var total_points: int = 0
var food_quota: int = 32
var water_quota: int = 21
var game_finished: bool = false
var is_game_over: bool = false

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

var reload_layer: CanvasLayer = null
var reload_root: Control = null
var reload_title_label: Label = null
var reload_reason_label: Label = null
var reload_stats_label: Label = null
var reload_button: Button = null

func _ready() -> void:
	_auto_recover_missing_references()
	_setup_reload_screen()

	if leader != null:
		if leader.has_signal("inventory_updated"):
			leader.inventory_updated.connect(_on_inventory_updated)
		if leader.has_signal("squad_updated"):
			leader.squad_updated.connect(_on_squad_updated)
		if leader.has_signal("leader_died"):
			leader.leader_died.connect(_on_leader_died)

	if closing_fog != null:
		closing_fog.leader = leader
		if closing_fog.has_signal("fog_started_closing"):
			closing_fog.fog_started_closing.connect(_on_fog_started_closing)

	for den in ant_dens:
		if den != null and den.has_signal("den_reached"):
			den.den_reached.connect(_on_den_reached)

	_setup_round(1)

	_start_item_spawn_loop()
	_start_hazard_loop()
	_start_hand_loop()

	await get_tree().create_timer(initial_spawn_delay).timeout
	if not is_inside_tree():
		return

	_on_spawn_timer_timeout()

	var follower_timer := Timer.new()
	follower_timer.wait_time = spawn_interval
	follower_timer.autostart = true
	follower_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(follower_timer)

func _setup_reload_screen() -> void:
	reload_layer = CanvasLayer.new()
	reload_layer.name = "ReloadScreenLayer"
	reload_layer.layer = 20
	add_child(reload_layer)

	reload_root = Control.new()
	reload_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	reload_root.visible = false
	reload_root.modulate.a = 0.0
	reload_layer.add_child(reload_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.03, 0.03, 0.68)
	reload_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	reload_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.07, 0.94)
	panel_style.border_color = Color(0.86, 0.26, 0.22, 0.95)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	panel_style.content_margin_top = 28
	panel_style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	reload_title_label = Label.new()
	reload_title_label.text = "SQUAD FALLEN"
	reload_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_title_label.add_theme_font_size_override("font_size", 32)
	reload_title_label.add_theme_color_override("font_color", Color(0.98, 0.34, 0.28, 1.0))
	vbox.add_child(reload_title_label)

	reload_reason_label = Label.new()
	reload_reason_label.text = "All follower ants have fallen!"
	reload_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reload_reason_label.add_theme_font_size_override("font_size", 17)
	reload_reason_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.85, 1.0))
	vbox.add_child(reload_reason_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	reload_stats_label = Label.new()
	reload_stats_label.text = "Round: 1 / 3  |  Total Points: 0"
	reload_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_stats_label.add_theme_font_size_override("font_size", 16)
	reload_stats_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42, 1.0))
	vbox.add_child(reload_stats_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	reload_button = Button.new()
	reload_button.text = "Play Again [R]"
	reload_button.custom_minimum_size = Vector2(240, 48)
	reload_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reload_button.add_theme_font_size_override("font_size", 18)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.76, 0.22, 0.18, 1.0)
	btn_normal.set_corner_radius_all(8)
	btn_normal.content_margin_left = 20
	btn_normal.content_margin_right = 20
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.90, 0.28, 0.22, 1.0)
	btn_hover.set_corner_radius_all(8)
	btn_hover.content_margin_left = 20
	btn_hover.content_margin_right = 20
	btn_hover.content_margin_top = 10
	btn_hover.content_margin_bottom = 10

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.56, 0.15, 0.12, 1.0)
	btn_pressed.set_corner_radius_all(8)
	btn_pressed.content_margin_left = 20
	btn_pressed.content_margin_right = 20
	btn_pressed.content_margin_top = 10
	btn_pressed.content_margin_bottom = 10

	reload_button.add_theme_stylebox_override("normal", btn_normal)
	reload_button.add_theme_stylebox_override("hover", btn_hover)
	reload_button.add_theme_stylebox_override("focus", btn_hover)
	reload_button.add_theme_stylebox_override("pressed", btn_pressed)
	reload_button.pressed.connect(_reload_game)
	vbox.add_child(reload_button)

func _show_reload_screen(title_text: String, reason_text: String, is_victory: bool = false) -> void:
	if reload_root == null:
		return

	reload_title_label.text = title_text
	reload_reason_label.text = reason_text
	reload_stats_label.text = "Round Reached: %d / %d  |  Total Points: %d" % [current_round, ant_dens.size(), total_points]

	var accent := Color(0.35, 0.92, 0.48, 1.0) if is_victory else Color(0.98, 0.34, 0.28, 1.0)
	reload_title_label.add_theme_color_override("font_color", accent)

	reload_root.visible = true
	reload_root.modulate.a = 0.0
	reload_button.grab_focus()

	var tw := create_tween()
	tw.tween_property(reload_root, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _reload_game() -> void:
	var audio := AudioManager.get_instance(get_tree())
	if audio != null:
		audio.play_button()
		await get_tree().create_timer(0.12).timeout
	if is_inside_tree():
		get_tree().reload_current_scene()

func _auto_recover_missing_references() -> void:
	if leader == null:
		leader = get_node_or_null("AntLeader")

	if ant_dens.is_empty():
		var found_dens: Array[Area2D] = []
		for node in find_children("*", "Area2D", true, false):
			if node.get("required_food") != null:
				found_dens.append(node as Area2D)
		found_dens.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
		ant_dens = found_dens

	if round_start_markers.is_empty():
		var found_markers: Array[Marker2D] = []
		for node in find_children("*", "Marker2D", true, false):
			if "Start" in node.name or "Round" in node.name:
				found_markers.append(node as Marker2D)
		found_markers.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
		round_start_markers = found_markers

	if forward_borders.is_empty():
		var found_borders: Array[StaticBody2D] = []
		for node in find_children("*", "StaticBody2D", true, false):
			if "Border" in node.name:
				found_borders.append(node as StaticBody2D)
		found_borders.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
		forward_borders = found_borders

	if round_spawn_mins.is_empty() and round_spawn_maxs.is_empty():
		round_spawn_mins = [Vector2(350, -7650), Vector2(8350, -7650), Vector2(16350, -7650)]
		round_spawn_maxs = [Vector2(7650, 650), Vector2(15650, 650), Vector2(23650, 650)]

	if follower_scene == null:
		follower_scene = _try_load_scene(["res://scenes/ant_follower.tscn", "res://ant_follower.tscn"])

	if item_scene == null:
		item_scene = _try_load_scene(["res://scenes/scavenge_item.tscn", "res://scenes/item.tscn", "res://scavenge_item.tscn", "res://item.tscn"])

	if foot_scene == null:
		foot_scene = _try_load_scene(["res://scenes/hazard_foot.tscn", "res://hazard_foot.tscn"])

	if hand_scene == null:
		hand_scene = _try_load_scene(["res://scenes/hazard_hand.tscn", "res://hazard_hand.tscn"])

func _try_load_scene(paths: Array[String]) -> PackedScene:
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p) as PackedScene
	return null

func _unhandled_input(event: InputEvent) -> void:
	if (is_game_over or game_finished) and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reload_game()

func _on_fog_started_closing() -> void:
	if not is_game_over and not game_finished:
		var audio := AudioManager.get_instance(get_tree())
		if audio != null:
			audio.play_map_blown_off()
		_show_hud_alert("THE FOG IS CLOSING IN! Gather the quota & advance to the Ant Den now!", 4.5)

func _on_leader_died(reason: String) -> void:
	if is_game_over or game_finished:
		return
	is_game_over = true
	if closing_fog != null and closing_fog.has_method("stop"):
		closing_fog.stop()

	var audio := AudioManager.get_instance(get_tree())
	if audio != null:
		audio.set_bgm_dimmed(true)

	await get_tree().create_timer(0.55).timeout
	if is_inside_tree():
		_show_reload_screen("SQUAD FALLEN", reason, false)

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

	if round_num > 1:
		for f in get_tree().get_nodes_in_group("followers"):
			if is_instance_valid(f) and f.get("line_target") == null:
				f.queue_free()
		for item in get_tree().get_nodes_in_group("items"):
			if is_instance_valid(item):
				item.queue_free()

	if leader != null and idx >= 0 and idx < round_start_markers.size():
		var marker := round_start_markers[idx]
		if marker != null:
			leader.teleport_squad(marker.global_position)

	_activate_round_borders()
	_start_round_fog(round_num)

	_refill_cells(available_follower_cells)
	_refill_cells(available_item_cells)
	_populate_initial_round_items.call_deferred()
	_refresh_hud()

func _start_round_fog(round_num: int) -> void:
	if closing_fog == null or not closing_fog.has_method("start_round"):
		return

	var idx := round_num - 1
	var zone_min_x := float(idx) * 8000.0
	var zone_max_x := float(round_num) * 8000.0
	var zone_min_y := -8000.0
	var zone_max_y := 1000.0

	if idx > 0 and (idx - 1) < forward_borders.size() and forward_borders[idx - 1] != null:
		zone_min_x = forward_borders[idx - 1].global_position.x
	if idx < forward_borders.size() and forward_borders[idx] != null:
		zone_max_x = forward_borders[idx].global_position.x

	var fog_dir := "bottom" if round_num == 1 else "left"
	closing_fog.start_round(zone_min_x, zone_max_x, zone_min_y, zone_max_y, round_num, fog_dir)

func _populate_initial_round_items() -> void:
	var target_count := mini(initial_round_items, max_items_on_map)
	for i in range(target_count):
		_on_item_spawn_timer_timeout()

func _activate_round_borders() -> void:
	for border in forward_borders:
		if border == null:
			continue
		border.visible = true
		if border.collision_layer == 0:
			border.collision_layer = 1
		for child in border.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)

func _on_den_reached(den: Area2D, leader_body: Node2D) -> void:
	if game_finished or is_game_over:
		return

	var current_food: int = leader_body.get_total_food()
	var current_water: int = leader_body.get_total_water()
	var req_food: int = den.get("required_food")
	var req_water: int = den.get("required_water")

	if current_food < req_food or current_water < req_water:
		_show_hud_alert("Quota not met! Need %d Food & %d Water." % [req_food, req_water], 3.5)
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

	var audio := AudioManager.get_instance(get_tree())
	if audio != null:
		audio.play_badge()
		audio.set_walking(false)

	VFX.spawn_celebration(self, den.global_position)

	if current_round < ant_dens.size():
		var upgrade_msg := ""
		if leader_body.has_method("apply_random_upgrade"):
			upgrade_msg = leader_body.apply_random_upgrade()

		_setup_round(current_round + 1)
		_show_hud_alert("ROUND %d COMPLETE! (+%d Points)\nRandom Upgrade: %s" % [current_round - 1, earned_points, upgrade_msg], 5.0)
	else:
		game_finished = true
		if closing_fog != null and closing_fog.has_method("stop"):
			closing_fog.stop()
		den.set_den_state(false, true)
		_show_reload_screen("MISSION COMPLETE!", "All Ant Dens have been supplied!", true)

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

func _get_effective_spawn_bounds() -> Rect2:
	if closing_fog != null and closing_fog.has_method("get_safe_spawn_rect"):
		return closing_fog.get_safe_spawn_rect(spawn_area_min, spawn_area_max, 350.0)
	return Rect2(spawn_area_min, spawn_area_max - spawn_area_min)

func _is_blocked_by_obstacle(pos: Vector2, radius: float = 70.0) -> bool:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return false

	var shape := CircleShape2D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if leader is CollisionObject2D:
		query.exclude = [(leader as CollisionObject2D).get_rid()]

	return not space_state.intersect_shape(query, 1).is_empty()

func _on_spawn_timer_timeout() -> void:
	if follower_scene == null or game_finished or is_game_over:
		return

	var current_count := get_tree().get_nodes_in_group("followers").size()
	var max_limit: int = leader.get("max_followers") if (leader != null and leader.get("max_followers") != null) else 5
	if current_count >= max_limit:
		return

	var spawn_pos := _get_follower_spawn_position()
	if spawn_pos == Vector2.INF:
		return

	var wild_follower := follower_scene.instantiate() as Node2D
	wild_follower.global_position = spawn_pos
	add_child(wild_follower)

func _on_item_spawn_timer_timeout() -> void:
	if item_scene == null or game_finished or is_game_over:
		return

	var current_items := get_tree().get_nodes_in_group("items").size()
	if current_items >= max_items_on_map:
		return

	var spawn_pos := _get_spaced_item_position()
	if spawn_pos == Vector2.INF:
		return

	var item_data := _pick_random_item_data().duplicate()
	item_data["texture"] = _get_item_texture(item_data["name"])

	var new_item := item_scene.instantiate() as Area2D
	new_item.global_position = spawn_pos
	if new_item.has_method("apply_data"):
		new_item.apply_data(item_data)
	add_child(new_item)

func _get_item_texture(item_name: String) -> Texture2D:
	match item_name:
		"Bread Crumb":
			return tex_bread_crumb
		"Water Droplet":
			return tex_water_droplet
		"Fruit Piece":
			return tex_fruit_piece
		"Sugar Cube":
			return tex_sugar_cube
		"Meat":
			var valid_meats: Array[Texture2D] = []
			for t in tex_meat_variants:
				if t != null:
					valid_meats.append(t)
			if not valid_meats.is_empty():
				return valid_meats.pick_random()
	return null

func _count_item_in_play(item_name: String) -> int:
	var count := 0
	for item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(item) and item.get("item_name") == item_name:
			count += 1

	if leader != null:
		var carried = leader.get("carried_items")
		if carried != null:
			for c in carried:
				if c["name"] == item_name:
					count += 1
	return count

func _pick_random_item_data() -> Dictionary:
	var pool: Array[Dictionary] = []
	var total_weight := 0
	for entry in ITEM_CATALOG:
		if entry.has("max_on_map") and _count_item_in_play(entry["name"]) >= entry["max_on_map"]:
			continue
		pool.append(entry)
		total_weight += entry["spawn_weight"]

	if pool.is_empty():
		return ITEM_CATALOG[0]

	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for entry in pool:
		cumulative += entry["spawn_weight"]
		if roll <= cumulative:
			return entry

	return pool[0]

func _get_follower_spawn_position() -> Vector2:
	var bounds := _get_effective_spawn_bounds()
	if bounds.size.x < 350.0 or bounds.size.y < 350.0:
		return Vector2.INF

	var eff_min := bounds.position
	var eff_max := bounds.end
	var cell_size := Vector2(
		bounds.size.x / float(grid_columns),
		bounds.size.y / float(grid_rows)
	)
	var padding := cell_size * 0.15

	for attempt in range(grid_columns * grid_rows):
		if available_follower_cells.is_empty():
			_refill_cells(available_follower_cells)

		var cell: Vector2i = available_follower_cells.pop_front()
		var cell_min := eff_min + Vector2(cell.x * cell_size.x, cell.y * cell_size.y) + padding
		var cell_max := cell_min + cell_size - (padding * 2.0)

		var candidate_pos := Vector2(
			randf_range(cell_min.x, cell_max.x),
			randf_range(cell_min.y, cell_max.y)
		)

		if not _is_blocked_by_obstacle(candidate_pos, 65.0) and (leader == null or candidate_pos.distance_to(leader.global_position) >= min_distance_from_leader):
			return candidate_pos

	for i in range(25):
		var random_pos := Vector2(
			randf_range(eff_min.x, eff_max.x),
			randf_range(eff_min.y, eff_max.y)
		)
		if not _is_blocked_by_obstacle(random_pos, 65.0) and (leader == null or random_pos.distance_to(leader.global_position) >= min_distance_from_leader):
			return random_pos

	return Vector2.INF

func _get_spaced_item_position() -> Vector2:
	var bounds := _get_effective_spawn_bounds()
	if bounds.size.x < 450.0 or bounds.size.y < 450.0:
		return Vector2.INF

	var eff_min := bounds.position
	var eff_max := bounds.end
	var cell_size := Vector2(
		bounds.size.x / float(grid_columns),
		bounds.size.y / float(grid_rows)
	)
	var padding := cell_size * 0.2

	for attempt in range(grid_columns * grid_rows):
		if available_item_cells.is_empty():
			_refill_cells(available_item_cells)

		var cell: Vector2i = available_item_cells.pop_front()
		var cell_min := eff_min + Vector2(cell.x * cell_size.x, cell.y * cell_size.y) + padding
		var cell_max := cell_min + cell_size - (padding * 2.0)

		var candidate_pos := Vector2(
			randf_range(cell_min.x, cell_max.x),
			randf_range(cell_min.y, cell_max.y)
		)

		if _is_valid_item_position(candidate_pos):
			return candidate_pos

	for i in range(30):
		var random_pos := Vector2(
			randf_range(eff_min.x, eff_max.x),
			randf_range(eff_min.y, eff_max.y)
		)
		if _is_valid_item_position(random_pos):
			return random_pos

	return Vector2.INF

func _is_valid_item_position(pos: Vector2) -> bool:
	if _is_blocked_by_obstacle(pos, 75.0):
		return false

	if closing_fog != null and closing_fog.has_method("is_in_fog") and closing_fog.is_in_fog(pos, 250.0):
		return false

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
		"ROUND %d / %d  |  Points: %d\n" % [current_round, ant_dens.size(), total_points] +
		"Follower Ants: %d / %d\n" % [ui_followers, ui_max_followers] +
		"Capacity: %d / %d CC%s\n" % [ui_weight, ui_max_capacity, warning] +
		"Food: %d / %d  |  Water: %d / %d%s" % [ui_food, food_quota, ui_water, water_quota, alert_line]
	)

func _start_hazard_loop() -> void:
	await get_tree().create_timer(initial_hazard_delay).timeout
	while is_inside_tree() and not game_finished and not is_game_over:
		_spawn_foot()
		var idx := current_round - 1
		var wait := hazard_interval_fallback
		if idx >= 0 and idx < round_hazard_intervals.size():
			wait = round_hazard_intervals[idx]
		elif not round_hazard_intervals.is_empty():
			wait = round_hazard_intervals.back()
		await get_tree().create_timer(maxf(2.0, wait)).timeout

func _spawn_foot() -> void:
	if foot_scene == null or leader == null or leader.get("is_dead") == true:
		return

	var foot_pos := _get_foot_position()
	if foot_pos == Vector2.INF:
		return

	var foot := foot_scene.instantiate() as Node2D
	foot.add_to_group("hazards")
	foot.leader = leader

	var valid_feet: Array[Texture2D] = []
	for t in foot_textures:
		if t != null:
			valid_feet.append(t)
	if not valid_feet.is_empty():
		foot.set("foot_textures", valid_feet)
		foot.set("foot_texture", valid_feet[0])

	foot.global_position = foot_pos
	add_child(foot)

func _start_hand_loop() -> void:
	await get_tree().create_timer(initial_hand_delay).timeout
	while is_inside_tree() and not game_finished and not is_game_over:
		_spawn_hand()
		var idx := current_round - 1
		var wait := hand_interval_fallback
		if idx >= 0 and idx < round_hand_intervals.size():
			wait = round_hand_intervals[idx]
		elif not round_hand_intervals.is_empty():
			wait = round_hand_intervals.back()
		await get_tree().create_timer(maxf(3.0, wait)).timeout

func _spawn_hand() -> void:
	if hand_scene == null or leader == null or leader.get("is_dead") == true:
		return

	var hand_pos := _get_hand_position()
	if hand_pos == Vector2.INF:
		return

	var hand := hand_scene.instantiate() as Node2D
	hand.add_to_group("hazards")
	hand.leader = leader
	if charge_hand_texture != null:
		hand.set("charge_hand_texture", charge_hand_texture)
	if sweep_hand_texture != null:
		hand.set("sweep_hand_texture", sweep_hand_texture)
	hand.global_position = hand_pos
	add_child(hand)

func _get_hand_position() -> Vector2:
	var ant_targets: Array[Vector2] = []
	if not _is_invalid_hazard_pos(leader.global_position):
		ant_targets.append(leader.global_position)

	var squad: Array = leader.get("followers")
	for f in squad:
		if is_instance_valid(f) and not _is_invalid_hazard_pos(f.global_position):
			ant_targets.append(f.global_position)

	var item_targets: Array[Vector2] = []
	for item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(item) and not _is_invalid_hazard_pos(item.global_position):
			if item.global_position.distance_to(leader.global_position) <= hazard_spawn_range:
				item_targets.append(item.global_position)

	if randf() < target_ants_chance and not ant_targets.is_empty():
		var ant_pos := _pick_hand_offset(ant_targets)
		if ant_pos != Vector2.INF:
			return ant_pos

	if not item_targets.is_empty():
		var item_pos := _pick_hand_offset(item_targets)
		if item_pos != Vector2.INF:
			return item_pos

	if not ant_targets.is_empty():
		return _pick_hand_offset(ant_targets)

	return Vector2.INF

func _pick_hand_offset(bases: Array[Vector2]) -> Vector2:
	for i in range(12):
		var base: Vector2 = bases.pick_random()
		var pos := base + Vector2(randf_range(-140.0, 140.0), randf_range(-55.0, 55.0))
		if not _is_invalid_hazard_pos(pos):
			return pos
	return Vector2.INF

func _is_invalid_hazard_pos(pos: Vector2) -> bool:
	if closing_fog != null and closing_fog.has_method("is_in_fog") and closing_fog.is_in_fog(pos, 100.0):
		return true

	for h in get_tree().get_nodes_in_group("hazards"):
		if is_instance_valid(h) and pos.distance_to(h.global_position) < min_distance_between_hazards:
			return true

	return false

func _get_foot_position() -> Vector2:
	var ant_targets: Array[Vector2] = []
	if not _is_invalid_hazard_pos(leader.global_position):
		ant_targets.append(leader.global_position)

	var squad: Array = leader.get("followers")
	for f in squad:
		if is_instance_valid(f) and not _is_invalid_hazard_pos(f.global_position):
			ant_targets.append(f.global_position)

	var item_targets: Array[Vector2] = []
	for item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(item) and not _is_invalid_hazard_pos(item.global_position):
			if item.global_position.distance_to(leader.global_position) <= hazard_spawn_range:
				item_targets.append(item.global_position)

	var target_ants := randf() < target_ants_chance
	if target_ants and not ant_targets.is_empty():
		var pos := _pick_offset_position(ant_targets, 85.0)
		if pos != Vector2.INF:
			return pos

	if not item_targets.is_empty():
		var pos := _pick_offset_position(item_targets, 110.0)
		if pos != Vector2.INF:
			return pos

	if not ant_targets.is_empty():
		return _pick_offset_position(ant_targets, 85.0)

	return Vector2.INF

func _pick_offset_position(bases: Array[Vector2], max_offset: float) -> Vector2:
	for i in range(15):
		var base: Vector2 = bases.pick_random()
		var candidate := base + Vector2(randf_range(-max_offset, max_offset), randf_range(-max_offset, max_offset))
		if not _is_invalid_hazard_pos(candidate):
			return candidate
	return Vector2.INF
