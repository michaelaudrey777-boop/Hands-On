extends Node2D

@export var follower_scene: PackedScene
@export var leader: Node2D
@export var initial_spawn_delay: float = 8.0
@export var spawn_interval: float = 9.0

@export_group("Title Screen")
@export var title_logo_texture: Texture2D
@export var title_bg_texture: Texture2D

@export_group("Custom UI Sprites")
@export var ui_antbar_texture: Texture2D
@export var ui_upgradebar_texture: Texture2D
@export var ui_resources_texture: Texture2D
@export var ui_warningboard_texture: Texture2D
@export var ui_menubg_texture: Texture2D
@export var ui_button_texture: Texture2D
@export var badge_squad_texture: Texture2D
@export var badge_capacity_texture: Texture2D
@export var badge_speed_texture: Texture2D

@export_group("Opening Story Cutscene")
@export var story_slides: Array[Texture2D] = []
@export_multiline var story_captions: Array[String] = [
	"",
	"",
	"",
	"",
	""
]
@export var slide_duration: float = 3.5
@export var allow_skip_story: bool = true

@export_group("Intro Map Cutscene")
@export var intro_map_texture: Texture2D
@export var intro_memorize_duration: float = 6.0
@export var allow_skip_intro: bool = true

@export_group("Round Loop & Ant Dens")
@export var ant_dens: Array[Area2D] = []
@export var round_start_markers: Array[Marker2D] = []
@export var round_max_items: Array[int] = [30, 40, 50]
@export var initial_round_items: int = 18
@export var round_spawn_mins: Array[Vector2] = []
@export var round_spawn_maxs: Array[Vector2] = []

@export_group("Round Borders")
@export var forward_borders: Array[StaticBody2D] = []

@export_group("Item Spawn Settings")
@export var item_scene: PackedScene
@export var initial_item_delay: float = 2.0
@export var item_spawn_interval: float = 4.5
@export var max_items_on_map: int = 30
@export var min_item_distance_from_leader: float = 700.0
@export var min_distance_between_items: float = 650.0

@export_group("Item Sprites")
@export var tex_bread_crumb: Texture2D
@export var tex_water_droplet: Texture2D
@export var tex_fruit_piece: Texture2D
@export var tex_sugar_cube: Texture2D
@export var tex_meat_variants: Array[Texture2D] = []

@export_group("Default Spawn Area & Distribution")
@export var spawn_area_min: Vector2 = Vector2(350, -7650)
@export var spawn_area_max: Vector2 = Vector2(7650, 650)
@export var grid_columns: int = 6
@export var grid_rows: int = 6
@export var min_distance_from_leader: float = 450.0
@export var follower_obstacle_clearance: float = 110.0
@export var item_obstacle_clearance: float = 125.0

@onready var status_label: Label = get_node_or_null("HUD/StatusLabel")
@onready var closing_fog: Node2D = get_node_or_null("ClosingFog")

@export_group("Hazard Foot Settings")
@export var foot_scene: PackedScene
@export var foot_textures: Array[Texture2D] = []
@export var initial_hazard_delay: float = 6.0
@export var round_hazard_intervals: Array[float] = [8.5, 5.5, 3.5]
@export var hazard_interval_fallback: float = 4.0
@export var hazard_spawn_range: float = 2200.0
@export var target_ants_chance: float = 0.55
@export var min_distance_between_hazards: float = 220.0

@export_group("Hazard Hand Settings")
@export var hand_scene: PackedScene
@export var charge_hand_texture: Texture2D
@export var sweep_hand_texture: Texture2D
@export var initial_hand_delay: float = 12.0
@export var round_hand_intervals: Array[float] = [16.0, 12.0, 8.5]
@export var hand_interval_fallback: float = 9.0

const ITEM_CATALOG: Array[Dictionary] = [
	{
		"name": "Bread Crumb",
		"weight": 1,
		"food": 2,
		"water": 0,
		"score": 3,
		"color": Color(0.95, 0.75, 0.35),
		"size_multiplier": 1.0,
		"spawn_weight": 40
	},
	{
		"name": "Water Droplet",
		"weight": 2,
		"food": 0,
		"water": 3,
		"score": 4,
		"color": Color(0.30, 0.75, 1.00),
		"size_multiplier": 1.0,
		"spawn_weight": 35
	},
	{
		"name": "Fruit Piece",
		"weight": 10,
		"food": 16,
		"water": 12,
		"score": 12,
		"color": Color(0.90, 0.25, 0.35),
		"size_multiplier": 1.0,
		"spawn_weight": 15,
		"max_on_map": 8
	},
	{
		"name": "Sugar Cube",
		"weight": 45,
		"food": 60,
		"water": 0,
		"score": 25,
		"color": Color(0.95, 0.95, 1.00),
		"size_multiplier": 1.0,
		"spawn_weight": 6,
		"max_on_map": 2
	},
	{
		"name": "Meat",
		"weight": 60,
		"food": 80,
		"water": 3,
		"score": 35,
		"color": Color(0.75, 0.20, 0.20),
		"size_multiplier": 1.0,
		"spawn_weight": 4,
		"max_on_map": 2
	}
]

var current_round: int = 1
var total_points: int = 0
var food_quota: int = 32
var water_quota: int = 21
var game_finished: bool = false
var is_game_over: bool = false
var is_title_open: bool = false
var is_story_playing: bool = false
var is_intro_playing: bool = false
var is_pause_open: bool = false
var intro_skip_requested: bool = false
var story_next_requested: bool = false
var story_skip_all_requested: bool = false

var ui_followers: int = 3
var ui_max_followers: int = 5
var ui_weight: int = 0
var ui_max_capacity: int = 32
var ui_food: int = 0
var ui_water: int = 0
var ui_overweight: bool = false
var current_upgrade_text: String = "No Upgrade"
var hud_alert_message: String = ""

var available_follower_cells: Array[Vector2i] = []
var available_item_cells: Array[Vector2i] = []

var custom_hud_layer: CanvasLayer = null
var summary_strip_label: Label = null
var ant_bar_label: Label = null
var upgrade_bar_label: Label = null
var upgrade_badge_icon: TextureRect = null
var resource_count_labels: Dictionary = {}

var badge_popup_holder: Control = null
var badge_popup_icon: TextureRect = null
var badge_popup_title: Label = null
var badge_popup_desc: Label = null
var badge_popup_tween: Tween = null

var warning_board_rect: TextureRect = null
var warning_board_label: Label = null
var warning_tween: Tween = null

var pause_layer: CanvasLayer = null
var pause_root: Control = null

var reload_layer: CanvasLayer = null
var reload_root: Control = null
var reload_title_label: Label = null
var reload_reason_label: Label = null
var reload_stats_label: Label = null
var reload_button: Button = null

func _ready() -> void:
	_auto_recover_missing_references()
	_setup_custom_hud()
	_setup_pause_menu()
	_setup_reload_screen()

	if leader != null:
		if leader.has_signal("inventory_updated"):
			leader.inventory_updated.connect(_on_inventory_updated)
		if leader.has_signal("squad_updated"):
			leader.squad_updated.connect(_on_squad_updated)
		if leader.has_signal("leader_died"):
			leader.leader_died.connect(_on_leader_died)

	if closing_fog != null:
		closing_fog.leader = leader
		if closing_fog.has_signal("fog_started_closing"):
			closing_fog.fog_started_closing.connect(_on_fog_started_closing)

	for den in ant_dens:
		if den != null and den.has_signal("den_reached"):
			den.den_reached.connect(_on_den_reached)

	_setup_round(1)

	var has_title := (title_logo_texture != null)
	var has_story := _has_valid_story_slides()
	var has_map_intro := (intro_map_texture != null and intro_memorize_duration > 0.0)

	if has_title or has_story or has_map_intro:
		if custom_hud_layer != null:
			custom_hud_layer.visible = false
		if status_label != null:
			status_label.visible = false

		get_tree().paused = true
		var audio := AudioManager.get_instance(get_tree())
		var prev_audio_mode := Node.PROCESS_MODE_INHERIT
		if audio != null:
			prev_audio_mode = audio.process_mode
			audio.process_mode = Node.PROCESS_MODE_ALWAYS

		var active_title_layer: CanvasLayer = null
		if has_title:
			active_title_layer = await _show_title_screen(audio)
			if not is_inside_tree():
				return

		if has_story:
			await _play_story_cutscene(audio, active_title_layer)
			if not is_inside_tree():
				return
		elif active_title_layer != null and is_instance_valid(active_title_layer):
			active_title_layer.queue_free()

		if has_map_intro:
			await _play_intro_map_sequence(audio)
			if not is_inside_tree():
				return

		if audio != null and is_instance_valid(audio):
			audio.process_mode = prev_audio_mode

		get_tree().paused = false
		if custom_hud_layer != null:
			custom_hud_layer.visible = true
		elif status_label != null:
			status_label.visible = true
		_refresh_hud()

		if has_map_intro:
			_show_hud_alert("The wind blew your map away! Reach Ant Den 1!", 4.0)

	_start_item_spawn_loop()
	_start_hazard_loop()
	_start_hand_loop()

	await get_tree().create_timer(initial_spawn_delay).timeout
	if not is_inside_tree():
		return

	_on_spawn_timer_timeout()

	var follower_timer := Timer.new()
	follower_timer.wait_time = spawn_interval
	follower_timer.autostart = true
	follower_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(follower_timer)

