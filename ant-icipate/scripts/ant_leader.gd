extends CharacterBody2D

@export var speed: float = 400.0
@export var acceleration: float = 2000.0
@export var friction: float = 2500.0

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("Left", "Right", "Up", "Down")
	var rate := acceleration if input else friction
	velocity = velocity.move_toward(input * speed, rate * delta)
	move_and_slide()
