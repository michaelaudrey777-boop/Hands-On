extends Node
## Autoload "JuiceInstaller"

const WalkJuice := preload("res://scripts/walk_juice.gd")
const ItemJuice := preload("res://scripts/item_juice.gd")
const AmbientDust := preload("res://scripts/ambient_dust.gd")

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred(get_tree().root)

func _scan(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_scan(c)

func _on_node_added(node: Node) -> void:
	if node.has_meta("juiced"):
		return
	if node.has_method("recruit_follower") or node.has_method("set_target"):
		node.set_meta("juiced", true)
		_attach.call_deferred(node, WalkJuice, "WalkJuice")
	elif node.has_method("apply_data"):
		node.set_meta("juiced", true)
		_attach.call_deferred(node, ItemJuice, "ItemJuice")
	elif node is Camera2D:
		node.set_meta("juiced", true)
		_attach.call_deferred(node, AmbientDust, "AmbientDust")

func _attach(node: Node, script: Script, node_name: String) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var juice := Node.new()
	juice.name = node_name
	juice.set_script(script)
	node.add_child(juice)
