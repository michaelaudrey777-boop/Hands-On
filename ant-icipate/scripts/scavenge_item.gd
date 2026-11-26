extends Area2D

@export var item_name: String = "Bread Crumb"
@export var weight: int = 1
@export var food_value: int = 2
@export var water_value: int = 0
@export var score_value: int = 3
@export var item_color: Color = Color(0.95, 0.75, 0.35)
@export var item_texture: Texture2D = null
@export var size_multiplier: float = 1.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var base_sprite_scale: Vector2 = Vector2.ONE
var base_sprite_pos: Vector2 = Vector2.ZERO
var bob_time: float = 0.0
var nearby_leader: Node2D = null
var is_closest_target: bool = false

func _ready() -> void:
	add_to_group("items")
	bob_time = randf() * TAU

	if sprite != null:
		base_sprite_scale = sprite.scale
		base_sprite_pos = sprite.position

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_visuals()

func apply_data(data: Dictionary) -> void:
	item_name = data.get("name", item_name)
	weight = data.get("weight", weight)
	food_value = data.get("food", food_value)
	water_value = data.get("water", water_value)
	score_value = data.get("score", score_value)
	item_color = data.get("color", item_color)
	item_texture = data.get("texture", item_texture)
	size_multiplier = data.get("size_multiplier", size_multiplier)

	if is_node_ready():
		_apply_visuals()

func _apply_visuals() -> void:
	if sprite != null:
		sprite.scale = base_sprite_scale * size_multiplier
		if item_texture != null:
			sprite.texture = item_texture
			sprite.modulate = Color(1.03, 0.98, 0.92, 1.0)
		else:
			sprite.modulate = item_color
	queue_redraw()

func _process(delta: float) -> void:
	bob_time += delta * 3.2
	if sprite != null:
		sprite.position.y = base_sprite_pos.y + sin(bob_time) * 3.0

	var was_closest := is_closest_target
	is_closest_target = _check_if_closest_to_leader()

	if is_closest_target or was_closest:
		queue_redraw()

func _check_if_closest_to_leader() -> bool:
	if nearby_leader == null or not is_instance_valid(nearby_leader):
		nearby_leader = null
		return false

	var items = nearby_leader.get("nearby_items")
	if items == null or items.is_empty():
		return false

	var closest: Area2D = null
	var min_dist := INF
	for item in items:
		if is_instance_valid(item):
			var d := nearby_leader.global_position.distance_to(item.global_position)
			if d < min_dist:
				min_dist = d
				closest = item

	return closest == self

func _draw() -> void:
	var r := 22.0 * size_multiplier

	draw_circle(Vector2(0, 6), r * 1.45, Color(item_color.r, item_color.g, item_color.b, 0.16))

	draw_set_transform(Vector2(6.0, 15.0), 0.0, Vector2(1.15, 0.55))
	draw_circle(Vector2.ZERO, r * 0.95, Color(0.14, 0.08, 0.06, 0.46))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if sprite == null or sprite.texture == null:
		draw_circle(Vector2.ZERO, r * 0.85, item_color)

	if is_closest_target and nearby_leader != null:
		var overweight: bool = nearby_leader.has_method("is_overweight") and nearby_leader.is_overweight()
		var ring_color := Color(1.0, 0.32, 0.32, 0.9) if overweight else Color(1.0, 0.88, 0.35, 0.9)
		draw_arc(Vector2(0, 4), r * 1.55, 0.0, TAU, 32, ring_color, 3.0, true)

		var font := ThemeDB.fallback_font
		if font != null:
			var label_text := "[FULL]" if overweight else "[E]"
			var font_size := 15
			var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var badge_pos := Vector2(0.0, -r - 24.0)
			var bg_rect := Rect2(
				badge_pos.x - text_size.x * 0.5 - 8.0,
				badge_pos.y - text_size.y + 2.0,
				text_size.x + 16.0,
				text_size.y + 6.0
			)
			draw_rect(bg_rect, Color(0.10, 0.07, 0.05, 0.82), true)
			draw_rect(bg_rect, ring_color, false, 1.5)
			draw_string(
				font,
				Vector2(badge_pos.x - text_size.x * 0.5, badge_pos.y),
				label_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color.WHITE
			)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("register_nearby_item"):
		body.register_nearby_item(self)
		nearby_leader = body

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("unregister_nearby_item"):
		body.unregister_nearby_item(self)
	if body == nearby_leader:
		nearby_leader = null
		is_closest_target = false
		queue_redraw()
