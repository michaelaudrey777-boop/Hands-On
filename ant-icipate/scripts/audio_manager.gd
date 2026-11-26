class_name AudioManager
extends Node

@export_group("Music & Ambience")
@export var main_theme: AudioStream
@export var main_theme_volume_db: float = -4.0
@export var backyard_ambience: AudioStream
@export var backyard_ambience_volume_db: float = -8.0

@export_group("Item Pickups")
@export var bread_crumb_pickup: AudioStream
@export var water_droplet_pickup: AudioStream
@export var fruit_slice_pickup: AudioStream
@export var sugar_cube_pickup: AudioStream
@export var meat_pickup: AudioStream

@export_group("Movement, Squad & UI")
@export var walking_sfx: AudioStream
@export var walking_volume_db: float = -6.0
@export var getting_hit_sfx: AudioStream
@export var badge_sfx: AudioStream
@export var button_sfx: AudioStream

@export_group("Hazards")
@export var foot_stomp_sfx: AudioStream
@export var hand_swoop_sfx: AudioStream
@export var map_blown_off_sfx: AudioStream
@export var max_hearing_distance: float = 2400.0

var bgm_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var walk_player: AudioStreamPlayer
var leader_ref: Node2D = null

static func get_instance(tree: SceneTree) -> AudioManager:
	if tree == null:
		return null
	return tree.get_first_node_in_group("audio_manager") as AudioManager

func _ready() -> void:
	add_to_group("audio_manager")
	leader_ref = get_tree().current_scene.find_child("AntLeader", true, false) as Node2D

	bgm_player = _create_loop_player("BGMPlayer", main_theme, main_theme_volume_db)
	ambience_player = _create_loop_player("AmbiencePlayer", backyard_ambience, backyard_ambience_volume_db)

	walk_player = AudioStreamPlayer.new()
	walk_player.name = "WalkLoopPlayer"
	walk_player.stream = walking_sfx
	walk_player.volume_db = walking_volume_db
	walk_player.finished.connect(func() -> void:
		if walk_player.stream != null and walk_player.get_meta("should_walk", false):
			walk_player.play()
	)
	add_child(walk_player)

func _create_loop_player(node_name: String, stream: AudioStream, vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.stream = stream
	p.volume_db = vol_db
	p.finished.connect(func() -> void:
		if p.stream != null and is_inside_tree():
			p.play()
	)
	add_child(p)
	if stream != null:
		p.play()
	return p

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if stream == null or not is_inside_tree():
		return

	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	if pitch_jitter > 0.0:
		p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func play_spatial_sfx(stream: AudioStream, world_pos: Vector2, base_volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if stream == null:
		return
	var atten_db := 0.0
	if world_pos != Vector2.INF and leader_ref != null and is_instance_valid(leader_ref):
		var dist := leader_ref.global_position.distance_to(world_pos)
		var ratio := clampf(dist / maxf(1.0, max_hearing_distance), 0.0, 1.0)
		atten_db = lerpf(0.0, -20.0, ratio)
	play_sfx(stream, base_volume_db + atten_db, pitch_jitter)

func play_item_pickup(item_name: String) -> void:
	match item_name:
		"Bread Crumb":
			play_sfx(bread_crumb_pickup, 0.0, 0.08)
		"Water Droplet":
			play_sfx(water_droplet_pickup, 0.0, 0.08)
		"Fruit Piece":
			play_sfx(fruit_slice_pickup, 0.0, 0.06)
		"Sugar Cube":
			play_sfx(sugar_cube_pickup, 0.0, 0.05)
		"Meat":
			play_sfx(meat_pickup, 0.0, 0.05)
		_:
			play_sfx(bread_crumb_pickup, 0.0, 0.08)

func set_walking(is_walking: bool, is_huddling: bool = false) -> void:
	if walk_player == null or walk_player.stream == null:
		return

	walk_player.set_meta("should_walk", is_walking)
	walk_player.pitch_scale = 0.85 if is_huddling else 1.0

	if is_walking:
		if not walk_player.playing:
			walk_player.play()
	else:
		if walk_player.playing:
			walk_player.stop()

func play_getting_hit() -> void:
	play_sfx(getting_hit_sfx, 1.0, 0.07)

func play_badge() -> void:
	play_sfx(badge_sfx, 1.5, 0.0)

func play_button() -> void:
	play_sfx(button_sfx, 0.0, 0.03)

func play_foot_stomp(world_pos: Vector2 = Vector2.INF) -> void:
	play_spatial_sfx(foot_stomp_sfx, world_pos, 2.0, 0.06)

func play_hand_swoop(world_pos: Vector2 = Vector2.INF) -> void:
	play_spatial_sfx(hand_swoop_sfx, world_pos, 1.5, 0.05)

func play_map_blown_off() -> void:
	play_sfx(map_blown_off_sfx, 1.0, 0.0)

func set_bgm_dimmed(dimmed: bool) -> void:
	if bgm_player == null or bgm_player.stream == null:
		return
	var target_db := (main_theme_volume_db - 9.0) if dimmed else main_theme_volume_db
	var tw := create_tween()
	tw.tween_property(bgm_player, "volume_db", target_db, 0.6)