func _show_title_screen(audio: Node) -> CanvasLayer:
	is_title_open = true

	var title_layer := CanvasLayer.new()
	title_layer.name = "TitleScreenLayer"
	title_layer.layer = 40
	title_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(title_layer)

	var root := Control.new()
	root.name = "TitleRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	title_layer.add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.14, 0.10, 0.07, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "TitleContent"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var main_vbox := VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 22)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(main_vbox)

	var logo_rect := TextureRect.new()
	logo_rect.texture = title_logo_texture
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.custom_minimum_size = Vector2(640, 290)
	logo_rect.pivot_offset = Vector2(320, 145)
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(logo_rect)

	var logo_tw := title_layer.create_tween().set_loops()
	logo_tw.tween_property(logo_rect, "scale", Vector2(1.035, 1.035), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	logo_tw.tween_property(logo_rect, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var btn_vbox := VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 14)
	main_vbox.add_child(btn_vbox)

	var start_btn := Button.new()
	start_btn.text = "START GAME"
	start_btn.custom_minimum_size = Vector2(270, 64)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_custom_button_style(start_btn, 23)
	btn_vbox.add_child(start_btn)

	var controls_btn := Button.new()
	controls_btn.text = "HOW TO PLAY"
	controls_btn.custom_minimum_size = Vector2(270, 56)
	controls_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_custom_button_style(controls_btn, 19)
	btn_vbox.add_child(controls_btn)

	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.custom_minimum_size = Vector2(270, 56)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_custom_button_style(quit_btn, 19)
	btn_vbox.add_child(quit_btn)

	var info_panel := PanelContainer.new()
	info_panel.visible = false
	info_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.86, 0.80, 0.71, 0.96)
	info_style.border_color = Color(0.24, 0.16, 0.09, 1.0)
	info_style.set_border_width_all(3)
	info_style.set_corner_radius_all(12)
	info_style.content_margin_left = 22
	info_style.content_margin_right = 22
	info_style.content_margin_top = 12
	info_style.content_margin_bottom = 12
	info_panel.add_theme_stylebox_override("panel", info_style)
	main_vbox.add_child(info_panel)

	var info_label := Label.new()
	info_label.text = "Move: WASD / Arrow Keys   |   Pick Up Item: E\nHuddle Squad: SPACE   |   Pause: ESC\nRecruit stray ants, gather Food & Water quota, and dodge hazards!"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color(0.16, 0.10, 0.06, 1.0))
	info_panel.add_child(info_label)

	controls_btn.pressed.connect(func() -> void:
		if audio != null:
			audio.play_button()
		info_panel.visible = not info_panel.visible
	)

	quit_btn.pressed.connect(func() -> void:
		if audio != null:
			audio.play_button()
		get_tree().quit()
	)

	start_btn.grab_focus()
	await start_btn.pressed

	if not is_inside_tree():
		return title_layer

	start_btn.disabled = true
	controls_btn.disabled = true
	quit_btn.disabled = true

	if audio != null:
		audio.play_button()

	if logo_tw != null and logo_tw.is_valid():
		logo_tw.kill()

	var exit_tw := title_layer.create_tween().set_parallel(true)
	exit_tw.tween_property(center, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tw.tween_property(backdrop, "color", Color(0.04, 0.03, 0.03, 1.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await exit_tw.finished

	is_title_open = false
	return title_layer

func _apply_custom_button_style(btn: Button, font_size: int = 20) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	if ui_button_texture != null:
		btn.add_theme_color_override("font_color", Color(0.99, 0.96, 0.90, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.85, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.90, 0.84, 0.72, 1.0))
		btn.add_theme_constant_override("outline_size", 4)
		btn.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.04, 0.95))

		var normal_sb := StyleBoxTexture.new()
		normal_sb.texture = ui_button_texture
		normal_sb.content_margin_left = 22
		normal_sb.content_margin_right = 22
		normal_sb.content_margin_top = 10
		normal_sb.content_margin_bottom = 12

		var hover_sb := normal_sb.duplicate() as StyleBoxTexture
		hover_sb.modulate_color = Color(1.12, 1.08, 1.02, 1.0)

		var pressed_sb := normal_sb.duplicate() as StyleBoxTexture
		pressed_sb.modulate_color = Color(0.82, 0.78, 0.72, 1.0)

		btn.add_theme_stylebox_override("normal", normal_sb)
		btn.add_theme_stylebox_override("hover", hover_sb)
		btn.add_theme_stylebox_override("focus", hover_sb)
		btn.add_theme_stylebox_override("pressed", pressed_sb)
	else:
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.45, 0.28, 0.16, 1.0)
		btn_normal.set_corner_radius_all(8)
		btn_normal.content_margin_left = 20
		btn_normal.content_margin_right = 20
		btn_normal.content_margin_top = 10
		btn_normal.content_margin_bottom = 10

		var btn_hover := btn_normal.duplicate() as StyleBoxFlat
		btn_hover.bg_color = Color(0.58, 0.36, 0.20, 1.0)

		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("focus", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_normal)

