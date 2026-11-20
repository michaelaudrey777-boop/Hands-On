extends Area2D

signal den_reached(den: Area2D, leader: Node2D)

@export var den_name: String = "Ant Den 1"
@export var required_food: int = 32
@export var required_water: int = 21

@onready var sprite: Sprite2D = $Sprite2D
@onready var info_label: Label = get_node_or_null("InfoLabel")

var is_active: bool = false
var is_completed: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visuals()

func set_den_state(active: bool, completed: bool) -> void:
	is_active = active
	is_completed = completed
	set_deferred("monitoring", active and not completed)
	_update_visuals()

func _update_visuals() -> void:
	if not is_node_ready():
		return

	if is_completed:
		sprite.modulate = Color(0.4, 0.4, 0.4, 0.6)
		if info_label != null:
			info_label.text = "%s [SELESAI]" % den_name
	elif is_active:
		sprite.modulate = Color(0.3, 0.9, 0.4, 1.0)
		if info_label != null:
			info_label.text = "%s [TUJUAN]\nKuota: %d Food | %d Water" % [den_name, required_food, required_water]
	else:
		sprite.modulate = Color(0.8, 0.3, 0.3, 0.5)
		if info_label != null:
			info_label.text = "%s [TERKUNCI]" % den_name

func _on_body_entered(body: Node2D) -> void:
	if not is_active or is_completed:
		return

	if body.has_method("deposit_all_items"):
		den_reached.emit(self, body)
