extends Area2D

@export var item_name: String = "Bread Crumb"
@export var weight: int = 1
@export var food_value: int = 2
@export var water_value: int = 0
@export var score_value: int = 3
@export var item_color: Color = Color(0.95, 0.75, 0.35)
@export var item_texture: Texture2D = null
@export var size_multiplier: float = 1.0

@export_group("Sprite Shadow")
@export var shadow_enabled: bool = true
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.45)
@export var shadow_offset: Vector2 = Vector2(6.0, 14.0)
@export var shadow_scale: Vector2 = Vector2(1.0, 0.92)

@export_group("Pickup Indicator")
@export var prompt_font_size: int = 62
@export var prompt_extra_height: float = 28.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var base_sprite_scale: Vector2 = Vector2.ONE
var base_sprite_pos: Vector2 = Vector2.ZERO
var base_z_index: int = 0
var bob_time: float = 0.0
var nearby_leader: Node2D = null
var is_closest_target: bool = false

func _ready() -> void:
	add_to_group("items")
	bob_time = randf() * TAU
	base_z_index = z_index

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

	is_closest_target = _check_if_closest_to_leader()
	z_index = (base_z_index + 20) if is_closest_target else base_z_index
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

func _get_visual_half_extents() -> Vector2:
	var fallback := 22.0 * size_multiplier
	if sprite != null and sprite.texture != null:
		var tex_size := sprite.texture.get_size()
		return Vector2(
			maxf(fallback, (tex_size.x * absf(sprite.scale.x)) * 0.5),
			maxf(fallback, (tex_size.y * absf(sprite.scale.y)) * 0.5)
		)
	return Vector2(fallback, fallback)

func _draw() -> void:
	var r := 22.0 * size_multiplier
	var half_ext := _get_visual_half_extents()
	var bob_factor := 1.0 - sin(bob_time) * 0.04

	draw_circle(Vector2(0, 6), maxf(r * 1.45, half_ext.x * 1.15), Color(item_color.r, item_color.g, item_color.b, 0.14))

	if shadow_enabled:
		if sprite != null and sprite.texture != null:
			var tex := sprite.texture
			var draw_size := tex.get_size() * Vector2(absf(sprite.scale.x), absf(sprite.scale.y))
			var flip_x := -1.0 if sprite.flip_h else 1.0
			var flip_y := -1.0 if sprite.flip_v else 1.0
			var final_scale := Vector2(
				flip_x * shadow_scale.x * bob_factor,
				flip_y * shadow_scale.y * bob_factor
			)
			var shadow_pos := base_sprite_pos + shadow_offset
			var rect_pos := (-draw_size * 0.5) + sprite.offset

			draw_set_transform(shadow_pos, sprite.rotation, final_scale)
			draw_texture_rect(tex, Rect2(rect_pos, draw_size), false, shadow_color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(shadow_offset, r * 0.85 * bob_factor, shadow_color)

	if sprite == null or sprite.texture == null:
		draw_circle(Vector2.ZERO, r * 0.85, item_color)

	if is_closest_target and nearby_leader != null:
		var overweight: bool = nearby_leader.has_method("is_overweight") and nearby_leader.is_overweight()
		var ring_color := Color(1.0, 0.32, 0.32, 0.95) if overweight else Color(1.0, 0.88, 0.35, 0.95)
		var ring_radius := maxf(r * 1.65, maxf(half_ext.x, half_ext.y) * 1.25)
		draw_arc(Vector2(0, 4), ring_radius, 0.0, TAU, 40, ring_color, 4.0, true)

		var font := ThemeDB.fallback_font
		if font != null:
			var label_text := "[FULL]" if overweight else "[E]"
			var pulse := 1.0 + sin(bob_time * 2.2) * 0.06
			var font_size := int(round(float(prompt_font_size) * pulse))

			var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var ascent := font.get_ascent(font_size)
			var descent := font.get_descent(font_size)
			var total_h := ascent + descent

			var pad_x := 18.0
			var pad_y := 10.0
			var box_w := text_size.x + pad_x * 2.0
			var box_h := total_h + pad_y * 2.0

			var box_bottom_y := -half_ext.y - prompt_extra_height + sin(bob_time * 2.2) * 3.0
			var bg_rect := Rect2(
				-box_w * 0.5,
				box_bottom_y - box_h,
				box_w,
				box_h
			)

			draw_rect(bg_rect, Color(0.08, 0.05, 0.04, 0.90), true)
			draw_rect(bg_rect, ring_color, false, 3.5)

			var text_pos := Vector2(-text_size.x * 0.5, bg_rect.position.y + pad_y + ascent)
			draw_string_outline(
				font,
				text_pos,
				label_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				6,
				Color(0.0, 0.0, 0.0, 0.95)
			)
			draw_string(
				font,
				text_pos,
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
		z_index = base_z_index
		queue_redraw()