func _setup_custom_hud() -> void:
	var has_any_hud_tex := (
		ui_antbar_texture != null or
		ui_upgradebar_texture != null or
		ui_resources_texture != null or
		ui_warningboard_texture != null or
		ui_button_texture != null
	)
	if not has_any_hud_tex:
		return

	if status_label != null:
		status_label.visible = false

	custom_hud_layer = CanvasLayer.new()
	custom_hud_layer.name = "CustomHUDLayer"
	custom_hud_layer.layer = 12
	add_child(custom_hud_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_hud_layer.add_child(root)

	var left_vbox := VBoxContainer.new()
	left_vbox.position = Vector2(20, 16)
	left_vbox.add_theme_constant_override("separation", 4)
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left_vbox)

	var summary_panel := PanelContainer.new()
	summary_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	summary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sum_style := StyleBoxFlat.new()
	sum_style.bg_color = Color(0.84, 0.79, 0.71, 0.94)
	sum_style.border_color = Color(0.24, 0.16, 0.09, 1.0)
	sum_style.set_border_width_all(3)
	sum_style.set_corner_radius_all(10)
	sum_style.content_margin_left = 14
	sum_style.content_margin_right = 14
	sum_style.content_margin_top = 6
	sum_style.content_margin_bottom = 6
	summary_panel.add_theme_stylebox_override("panel", sum_style)
	left_vbox.add_child(summary_panel)

	summary_strip_label = Label.new()
	summary_strip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_strip_label.add_theme_font_size_override("font_size", 17)
	summary_strip_label.add_theme_color_override("font_color", Color(0.16, 0.10, 0.06, 1.0))
	summary_panel.add_child(summary_strip_label)

	if ui_antbar_texture != null:
		var ant_bar := TextureRect.new()
		ant_bar.texture = ui_antbar_texture
		ant_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ant_bar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ant_bar.custom_minimum_size = Vector2(240, 124)
		ant_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ant_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left_vbox.add_child(ant_bar)

		ant_bar_label = Label.new()
		ant_bar_label.anchor_left = 0.48
		ant_bar_label.anchor_right = 0.92
		ant_bar_label.anchor_top = 0.36
		ant_bar_label.anchor_bottom = 0.64
		ant_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ant_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ant_bar_label.add_theme_font_size_override("font_size", 20)
		ant_bar_label.add_theme_color_override("font_color", Color(0.16, 0.10, 0.06, 1.0))
		ant_bar.add_child(ant_bar_label)

	if ui_upgradebar_texture != null:
		var upg_bar := TextureRect.new()
		upg_bar.texture = ui_upgradebar_texture
		upg_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		upg_bar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		upg_bar.custom_minimum_size = Vector2(236, 94)
		upg_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		upg_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left_vbox.add_child(upg_bar)

		upgrade_badge_icon = TextureRect.new()
		upgrade_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		upgrade_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		upgrade_badge_icon.anchor_left = 0.115
		upgrade_badge_icon.anchor_right = 0.305
		upgrade_badge_icon.anchor_top = 0.29
		upgrade_badge_icon.anchor_bottom = 0.75
		upgrade_badge_icon.visible = false
		upgrade_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upg_bar.add_child(upgrade_badge_icon)

		upgrade_bar_label = Label.new()
		upgrade_bar_label.anchor_left = 0.33
		upgrade_bar_label.anchor_right = 0.86
		upgrade_bar_label.anchor_top = 0.36
		upgrade_bar_label.anchor_bottom = 0.64
		upgrade_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrade_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		upgrade_bar_label.clip_text = true
		upgrade_bar_label.add_theme_font_size_override("font_size", 13)
		upgrade_bar_label.add_theme_color_override("font_color", Color(0.16, 0.10, 0.06, 1.0))
		upg_bar.add_child(upgrade_bar_label)

	if ui_resources_texture != null:
		var res_grid := GridContainer.new()
		res_grid.columns = 2
		res_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		res_grid.add_theme_constant_override("v_separation", 2)
		res_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left_vbox.add_child(res_grid)

		var tex_size := ui_resources_texture.get_size()

		var res_layout: Array[Dictionary] = [
			{"name": "Bread Crumb",   "rx": 0.020, "ry": 0.18, "rw": 0.330, "rh": 0.32, "lt": 0.25, "lb": 0.65},
			{"name": "Water Droplet", "rx": 0.365, "ry": 0.18, "rw": 0.330, "rh": 0.32, "lt": 0.25, "lb": 0.65},
			{"name": "Fruit Piece",   "rx": 0.365, "ry": 0.53, "rw": 0.330, "rh": 0.32, "lt": 0.16, "lb": 0.56},
			{"name": "Sugar Cube",    "rx": 0.020, "ry": 0.53, "rw": 0.330, "rh": 0.32, "lt": 0.16, "lb": 0.56},
			{"name": "Meat",          "rx": 0.692, "ry": 0.18, "rw": 0.305, "rh": 0.32, "lt": 0.25, "lb": 0.65}
		]

		for entry in res_layout:
			var atlas := AtlasTexture.new()
			atlas.atlas = ui_resources_texture
			atlas.region = Rect2(
				entry["rx"] * tex_size.x,
				entry["ry"] * tex_size.y,
				entry["rw"] * tex_size.x,
				entry["rh"] * tex_size.y
			)

			var res_rect := TextureRect.new()
			res_rect.texture = atlas
			res_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			res_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			res_rect.custom_minimum_size = Vector2(132, 46)
			res_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			res_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			res_grid.add_child(res_rect)

			var count_lbl := Label.new()
			count_lbl.text = "x0"
			count_lbl.anchor_left = 0.42
			count_lbl.anchor_right = 0.90
			count_lbl.anchor_top = entry["lt"]
			count_lbl.anchor_bottom = entry["lb"]
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			count_lbl.add_theme_font_size_override("font_size", 16)
			count_lbl.add_theme_color_override("font_color", Color(0.16, 0.10, 0.06, 1.0))
			res_rect.add_child(count_lbl)

			resource_count_labels[entry["name"]] = count_lbl

	var menu_btn := Button.new()
	menu_btn.text = "MENU [ESC]"
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left = -185.0
	menu_btn.offset_right = -20.0
	menu_btn.offset_top = 18.0
	menu_btn.offset_bottom = 72.0
	menu_btn.focus_mode = Control.FOCUS_NONE
	_apply_custom_button_style(menu_btn, 17)
	menu_btn.pressed.connect(_toggle_pause_menu)
	root.add_child(menu_btn)

	if ui_warningboard_texture != null:
		warning_board_rect = TextureRect.new()
		warning_board_rect.texture = ui_warningboard_texture
		warning_board_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		warning_board_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		warning_board_rect.set_anchors_preset(Control.PRESET_CENTER_TOP)
		warning_board_rect.offset_left = -240.0
		warning_board_rect.offset_right = 240.0
		warning_board_rect.offset_top = 14.0
		warning_board_rect.offset_bottom = 194.0
		warning_board_rect.pivot_offset = Vector2(240.0, 90.0)
		warning_board_rect.visible = false
		warning_board_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(warning_board_rect)

		warning_board_label = Label.new()
		warning_board_label.anchor_left = 0.14
		warning_board_label.anchor_right = 0.82
		warning_board_label.anchor_top = 0.38
		warning_board_label.anchor_bottom = 0.85
		warning_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning_board_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		warning_board_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning_board_label.add_theme_font_size_override("font_size", 16)
		warning_board_label.add_theme_color_override("font_color", Color(0.18, 0.10, 0.05, 1.0))
		warning_board_rect.add_child(warning_board_label)

	badge_popup_holder = Control.new()
	badge_popup_holder.set_anchors_preset(Control.PRESET_CENTER)
	badge_popup_holder.offset_left = -190.0
	badge_popup_holder.offset_right = 190.0
	badge_popup_holder.offset_top = -140.0
	badge_popup_holder.offset_bottom = 140.0
	badge_popup_holder.pivot_offset = Vector2(190.0, 140.0)
	badge_popup_holder.visible = false
	badge_popup_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge_popup_holder)

	var badge_vbox := VBoxContainer.new()
	badge_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_vbox.add_theme_constant_override("separation", 8)
	badge_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_popup_holder.add_child(badge_vbox)

	badge_popup_icon = TextureRect.new()
	badge_popup_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge_popup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge_popup_icon.custom_minimum_size = Vector2(150, 150)
	badge_popup_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_popup_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_vbox.add_child(badge_popup_icon)

	badge_popup_title = Label.new()
	badge_popup_title.text = "UPGRADE UNLOCKED!"
	badge_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_popup_title.add_theme_font_size_override("font_size", 24)
	badge_popup_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
	badge_popup_title.add_theme_constant_override("outline_size", 5)
	badge_popup_title.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.03, 0.95))
	badge_vbox.add_child(badge_popup_title)

	badge_popup_desc = Label.new()
	badge_popup_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_popup_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge_popup_desc.add_theme_font_size_override("font_size", 18)
	badge_popup_desc.add_theme_color_override("font_color", Color(0.99, 0.96, 0.90, 1.0))
	badge_popup_desc.add_theme_constant_override("outline_size", 4)
	badge_popup_desc.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.03, 0.95))
	badge_vbox.add_child(badge_popup_desc)

func _get_badge_texture_for_upgrade(upgrade_msg: String) -> Texture2D:
	if "Followers" in upgrade_msg:
		return badge_squad_texture
	elif "Capacity" in upgrade_msg:
		return badge_capacity_texture
	elif "Speed" in upgrade_msg:
		return badge_speed_texture
	return null

