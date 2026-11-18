extends Node2D

@export var follower_scene: PackedScene
@export var spawn_interval: float = 10.0
@export var max_total_followers: int = 10
@export var spawn_area_min: Vector2 = Vector2(100, 100)
@export var spawn_area_max: Vector2 = Vector2(1050, 550)

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(timer)

func _on_spawn_timer_timeout() -> void:
	if follower_scene == null:
		return

	var current_count := get_tree().get_nodes_in_group("followers").size()
	if current_count >= max_total_followers:
		return

	var wild_follower := follower_scene.instantiate() as Node2D
	wild_follower.global_position = Vector2(
		randf_range(spawn_area_min.x, spawn_area_max.x),
		randf_range(spawn_area_min.y, spawn_area_max.y)
	)
	add_child(wild_follower)
