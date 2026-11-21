extends CharacterBody2D

signal inventory_updated(current_weight: int, max_capacity: int, food: int, water: int, is_overweight: bool)
signal squad_updated(current_followers: int, max_followers: int)

@export var speed: float = 400.0
@export var acceleration: float = 2000.0
@export var friction: float = 2500.0
@export var turn_speed: float = 12.0
@export var turn_acceleration: float = 6000.0
@export var huddle_speed_multiplier: float = 0.5
@export var shadow_offset: Vector2 = Vector2(5, 8)

@export_group("Follower Settings")
@export var follower_scene: PackedScene
@export var starting_followers: int = 3
@export var max_followers: int = 5

@export_group("Carry Capacity Settings")
@export var item_scene: PackedScene
@export var capacity_per_ant: int = 8
@export var include_leader_in_capacity: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow

var followers: Array[Node2D] = []
var is_huddling: bool = false
var carried_items: Array[Dictionary] = []
var nearby_items: Array[Area2D] = []
var facing: Vector2 = Vector2.RIGHT

func _ready() -> void:
	spawn_initial_followers()
	_emit_status.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			try_pickup_item()
		elif event.keycode == KEY_Q:
			drop_last_item()
		elif event.keycode == KEY_K and OS.is_debug_build():
			if not followers.is_empty():
				remove_follower(followers.back())

func _physics_process(delta: float) -> void:
	is_huddling = Input.is_key_pressed(KEY_SPACE)

	var input := Input.get_vector("Left", "Right", "Up", "Down")
	var rate := acceleration if input else friction
	if input and velocity.dot(input) < 0.0:
		rate = turn_acceleration  # braking against the current direction: brake hard

	var speed_multiplier := 1.0
	if is_huddling:
		speed_multiplier *= huddle_speed_multiplier
	if is_overweight():
		speed_multiplier *= 0.1

	velocity = velocity.move_toward(input * (speed * speed_multiplier), rate * delta)

	if input:
		facing = input.normalized()
		if absf(input.x) > 0.1:
			sprite.flip_h = input.x < 0.0
			shadow.flip_h = sprite.flip_h

	move_and_slide()
	shadow.global_position = sprite.global_position + shadow_offset
	shadow.texture = sprite.texture
	shadow.frame = sprite.frame
	shadow.hframes = sprite.hframes
	shadow.vframes = sprite.vframes

func spawn_initial_followers() -> void:
	if follower_scene == null:
		push_warning("Follower Scene di Inspector AntLeader masih kosong!")
		return

	for i in range(starting_followers):
		var follower := follower_scene.instantiate() as Node2D
		var spacing: float = follower.get("follow_distance") if follower.get("follow_distance") != null else 128.0
		follower.global_position = global_position + Vector2(0, (i + 1) * spacing)
		get_parent().add_child.call_deferred(follower)
		recruit_follower(follower)

func recruit_follower(follower: Node2D) -> void:
	if follower in followers or followers.size() >= max_followers:
		return

	var target_node: Node2D = self if followers.is_empty() else followers.back()
	followers.append(follower)
	follower.set_target(target_node, self)
	_emit_status()

func remove_follower(follower: Node2D) -> void:
	var idx := followers.find(follower)
	if idx == -1:
		return

	var new_target: Node2D = self if idx == 0 else followers[idx - 1]
	followers.remove_at(idx)
	if idx < followers.size():
		followers[idx].set_target(new_target, self)

	if is_instance_valid(follower):
		follower.queue_free()

	drop_heaviest_items_until_fit()

func get_huddle_position(follower: Node2D, radius: float) -> Vector2:
	var index := followers.find(follower)
	var total := followers.size()
	if index == -1 or total == 0:
		return global_position

	var angle := (TAU / float(total)) * float(index)
	return global_position + Vector2.from_angle(angle) * radius

func apply_random_upgrade() -> String:
	var choice := randi() % 3
	var result_text := ""

	match choice:
		0:
			max_followers += 2
			result_text = "+2 Max Ant Follower (Maks: %d)" % max_followers
		1:
			capacity_per_ant += 2
			result_text = "+2 Carry Capacity/Semut (%d CC/semut)" % capacity_per_ant
		2:
			speed += 60.0
			result_text = "+Movement Speed (Speed: %.0f)" % speed

	_emit_status()
	return result_text

func get_max_capacity() -> int:
	var total_ants := followers.size() + (1 if include_leader_in_capacity else 0)
	return total_ants * capacity_per_ant

func get_current_weight() -> int:
	var total := 0
	for item in carried_items:
		total += item["weight"]
	return total

func get_total_food() -> int:
	var total := 0
	for item in carried_items:
		total += item["food"]
	return total

func get_total_water() -> int:
	var total := 0
	for item in carried_items:
		total += item["water"]
	return total

func is_overweight() -> bool:
	return get_current_weight() > get_max_capacity()

func register_nearby_item(item: Area2D) -> void:
	if item not in nearby_items:
		nearby_items.append(item)

func unregister_nearby_item(item: Area2D) -> void:
	nearby_items.erase(item)

func try_pickup_item() -> void:
	nearby_items = nearby_items.filter(func(i): return is_instance_valid(i))
	if nearby_items.is_empty():
		return

	if is_overweight():
		print("Overweight! Tidak bisa mengambil barang lagi.")
		return

	var closest_item: Area2D = nearby_items[0]
	var closest_dist := global_position.distance_to(closest_item.global_position)
	for item in nearby_items:
		var d := global_position.distance_to(item.global_position)
		if d < closest_dist:
			closest_dist = d
			closest_item = item

	var item_data := {
		"name": closest_item.get("item_name"),
		"weight": closest_item.get("weight"),
		"food": closest_item.get("food_value"),
		"water": closest_item.get("water_value"),
		"score": closest_item.get("score_value"),
		"color": closest_item.get("item_color")
	}

	carried_items.append(item_data)
	nearby_items.erase(closest_item)
	closest_item.queue_free()

	_emit_status()

func drop_last_item() -> void:
	if carried_items.is_empty():
		return
	if item_scene == null:
		push_warning("Item Scene di Inspector AntLeader masih kosong!")
		return

	var dropped: Dictionary = carried_items.pop_back()

	var dropped_node := item_scene.instantiate() as Area2D
	dropped_node.global_position = global_position - facing * 80.0
	if dropped_node.has_method("apply_data"):
		dropped_node.apply_data(dropped)
	get_parent().add_child.call_deferred(dropped_node)

	_emit_status()

func deposit_all_items() -> Dictionary:
	var deposited_food := get_total_food()
	var deposited_water := get_total_water()
	var base_score := 0
	for item in carried_items:
		base_score += item["score"]

	carried_items.clear()
	_emit_status()

	return {
		"food": deposited_food,
		"water": deposited_water,
		"base_score": base_score
	}

func drop_heaviest_items_until_fit() -> void:
	while is_overweight() and not carried_items.is_empty():
		carried_items.sort_custom(func(a, b): return a["weight"] > b["weight"])
		var dropped: Dictionary = carried_items.pop_front()

		if item_scene != null:
			var dropped_node := item_scene.instantiate() as Area2D
			dropped_node.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
			if dropped_node.has_method("apply_data"):
				dropped_node.apply_data(dropped)
			get_parent().add_child.call_deferred(dropped_node)

	_emit_status()

func _emit_status() -> void:
	inventory_updated.emit(
		get_current_weight(),
		get_max_capacity(),
		get_total_food(),
		get_total_water(),
		is_overweight()
	)
	squad_updated.emit(followers.size(), max_followers)
