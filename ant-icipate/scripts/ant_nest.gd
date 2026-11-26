extends Area2D

signal den_reached(den: Area2D, leader: Node2D)

@export var den_name: String = "Ant Den 1"
@export var required_food: int = 32
@export var required_water: int = 21
@export var den_radius: float = 115.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var info_label: Label = get_node_or_null("InfoLabel")

var is_active: bool = false
var is_completed: bool = false
var pulse_time: float = 0.0
var leader_ref: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	leader_ref = get_tree().current_scene.find_child("AntLeader", true, false) as Node2D
	_update_visuals()

func set_den_state(active: bool, completed: bool) -> void:
	is_active = active
	is_completed = completed
	set_deferred("monitoring", active and not completed)
	_update_visuals()
	queue_redraw()

func _process(delta: float) -> void:
	if is_active and not is_completed:
		pulse_time += delta * 2.5
		queue_redraw()

func _is_quota_ready() -> bool:
	if leader_ref == null or not is_instance_valid(leader_ref):
		return false
	if not leader_ref.has_method("get_total_food") or not leader_ref.has_method("get_total_water"):
		return false
	return leader_ref.get_total_food() >= required_food and leader_ref.get_total_water() >= required_water

func _update_visuals() -> void:
	if not is_node_ready():
		return

	if is_completed:
		sprite.modulate = Color(0.75, 0.85, 0.75, 0.85)
		if info_label != null:
			info_label.text = "%s [COMPLETED]" % den_name
	elif is_active:
		sprite.modulate = Color(1.03, 0.97, 0.91, 1.0)
		if info_label != null:
			info_label.text = "%s [TARGET]\nQuota: %d Food | %d Water" % [den_name, required_food, required_water]
	else:
		sprite.modulate = Color(0.55, 0.52, 0.50, 0.72)
		if info_label != null:
			info_label.text = "%s [LOCKED]" % den_name

func _draw() -> void:
	draw_set_transform(Vector2(10.0, 22.0), 0.0, Vector2(1.2, 0.55))
	draw_circle(Vector2.ZERO, den_radius, Color(0.14, 0.08, 0.06, 0.52))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_active and not is_completed:
		var ready := _is_quota_ready()
		var pulse := (sin(pulse_time) + 1.0) * 0.5
		var ring_radius := den_radius + 10.0 + pulse * 10.0
		var ring_color := Color(0.32, 1.0, 0.45, 0.60 + pulse * 0.30) if ready else Color(1.0, 0.82, 0.25, 0.45 + pulse * 0.25)

		draw_circle(Vector2.ZERO, ring_radius, Color(ring_color.r, ring_color.g, ring_color.b, 0.10))
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, ring_color, 4.0, true)
	elif is_completed:
		draw_arc(Vector2.ZERO, den_radius + 6.0, 0.0, TAU, 48, Color(0.45, 0.85, 0.50, 0.35), 3.0, true)

func _on_body_entered(body: Node2D) -> void:
	if not is_active or is_completed:
		return

	if body.has_method("deposit_all_items"):
		den_reached.emit(self, body)