func _show_upgrade_badge_popup(badge_tex: Texture2D, upgrade_msg: String) -> void:
	if badge_popup_holder == null or badge_tex == null:
		return

	badge_popup_icon.texture = badge_tex
	badge_popup_desc.text = upgrade_msg
	badge_popup_holder.visible = true
	badge_popup_holder.modulate.a = 0.0
	badge_popup_holder.scale = Vector2(0.35, 0.35)

	if badge_popup_tween != null and badge_popup_tween.is_valid():
		badge_popup_tween.kill()

	badge_popup_tween = create_tween()
	badge_popup_tween.set_parallel(true)
	badge_popup_tween.tween_property(badge_popup_holder, "modulate:a", 1.0, 0.25)
	badge_popup_tween.tween_property(badge_popup_holder, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	badge_popup_tween.chain().tween_interval(3.0)
	badge_popup_tween.chain().set_parallel(true)
	badge_popup_tween.tween_property(badge_popup_holder, "modulate:a", 0.0, 0.35)
	badge_popup_tween.tween_property(badge_popup_holder, "scale", Vector2(0.85, 0.85), 0.35)
	badge_popup_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(badge_popup_holder):
			badge_popup_holder.visible = false
	)

func _setup_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.name = "PauseMenuLayer"
	pause_layer.layer = 25
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)

	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	pause_layer.add_child(pause_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.04, 0.03, 0.65)
	pause_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(center)

	var menu_holder: Control
	if ui_menubg_texture != null:
		var bg_tex := TextureRect.new()
		bg_tex.texture = ui_menubg_texture
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_tex.custom_minimum_size = Vector2(430, 460)
		center.add_child(bg_tex)
		menu_holder = bg_tex
	else:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(360, 320)
		center.add_child(panel)
		menu_holder = panel

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.18
	vbox.anchor_right = 0.82
	vbox.anchor_top = 0.22
	vbox.anchor_bottom = 0.82
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	menu_holder.add_child(vbox)

	var resume_btn := Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(220, 56)
	resume_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_custom_button_style(resume_btn, 21)
	resume_btn.pressed.connect(_toggle_pause_menu)
	vbox.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "RESTART"
	restart_btn.custom_minimum_size = Vector2(220, 56)
	restart_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_custom_button_style(restart_btn, 21)
	restart_btn.pressed.connect(func() -> void:
		get_tree().paused = false
		_reload_game()
	)
	vbox.add_child(restart_btn)

	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.custom_minimum_size = Vector2(220, 56)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_custom_button_style(quit_btn, 21)
	quit_btn.pressed.connect(func() -> void:
		get_tree().quit()
	)
	vbox.add_child(quit_btn)

func _toggle_pause_menu() -> void:
	if is_title_open or is_story_playing or is_intro_playing or is_game_over or game_finished:
		return

	var audio := AudioManager.get_instance(get_tree())
	if audio != null:
		audio.play_button()

	is_pause_open = not is_pause_open
	pause_root.visible = is_pause_open
	get_tree().paused = is_pause_open

