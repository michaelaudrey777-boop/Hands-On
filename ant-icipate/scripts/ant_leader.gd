extends CharacterBody2D

@export var speed: float = 400.0
@export var acceleration: float = 2000.0
@export var friction: float = 2500.0
@export var turn_speed: float = 12.0

@export_group("Follower Settings")
@export var follower_scene: PackedScene
@export var starting_followers: int = 3
@export var max_followers: int = 10

@export var shadow_offset: Vector2 = Vector2(8,12)
@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow

var followers: Array[Node2D] = []

func _ready() -> void:
	spawn_initial_followers()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("Left", "Right", "Up", "Down")
	var rate := acceleration if input else friction
	velocity = velocity.move_toward(input * speed, rate * delta)

	if velocity.length() > 10.0:
		rotation = lerp_angle(rotation, velocity.angle(), turn_speed * delta)

	shadow.global_position = sprite.global_position + shadow_offset

	move_and_slide()

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
	follower.set_target(target_node)
