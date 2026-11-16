extends CharacterBody2D

@export var speed: float = 400.0

func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("Left", "Right", "Up", "Down")
	#if input_vector != Vector2.ZERO:
		#print("Karakter sedang bergerak ke arah: ", input_vector)
	#else:
		#print("Karakter diam (Idle)")
	velocity = input_vector * speed
	move_and_slide()