func _play_intro_map_sequence(audio: Node) -> void:
	is_intro_playing = true
	intro_skip_requested = false

	var intro_layer := CanvasLayer.new()
	intro_layer.name = "IntroMapLayer"
	intro_layer.layer = 30
	intro_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(intro_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.focus_mode = Control.FOCUS_ALL
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_layer.add_child(root)
	root.grab_focus()

	root.gui_input.connect(func(event: InputEvent) -> void:
		if not allow_skip_intro:
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
				intro_skip_requested = true
				root.accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			intro_skip_requested = true
			root.accept_event()
	)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color(0.05, 0.04, 0.03, 0.78)
	root.add_child(backdrop)

	var vp_size := get_viewport().get_visible_rect().size
	var tex_size := intro_map_texture.get_size()
	var aspect := tex_size.x / maxf(1.0, tex_size.y)
	var map_h := minf(vp_size.y * 0.76, vp_size.x * 0.84 / maxf(0.1, aspect))
	var map_w := map_h * aspect
	var base_pos := Vector2((vp_size.x - map_w) * 0.5, (vp_size.y - map_h) * 0.48)

	var map_rect := TextureRect.new()
	map_rect.texture = intro_map_texture
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.size = Vector2(map_w, map_h)
	map_rect.position = base_pos
	map_rect.pivot_offset = map_rect.size * 0.5
	map_rect.modulate.a = 0.0
	map_rect.scale = Vector2(0.92, 0.92)
	root.add_child(map_rect)

	var top_label := Label.new()
	top_label.text = "MEMORIZE THE ROUTE TO ALL 3 ANT DENS!"
	top_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_label.offset_top = 26.0
	top_label.add_theme_font_size_override("font_size", 28)
	top_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))
	top_label.add_theme_constant_override("outline_size", 5)
	top_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.95))
	root.add_child(top_label)

	var bottom_label := Label.new()
	bottom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_label.offset_bottom = -26.0
	bottom_label.offset_top = -66.0
	bottom_label.add_theme_font_size_override("font_size", 20)
	bottom_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.78, 0.95))
	bottom_label.add_theme_constant_override("outline_size", 4)
	bottom_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.95))
	root.add_child(bottom_label)

	var enter_tw := intro_layer.create_tween().set_parallel(true)
	enter_tw.tween_property(map_rect, "modulate:a", 1.0, 0.35)
	enter_tw.tween_property(map_rect, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await enter_tw.finished

	var remaining := intro_memorize_duration
	var flutter_time := 0.0
	while remaining > 0.0 and not intro_skip_requested and is_inside_tree():
		var dt := get_process_delta_time()
		remaining -= dt
		flutter_time += dt

		if not root.has_focus():
			root.grab_focus()

		var skip_hint := "  |  [SPACE / CLICK] Ready" if allow_skip_intro else ""
		bottom_label.text = "Wind picking up in %ds...%s" % [ceili(maxf(0.0, remaining)), skip_hint]

		if remaining <= 0.75:
			var intensity := (0.75 - remaining) / 0.75
			map_rect.position = base_pos + Vector2(
				sin(flutter_time * 42.0) * 10.0 * intensity,
				cos(flutter_time * 36.0) * 6.0 * intensity
			)
			map_rect.rotation_degrees = sin(flutter_time * 32.0) * 3.5 * intensity
		else:
			map_rect.position = base_pos + Vector2(0.0, sin(flutter_time * 2.2) * 5.0)
			map_rect.rotation_degrees = sin(flutter_time * 1.5) * 0.8

		await get_tree().process_frame

	if not is_inside_tree():
		return

	top_label.visible = false
	bottom_label.visible = false

	if audio != null:
		audio.play_map_blown_off()

	_spawn_intro_wind_streaks(root, vp_size)

	var blow_tw := intro_layer.create_tween().set_parallel(true)
	blow_tw.tween_property(map_rect, "position", base_pos + Vector2(vp_size.x * 1.25, -vp_size.y * 0.42), 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	blow_tw.tween_property(map_rect, "rotation_degrees", 34.0, 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	blow_tw.tween_property(map_rect, "scale", Vector2(1.12, 0.76), 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	blow_tw.tween_property(map_rect, "modulate:a", 0.0, 0.85).set_delay(0.2)
	blow_tw.tween_property(backdrop, "color:a", 0.0, 0.95).set_delay(0.1)
	await blow_tw.finished

	if is_instance_valid(intro_layer):
		intro_layer.queue_free()

	is_intro_playing = false

func _spawn_intro_wind_streaks(parent: Control, vp_size: Vector2) -> void:
	for i in range(14):
		var streak := ColorRect.new()
		var w := randf_range(140.0, 340.0)
		var h := randf_range(3.0, 6.0)
		streak.size = Vector2(w, h)
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak.color = Color(0.96, 0.93, 0.86, randf_range(0.25, 0.55))
		streak.rotation_degrees = -12.0
		var start_y := randf_range(vp_size.y * 0.1, vp_size.y * 0.9)
		streak.position = Vector2(-w - randf_range(0.0, 260.0), start_y)
		parent.add_child(streak)

		var tw := parent.create_tween()
		var delay := randf_range(0.0, 0.35)
		var dur := randf_range(0.45, 0.75)
		tw.tween_property(streak, "position", Vector2(vp_size.x + 200.0, start_y - 260.0), dur).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.finished.connect(streak.queue_free)

func _has_valid_story_slides() -> bool:
	for tex in story_slides:
		if tex != null:
			return true
	return false

func _play_story_cutscene(audio: Node, title_layer: CanvasLayer = null) -> void:
	is_story_playing = true
	story_skip_all_requested = false

	var slides: Array[Dictionary] = []
	for i in range(story_slides.size()):
		if story_slides[i] != null:
			var caption := story_captions[i] if i < story_captions.size() else ""
			slides.append({
				"texture": story_slides[i],
				"caption": caption
			})

	if slides.is_empty():
		if title_layer != null and is_instance_valid(title_layer):
			title_layer.queue_free()
		is_story_playing = false
		return

	var story_layer := CanvasLayer.new()
	story_layer.name = "OpeningStoryLayer"
	story_layer.layer = 35
	story_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(story_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.focus_mode = Control.FOCUS_ALL
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	story_layer.add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color(0.04, 0.03, 0.03, 1.0)
	root.add_child(bg)

	if title_layer != null and is_instance_valid(title_layer):
		title_layer.queue_free()

	root.grab_focus()

	root.gui_input.connect(func(event: InputEvent) -> void:
		if not allow_skip_story:
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT]:
				story_next_requested = true
				root.accept_event()
			elif event.keycode == KEY_ESCAPE:
				story_skip_all_requested = true
				story_next_requested = true
				root.accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			story_next_requested = true
			root.accept_event()
	)

	var vp_size := get_viewport().get_visible_rect().size

	var slide_rect := TextureRect.new()
	slide_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slide_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slide_rect.size = vp_size
	slide_rect.position = Vector2.ZERO
	slide_rect.pivot_offset = vp_size * 0.5
	slide_rect.modulate.a = 0.0
	root.add_child(slide_rect)

	var caption_panel := PanelContainer.new()
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption_panel.offset_left = 120.0
	caption_panel.offset_right = -120.0
	caption_panel.offset_top = -132.0
	caption_panel.offset_bottom = -44.0

	var cap_style := StyleBoxFlat.new()
	cap_style.bg_color = Color(0.06, 0.05, 0.04, 0.82)
	cap_style.border_color = Color(0.75, 0.65, 0.45, 0.55)
	cap_style.set_border_width_all(2)
	cap_style.set_corner_radius_all(10)
	cap_style.content_margin_left = 24
	cap_style.content_margin_right = 24
	cap_style.content_margin_top = 12
	cap_style.content_margin_bottom = 12
	caption_panel.add_theme_stylebox_override("panel", cap_style)
	root.add_child(caption_panel)

	var caption_label := Label.new()
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.add_theme_font_size_override("font_size", 22)
	caption_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86, 1.0))
	caption_panel.add_child(caption_label)

	var hint_label := Label.new()
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_right = -28.0
	hint_label.offset_top = -34.0
	hint_label.offset_bottom = -10.0
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 0.78))
	root.add_child(hint_label)

	for idx in range(slides.size()):
		if story_skip_all_requested or not is_inside_tree():
			break

		story_next_requested = false
		var entry := slides[idx]
		slide_rect.texture = entry["texture"]
		slide_rect.scale = Vector2.ONE
		slide_rect.modulate.a = 0.0

		var cap_text: String = entry["caption"]
		caption_panel.visible = cap_text.strip_edges() != ""
		caption_label.text = cap_text
		caption_panel.modulate.a = 0.0

		if allow_skip_story:
			hint_label.text = "(%d / %d)  [CLICK / SPACE] Next   |   [ESC] Skip" % [idx + 1, slides.size()]
		else:
			hint_label.text = "%d / %d" % [idx + 1, slides.size()]

		var fade_in := story_layer.create_tween().set_parallel(true)
		fade_in.tween_property(slide_rect, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if caption_panel.visible:
			fade_in.tween_property(caption_panel, "modulate:a", 1.0, 0.4)
		await fade_in.finished

		var elapsed := 0.0
		var dur := maxf(0.8, slide_duration)
		while elapsed < dur and not story_next_requested and not story_skip_all_requested and is_inside_tree():
			var dt := get_process_delta_time()
			elapsed += dt
			if not root.has_focus():
				root.grab_focus()
			var zoom := lerpf(1.0, 1.045, clampf(elapsed / dur, 0.0, 1.0))
			slide_rect.scale = Vector2(zoom, zoom)
			await get_tree().process_frame

		if not is_inside_tree():
			return

		if story_next_requested and not story_skip_all_requested and audio != null:
			audio.play_button()

		var fade_out := story_layer.create_tween().set_parallel(true)
		fade_out.tween_property(slide_rect, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if caption_panel.visible:
			fade_out.tween_property(caption_panel, "modulate:a", 0.0, 0.25)
		await fade_out.finished

	if is_instance_valid(story_layer):
		var end_tw := story_layer.create_tween()
		end_tw.tween_property(bg, "color:a", 0.0, 0.35)
		await end_tw.finished
		if is_instance_valid(story_layer):
			story_layer.queue_free()

	is_story_playing = false

func _setup_reload_screen() -> void:
	reload_layer = CanvasLayer.new()
	reload_layer.name = "ReloadScreenLayer"
	reload_layer.layer = 20
	add_child(reload_layer)

	reload_root = Control.new()
	reload_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	reload_root.visible = false
	reload_root.modulate.a = 0.0
	reload_layer.add_child(reload_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.03, 0.03, 0.68)
	reload_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	reload_root.add_child(center)

	var container_node: Control
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	if ui_menubg_texture != null:
		var bg_tex := TextureRect.new()
		bg_tex.texture = ui_menubg_texture
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_tex.custom_minimum_size = Vector2(460, 480)
		center.add_child(bg_tex)
		container_node = bg_tex

		vbox.anchor_left = 0.16
		vbox.anchor_right = 0.84
		vbox.anchor_top = 0.20
		vbox.anchor_bottom = 0.84
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		container_node.add_child(vbox)
	else:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(460, 0)
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.12, 0.08, 0.07, 0.94)
		panel_style.border_color = Color(0.86, 0.26, 0.22, 0.95)
		panel_style.set_border_width_all(3)
		panel_style.set_corner_radius_all(14)
		panel_style.content_margin_left = 32
		panel_style.content_margin_right = 32
		panel_style.content_margin_top = 28
		panel_style.content_margin_bottom = 28
		panel.add_theme_stylebox_override("panel", panel_style)
		center.add_child(panel)
		panel.add_child(vbox)

	var text_col := Color(0.16, 0.10, 0.06, 1.0) if ui_menubg_texture != null else Color(0.95, 0.90, 0.85, 1.0)

	reload_title_label = Label.new()
	reload_title_label.text = "SQUAD FALLEN"
	reload_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_title_label.add_theme_font_size_override("font_size", 28)
	reload_title_label.add_theme_color_override("font_color", Color(0.82, 0.20, 0.16, 1.0))
	vbox.add_child(reload_title_label)

	reload_reason_label = Label.new()
	reload_reason_label.text = "All follower ants have fallen!"
	reload_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reload_reason_label.add_theme_font_size_override("font_size", 17)
	reload_reason_label.add_theme_color_override("font_color", text_col)
	vbox.add_child(reload_reason_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	reload_stats_label = Label.new()
	reload_stats_label.text = "Round: 1 / 3  |  Total Points: 0"
	reload_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_stats_label.add_theme_font_size_override("font_size", 16)
	reload_stats_label.add_theme_color_override("font_color", text_col)
	vbox.add_child(reload_stats_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	reload_button = Button.new()
	reload_button.text = "Play Again [R]"
	reload_button.custom_minimum_size = Vector2(230, 54)
	reload_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_custom_button_style(reload_button, 18)
	reload_button.pressed.connect(_reload_game)
	vbox.add_child(reload_button)

func _show_reload_screen(title_text: String, reason_text: String, is_victory: bool = false) -> void:
	if reload_root == null:
		return

	reload_title_label.text = title_text
	reload_reason_label.text = reason_text
	reload_stats_label.text = "Round Reached: %d / %d  |  Points: %d" % [current_round, ant_dens.size(), total_points]

	var accent := Color(0.18, 0.56, 0.22, 1.0) if is_victory else Color(0.82, 0.20, 0.16, 1.0)
	reload_title_label.add_theme_color_override("font_color", accent)

	reload_root.visible = true
	reload_root.modulate.a = 0.0
	reload_button.grab_focus()

	var tw := create_tween()
	tw.tween_property(reload_root, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _reload_game() -> void:
	var audio := AudioManager.get_instance(get_tree())
	if audio != null:
		audio.play_button()
		await get_tree().create_timer(0.12).timeout
	if is_inside_tree():
		get_tree().reload_current_scene()

func _auto_recover_missing_references() -> void:
	if leader == null:
		leader = get_node_or_null("AntLeader")

	if ant_dens.is_empty():
		var found_dens: Array[Area2D] = []
		for node in find_children("*", "Area2D", true, false):
			if node.get("required_food") != null:
				found_dens.append(node as Area2D)
		found_dens.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
		ant_dens = found_dens

	if round_start_markers.is_empty():
		var found_markers: Array[Marker2D] = []
		for node in find_children("*", "Marker2D", true, false):
			if "Start" in node.name or "Round" in node.name:
				found_markers.append(node as Marker2D)
		found_markers.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
		round_start_markers = found_markers

	if forward_borders.is_empty():
		var found_borders: Array[StaticBody2D] = []
		for node in find_children("*", "StaticBody2D", true, false):
			if "Border" in node.name:
				found_borders.append(node as StaticBody2D)
		found_borders.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
		forward_borders = found_borders

	if round_spawn_mins.is_empty() and round_spawn_maxs.is_empty():
		round_spawn_mins = [Vector2(350, -7650), Vector2(8350, -7650), Vector2(16350, -7650)]
		round_spawn_maxs = [Vector2(7650, 650), Vector2(15650, 650), Vector2(23650, 650)]

	if follower_scene == null:
		follower_scene = _try_load_scene(["res://scenes/ant_follower.tscn", "res://ant_follower.tscn"])

	if item_scene == null:
		item_scene = _try_load_scene(["res://scenes/scavenge_item.tscn", "res://scenes/item.tscn", "res://scavenge_item.tscn", "res://item.tscn"])

	if foot_scene == null:
		foot_scene = _try_load_scene(["res://scenes/hazard_foot.tscn", "res://hazard_foot.tscn"])

	if hand_scene == null:
		hand_scene = _try_load_scene(["res://scenes/hazard_hand.tscn", "res://hazard_hand.tscn"])

func _try_load_scene(paths: Array[String]) -> PackedScene:
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p) as PackedScene
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not is_title_open and not is_story_playing and not is_intro_playing and not is_game_over and not game_finished:
			_toggle_pause_menu()
		elif (is_game_over or game_finished) and event.keycode == KEY_R:
			_reload_game()

func _on_fog_started_closing() -> void:
	if not is_game_over and not game_finished:
		var audio := AudioManager.get_instance(get_tree())
		if audio != null:
			audio.play_map_blown_off()
		_show_hud_alert("THE FOG IS CLOSING IN! Gather the quota & advance to the Ant Den now!", 4.5)

func _on_leader_died(reason: String) -> void:
	if is_game_over or game_finished:
		return
	is_game_over = true
	if closing_fog != null and closing_fog.has_method("stop"):
		closing_fog.stop()

	var audio := AudioManager.get_instance(get_tree())
	if audio != null:
		audio.set_bgm_dimmed(true)

	await get_tree().create_timer(0.55).timeout
	if is_inside_tree():
		_show_reload_screen("SQUAD FALLEN", reason, false)

func _setup_round(round_num: int) -> void:
	current_round = round_num
	var idx := round_num - 1

	for i in range(ant_dens.size()):
		var den := ant_dens[i]
		if den == null:
			continue
		if i < idx:
			den.set_den_state(false, true)
		elif i == idx:
			den.set_den_state(true, false)
			food_quota = den.get("required_food")
			water_quota = den.get("required_water")
		else:
			den.set_den_state(false, false)

	if idx >= 0 and idx < round_max_items.size():
		max_items_on_map = round_max_items[idx]

	if idx >= 0 and idx < round_spawn_mins.size() and idx < round_spawn_maxs.size():
		spawn_area_min = round_spawn_mins[idx]
		spawn_area_max = round_spawn_maxs[idx]

	if round_num > 1:
		for f in get_tree().get_nodes_in_group("followers"):
			if is_instance_valid(f) and f.get("line_target") == null:
				f.queue_free()
		for item in get_tree().get_nodes_in_group("items"):
			if is_instance_valid(item):
				item.queue_free()

	if leader != null and idx >= 0 and idx < round_start_markers.size():
		var marker := round_start_markers[idx]
		if marker != null:
			leader.teleport_squad(marker.global_position)
			var cam := get_viewport().get_camera_2d()
			if cam == null and leader != null:
				cam = leader.get_node_or_null("Camera2D")
			if cam != null:
				cam.limit_left = 0
				cam.limit_top = -8000
				cam.limit_right = 24000
				cam.limit_bottom = 1000
				cam.reset_smoothing()
				cam.force_update_scroll()

	_activate_round_borders()
	_start_round_fog(round_num)

	_refill_cells(available_follower_cells)
	_refill_cells(available_item_cells)
	_populate_initial_round_items.call_deferred()
	_refresh_hud()

func _start_round_fog(round_num: int) -> void:
	if closing_fog == null or not closing_fog.has_method("start_round"):
		return

	var idx := round_num - 1
	var zone_min_x := float(idx) * 8000.0
	var zone_max_x := float(round_num) * 8000.0
	var zone_min_y := -8000.0
	var zone_max_y := 1000.0

	if idx > 0 and (idx - 1) < forward_borders.size() and forward_borders[idx - 1] != null:
		zone_min_x = forward_borders[idx - 1].global_position.x
	if idx < forward_borders.size() and forward_borders[idx] != null:
		zone_max_x = forward_borders[idx].global_position.x

	var fog_dir := "bottom" if round_num == 1 else "left"
	closing_fog.start_round(zone_min_x, zone_max_x, zone_min_y, zone_max_y, round_num, fog_dir)

func _populate_initial_round_items() -> void:
	var target_count := mini(initial_round_items, max_items_on_map)
	for i in range(target_count):
		_on_item_spawn_timer_timeout()

func _activate_round_borders() -> void:
	for border in forward_borders:
		if border == null:
			continue
		border.visible = true
		if border.collision_layer == 0:
			border.collision_layer = 1
		for child in border.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)

func _on_den_reached(den: Area2D, leader_body: Node2D) -> void:
	if game_finished or is_game_over:
		return

	var current_food: int = leader_body.get_total_food()
	var current_water: int = leader_body.get_total_water()
	var req_food: int = den.get("required_food")
	var req_water: int = den.get("required_water")

	if current_food < req_food or current_water < req_water:
		_show_hud_alert("Quota not met! Need %d Food & %d Water." % [req_food, req_water], 3.5)
		return

	var deposit: Dictionary = leader_body.deposit_all_items()
	var surplus_food: int = max(0, deposit["food"] - req_food)
	var surplus_water: int = max(0, deposit["water"] - req_water)
	var surviving_ants: int = leader_body.followers.size()

	var earned_points: int = (
		deposit["base_score"] +
		(surplus_food * 10) +
		(surplus_water * 10) +
		(surviving_ants * 5)
	)
	total_points += earned_points

	var audio := AudioManager.get_instance(get_tree())
	if audio != null:
		audio.play_badge()
		audio.set_walking(false)

	VFX.spawn_celebration(self, den.global_position)

	if current_round < ant_dens.size():
		var upgrade_msg := ""
		if leader_body.has_method("apply_random_upgrade"):
			upgrade_msg = leader_body.apply_random_upgrade()
		if upgrade_msg != "":
			if "Followers" in upgrade_msg:
				current_upgrade_text = "+2 Max Ants"
			elif "Capacity" in upgrade_msg:
				current_upgrade_text = "+2 Capacity/Ant"
			elif "Speed" in upgrade_msg:
				current_upgrade_text = "+Move Speed"
			else:
				current_upgrade_text = upgrade_msg
			var badge_tex := _get_badge_texture_for_upgrade(upgrade_msg)
			if upgrade_badge_icon != null and badge_tex != null:
				upgrade_badge_icon.texture = badge_tex
				upgrade_badge_icon.visible = true
			_show_upgrade_badge_popup(badge_tex, upgrade_msg)

		_setup_round(current_round + 1)
		_show_hud_alert("ROUND %d COMPLETE! (+%d Points)\nUpgrade: %s" % [current_round - 1, earned_points, upgrade_msg], 5.0)
	else:
		game_finished = true
		if closing_fog != null and closing_fog.has_method("stop"):
			closing_fog.stop()
		den.set_den_state(false, true)
		_show_reload_screen("MISSION COMPLETE!", "All Ant Dens have been supplied!", true)

func _show_hud_alert(msg: String, duration: float) -> void:
	hud_alert_message = msg
	_refresh_hud()

	if warning_board_rect != null and warning_board_label != null:
		warning_board_label.text = msg
		warning_board_rect.visible = true
		warning_board_rect.modulate.a = 0.0
		warning_board_rect.scale = Vector2(0.85, 0.85)

		if warning_tween != null and warning_tween.is_valid():
			warning_tween.kill()

		warning_tween = create_tween().set_parallel(true)
		warning_tween.tween_property(warning_board_rect, "modulate:a", 1.0, 0.25)
		warning_tween.tween_property(warning_board_rect, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if duration < 900.0:
		await get_tree().create_timer(duration).timeout
		if hud_alert_message == msg:
			hud_alert_message = ""
			_refresh_hud()
			if warning_board_rect != null and is_instance_valid(warning_board_rect):
				var hide_tw := create_tween()
				hide_tw.tween_property(warning_board_rect, "modulate:a", 0.0, 0.25)
				await hide_tw.finished
				if hud_alert_message == "" and is_instance_valid(warning_board_rect):
					warning_board_rect.visible = false

func _start_item_spawn_loop() -> void:
	await get_tree().create_timer(initial_item_delay).timeout
	if not is_inside_tree():
		return

	_on_item_spawn_timer_timeout()

	var item_timer := Timer.new()
	item_timer.wait_time = item_spawn_interval
	item_timer.autostart = true
	item_timer.timeout.connect(_on_item_spawn_timer_timeout)
	add_child(item_timer)

func _refill_cells(cells_pool: Array[Vector2i]) -> void:
	cells_pool.clear()
	for x in range(grid_columns):
		for y in range(grid_rows):
			cells_pool.append(Vector2i(x, y))
	cells_pool.shuffle()

func _get_effective_spawn_bounds() -> Rect2:
	if closing_fog != null and closing_fog.has_method("get_safe_spawn_rect"):
		return closing_fog.get_safe_spawn_rect(spawn_area_min, spawn_area_max, 350.0)
	return Rect2(spawn_area_min, spawn_area_max - spawn_area_min)

func _is_blocked_by_obstacle(pos: Vector2, radius: float = 70.0) -> bool:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return false

	var shape := CircleShape2D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if leader is CollisionObject2D:
		query.exclude = [(leader as CollisionObject2D).get_rid()]

	return not space_state.intersect_shape(query, 1).is_empty()

func _on_spawn_timer_timeout() -> void:
	if follower_scene == null or game_finished or is_game_over:
		return

	var current_count := get_tree().get_nodes_in_group("followers").size()
	var max_limit: int = leader.get("max_followers") if (leader != null and leader.get("max_followers") != null) else 5
	if current_count >= max_limit:
		return

	var spawn_pos := _get_follower_spawn_position()
	if spawn_pos == Vector2.INF:
		return

	var wild_follower := follower_scene.instantiate() as Node2D
	wild_follower.global_position = spawn_pos
	add_child(wild_follower)

func _on_item_spawn_timer_timeout() -> void:
	if item_scene == null or game_finished or is_game_over:
		return

	var current_items := get_tree().get_nodes_in_group("items").size()
	if current_items >= max_items_on_map:
		return

	var spawn_pos := _get_spaced_item_position()
	if spawn_pos == Vector2.INF:
		return

	var item_data := _pick_random_item_data().duplicate()
	item_data["texture"] = _get_item_texture(item_data["name"])

	var new_item := item_scene.instantiate() as Area2D
	new_item.global_position = spawn_pos
	if new_item.has_method("apply_data"):
		new_item.apply_data(item_data)
	add_child(new_item)

func _get_item_texture(item_name: String) -> Texture2D:
	match item_name:
		"Bread Crumb":
			return tex_bread_crumb
		"Water Droplet":
			return tex_water_droplet
		"Fruit Piece":
			return tex_fruit_piece
		"Sugar Cube":
			return tex_sugar_cube
		"Meat":
			var valid_meats: Array[Texture2D] = []
			for t in tex_meat_variants:
				if t != null:
					valid_meats.append(t)
			if not valid_meats.is_empty():
				return valid_meats.pick_random()
	return null

func _count_item_in_play(item_name: String) -> int:
	var count := 0
	for item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(item) and item.get("item_name") == item_name:
			count += 1

	if leader != null:
		var carried = leader.get("carried_items")
		if carried != null:
			for c in carried:
				if c["name"] == item_name:
					count += 1
	return count

func _pick_random_item_data() -> Dictionary:
	var pool: Array[Dictionary] = []
	var total_weight := 0
	for entry in ITEM_CATALOG:
		if entry.has("max_on_map") and _count_item_in_play(entry["name"]) >= entry["max_on_map"]:
			continue
		pool.append(entry)
		total_weight += entry["spawn_weight"]

	if pool.is_empty():
		return ITEM_CATALOG[0]

	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for entry in pool:
		cumulative += entry["spawn_weight"]
		if roll <= cumulative:
			return entry

	return pool[0]

func _get_follower_spawn_position() -> Vector2:
	var bounds := _get_effective_spawn_bounds()
	if bounds.size.x < 350.0 or bounds.size.y < 350.0:
		return Vector2.INF

	var eff_min := bounds.position
	var eff_max := bounds.end
	var cell_size := Vector2(
		bounds.size.x / float(grid_columns),
		bounds.size.y / float(grid_rows)
	)
	var padding := cell_size * 0.15

	for attempt in range(grid_columns * grid_rows):
		if available_follower_cells.is_empty():
			_refill_cells(available_follower_cells)

		var cell: Vector2i = available_follower_cells.pop_front()
		var cell_min := eff_min + Vector2(cell.x * cell_size.x, cell.y * cell_size.y) + padding
		var cell_max := cell_min + cell_size - (padding * 2.0)

		var candidate_pos := Vector2(
			randf_range(cell_min.x, cell_max.x),
			randf_range(cell_min.y, cell_max.y)
		)

		if not _is_blocked_by_obstacle(candidate_pos, follower_obstacle_clearance) and (leader == null or candidate_pos.distance_to(leader.global_position) >= min_distance_from_leader):
			return candidate_pos

	for i in range(25):
		var random_pos := Vector2(
			randf_range(eff_min.x, eff_max.x),
			randf_range(eff_min.y, eff_max.y)
		)
		if not _is_blocked_by_obstacle(random_pos, follower_obstacle_clearance) and (leader == null or random_pos.distance_to(leader.global_position) >= min_distance_from_leader):
			return random_pos

	return Vector2.INF

func _get_spaced_item_position() -> Vector2:
	var bounds := _get_effective_spawn_bounds()
	if bounds.size.x < 450.0 or bounds.size.y < 450.0:
		return Vector2.INF

	var eff_min := bounds.position
	var eff_max := bounds.end
	var cell_size := Vector2(
		bounds.size.x / float(grid_columns),
		bounds.size.y / float(grid_rows)
	)
	var padding := cell_size * 0.2

	for attempt in range(grid_columns * grid_rows):
		if available_item_cells.is_empty():
			_refill_cells(available_item_cells)

		var cell: Vector2i = available_item_cells.pop_front()
		var cell_min := eff_min + Vector2(cell.x * cell_size.x, cell.y * cell_size.y) + padding
		var cell_max := cell_min + cell_size - (padding * 2.0)

		var candidate_pos := Vector2(
			randf_range(cell_min.x, cell_max.x),
			randf_range(cell_min.y, cell_max.y)
		)

		if _is_valid_item_position(candidate_pos):
			return candidate_pos

	for i in range(30):
		var random_pos := Vector2(
			randf_range(eff_min.x, eff_max.x),
			randf_range(eff_min.y, eff_max.y)
		)
		if _is_valid_item_position(random_pos):
			return random_pos

	return Vector2.INF

func _is_valid_item_position(pos: Vector2) -> bool:
	if _is_blocked_by_obstacle(pos, item_obstacle_clearance):
		return false

	if closing_fog != null and closing_fog.has_method("is_in_fog") and closing_fog.is_in_fog(pos, 250.0):
		return false

	if leader != null and pos.distance_to(leader.global_position) < min_item_distance_from_leader:
		return false

	for existing_item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(existing_item) and pos.distance_to(existing_item.global_position) < min_distance_between_items:
			return false

	return true

func _on_inventory_updated(w: int, max_cap: int, f: int, wa: int, overweight: bool) -> void:
	ui_weight = w
	ui_max_capacity = max_cap
	ui_food = f
	ui_water = wa
	ui_overweight = overweight
	_refresh_hud()

func _on_squad_updated(curr: int, max_f: int) -> void:
	ui_followers = curr
	ui_max_followers = max_f
	_refresh_hud()

func _refresh_hud() -> void:
	var warning := " [OVERWEIGHT!]" if ui_overweight else ""

	if summary_strip_label != null:
		summary_strip_label.text = (
			"ROUND %d/%d  |  PTS: %d  |  FOOD: %d/%d  |  WATER: %d/%d  |  CAP: %d/%d%s" % [
				current_round, ant_dens.size(), total_points,
				ui_food, food_quota, ui_water, water_quota,
				ui_weight, ui_max_capacity, warning
			]
		)

	if ant_bar_label != null:
		ant_bar_label.text = "%d / %d" % [ui_followers, ui_max_followers]

	if upgrade_bar_label != null:
		upgrade_bar_label.text = current_upgrade_text

	if not resource_count_labels.is_empty():
		var counts := {
			"Bread Crumb": 0,
			"Water Droplet": 0,
			"Fruit Piece": 0,
			"Sugar Cube": 0,
			"Meat": 0
		}
		if leader != null:
			var carried = leader.get("carried_items")
			if carried != null:
				for item in carried:
					var item_name: String = item.get("name", "")
					if counts.has(item_name):
						counts[item_name] += 1

		for key in resource_count_labels.keys():
			var lbl: Label = resource_count_labels[key]
			if lbl != null:
				lbl.text = "x%d" % counts.get(key, 0)

	if status_label != null and status_label.visible:
		var alert_line := ("\n>>> %s <<<" % hud_alert_message) if hud_alert_message != "" else ""
		status_label.text = (
			"ROUND %d / %d  |  Points: %d\n" % [current_round, ant_dens.size(), total_points] +
			"Follower Ants: %d / %d\n" % [ui_followers, ui_max_followers] +
			"Capacity: %d / %d CC%s\n" % [ui_weight, ui_max_capacity, warning] +
			"Food: %d / %d  |  Water: %d / %d%s" % [ui_food, food_quota, ui_water, water_quota, alert_line]
		)

func _start_hazard_loop() -> void:
	await get_tree().create_timer(initial_hazard_delay).timeout
	while is_inside_tree() and not game_finished and not is_game_over:
		_spawn_foot()
		var idx := current_round - 1
		var wait := hazard_interval_fallback
		if idx >= 0 and idx < round_hazard_intervals.size():
			wait = round_hazard_intervals[idx]
		elif not round_hazard_intervals.is_empty():
			wait = round_hazard_intervals.back()
		await get_tree().create_timer(maxf(2.0, wait)).timeout

func _spawn_foot() -> void:
	if foot_scene == null or leader == null or leader.get("is_dead") == true:
		return

	var foot_pos := _get_foot_position()
	if foot_pos == Vector2.INF:
		return

	var foot := foot_scene.instantiate() as Node2D
	foot.add_to_group("hazards")
	foot.leader = leader

	var valid_feet: Array[Texture2D] = []
	for t in foot_textures:
		if t != null:
			valid_feet.append(t)
	if not valid_feet.is_empty():
		foot.set("foot_textures", valid_feet)
		foot.set("foot_texture", valid_feet[0])

	foot.global_position = foot_pos
	add_child(foot)

func _start_hand_loop() -> void:
	await get_tree().create_timer(initial_hand_delay).timeout
	while is_inside_tree() and not game_finished and not is_game_over:
		_spawn_hand()
		var idx := current_round - 1
		var wait := hand_interval_fallback
		if idx >= 0 and idx < round_hand_intervals.size():
			wait = round_hand_intervals[idx]
		elif not round_hand_intervals.is_empty():
			wait = round_hand_intervals.back()
		await get_tree().create_timer(maxf(3.0, wait)).timeout

func _spawn_hand() -> void:
	if hand_scene == null or leader == null or leader.get("is_dead") == true:
		return

	var hand_pos := _get_hand_position()
	if hand_pos == Vector2.INF:
		return

	var hand := hand_scene.instantiate() as Node2D
	hand.add_to_group("hazards")
	hand.leader = leader
	if charge_hand_texture != null:
		hand.set("charge_hand_texture", charge_hand_texture)
	if sweep_hand_texture != null:
		hand.set("sweep_hand_texture", sweep_hand_texture)
	hand.global_position = hand_pos
	add_child(hand)

func _get_hand_position() -> Vector2:
	var ant_targets: Array[Vector2] = []
	if not _is_invalid_hazard_pos(leader.global_position):
		ant_targets.append(leader.global_position)

	var squad: Array = leader.get("followers")
	for f in squad:
		if is_instance_valid(f) and not _is_invalid_hazard_pos(f.global_position):
			ant_targets.append(f.global_position)

	var item_targets: Array[Vector2] = []
	for item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(item) and not _is_invalid_hazard_pos(item.global_position):
			if item.global_position.distance_to(leader.global_position) <= hazard_spawn_range:
				item_targets.append(item.global_position)

	if randf() < target_ants_chance and not ant_targets.is_empty():
		var ant_pos := _pick_hand_offset(ant_targets)
		if ant_pos != Vector2.INF:
			return ant_pos

	if not item_targets.is_empty():
		var item_pos := _pick_hand_offset(item_targets)
		if item_pos != Vector2.INF:
			return item_pos

	if not ant_targets.is_empty():
		return _pick_hand_offset(ant_targets)

	return Vector2.INF

func _pick_hand_offset(bases: Array[Vector2]) -> Vector2:
	for i in range(12):
		var base: Vector2 = bases.pick_random()
		var pos := base + Vector2(randf_range(-140.0, 140.0), randf_range(-55.0, 55.0))
		if not _is_invalid_hazard_pos(pos):
			return pos
	return Vector2.INF

func _is_invalid_hazard_pos(pos: Vector2) -> bool:
	if closing_fog != null and closing_fog.has_method("is_in_fog") and closing_fog.is_in_fog(pos, 100.0):
		return true

	for h in get_tree().get_nodes_in_group("hazards"):
		if is_instance_valid(h) and pos.distance_to(h.global_position) < min_distance_between_hazards:
			return true

	return false

func _get_foot_position() -> Vector2:
	var ant_targets: Array[Vector2] = []
	if not _is_invalid_hazard_pos(leader.global_position):
		ant_targets.append(leader.global_position)

	var squad: Array = leader.get("followers")
	for f in squad:
		if is_instance_valid(f) and not _is_invalid_hazard_pos(f.global_position):
			ant_targets.append(f.global_position)

	var item_targets: Array[Vector2] = []
	for item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(item) and not _is_invalid_hazard_pos(item.global_position):
			if item.global_position.distance_to(leader.global_position) <= hazard_spawn_range:
				item_targets.append(item.global_position)

	var target_ants := randf() < target_ants_chance
	if target_ants and not ant_targets.is_empty():
		var pos := _pick_offset_position(ant_targets, 85.0)
		if pos != Vector2.INF:
			return pos

	if not item_targets.is_empty():
		var pos := _pick_offset_position(item_targets, 110.0)
		if pos != Vector2.INF:
			return pos

	if not ant_targets.is_empty():
		return _pick_offset_position(ant_targets, 85.0)

	return Vector2.INF

func _pick_offset_position(bases: Array[Vector2], max_offset: float) -> Vector2:
	for i in range(15):
		var base: Vector2 = bases.pick_random()
		var candidate := base + Vector2(randf_range(-max_offset, max_offset), randf_range(-max_offset, max_offset))
		if not _is_invalid_hazard_pos(candidate):
			return candidate
	return Vector2.INF
