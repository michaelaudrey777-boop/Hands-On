extends Area2D

@export var item_name: String = "Bread Crumb"
@export var weight: int = 1
@export var food_value: int = 1
@export var water_value: int = 0
@export var score_value: int = 3
@export var item_color: Color = Color(0.95, 0.75, 0.35)

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = get_node_or_null("PromptLabel")

func _ready() -> void:
	add_to_group("items")
	sprite.modulate = item_color
	if prompt_label != null:
		prompt_label.text = "[E] %s (%d CC)" % [item_name, weight]
		prompt_label.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func apply_data(data: Dictionary) -> void:
	item_name = data.get("name", item_name)
	weight = data.get("weight", weight)
	food_value = data.get("food", food_value)
	water_value = data.get("water", water_value)
	score_value = data.get("score", score_value)
	item_color = data.get("color", item_color)
	if is_node_ready():
		sprite.modulate = item_color
		if prompt_label != null:
			prompt_label.text = "[E] %s (%d CC)" % [item_name, weight]

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("register_nearby_item"):
		body.register_nearby_item(self)
		if prompt_label != null:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("unregister_nearby_item"):
		body.unregister_nearby_item(self)
		if prompt_label != null:
			prompt_label.visible = false
