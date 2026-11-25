extends Area2D

@export var item_name: String = "Bread Crumb"
@export var weight: int = 1
@export var food_value: int = 1
@export var water_value: int = 0
@export var score_value: int = 3
@export var item_color: Color = Color(0.95, 0.75, 0.35)
@export var item_texture: Texture2D = null

@export_group("Visual & Shadow")
@export var target_visual_size: float = 92.0
@export var size_multiplier: float = 1.0
@export var shadow_offset: Vector2 = Vector2(5, 8)
@export var shadow_color: Color = Color(0, 0, 0, 0.35)

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = get_node_or_null("Shadow")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")

func _ready() -> void:
	add_to_group("items")
	_update_visuals()
	if prompt_label != null:
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
	item_texture = data.get("texture", item_texture)
	size_multiplier = data.get("size_multiplier", 1.0)
	_update_visuals()

func _update_visuals() -> void:
	if not is_node_ready():
		return

	if item_texture != null:
		sprite.texture = item_texture
		sprite.modulate = Color.WHITE
		var tex_size := item_texture.get_size()
		var max_dim := maxf(tex_size.x, tex_size.y)
		if max_dim > 0.0:
			var s := (target_visual_size * size_multiplier) / max_dim
			sprite.scale = Vector2(s, s)
	else:
		sprite.modulate = item_color

	if shadow != null:
		shadow.texture = sprite.texture
		shadow.scale = sprite.scale
		shadow.modulate = shadow_color
		shadow.position = sprite.position + shadow_offset

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
