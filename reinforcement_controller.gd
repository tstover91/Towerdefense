class_name ReinforcementController
extends RefCounted

const GameStats = preload("res://stat_database.gd")
const ReinforcementDropScript = preload("res://reinforcement_drop.gd")
const ReinforcementDropPreviewScript = preload("res://reinforcement_drop_preview.gd")

var host: Node
var position_validator: Callable
var selected_reinforcement_id: StringName = &"grunt_squad"
var cooldown_remaining := 0.0
var targeting := false
var preview: Node2D


func _init(scene_host: Node = null, validator: Callable = Callable()) -> void:
	host = scene_host
	position_validator = validator


func configure(scene_host: Node, validator: Callable) -> void:
	host = scene_host
	position_validator = validator


func get_selected_option() -> Dictionary:
	return GameStats.get_reinforcement_option(selected_reinforcement_id)


func can_begin_targeting(
	game_ended: bool,
	round_active: bool,
	shop_open: bool,
	build_mode: bool,
	selecting_path_relic_tower: bool
) -> bool:
	return (
		not game_ended
		and round_active
		and not shop_open
		and not build_mode
		and not selecting_path_relic_tower
		and cooldown_remaining <= 0.0
		and not targeting
	)


func process_cooldown(delta: float, can_recover: bool) -> bool:
	if not can_recover or cooldown_remaining <= 0.0:
		return false
	var previous_seconds := ceili(cooldown_remaining)
	cooldown_remaining = maxf(cooldown_remaining - maxf(delta, 0.0), 0.0)
	return ceili(cooldown_remaining) != previous_seconds


func update_preview(world_position: Vector2) -> void:
	if targeting and is_instance_valid(preview):
		preview.set_preview_position(world_position, is_valid_drop_position(world_position))


func begin_targeting() -> bool:
	if targeting or cooldown_remaining > 0.0 or host == null:
		return false
	targeting = true
	var option := get_selected_option()
	preview = ReinforcementDropPreviewScript.new()
	host.add_child(preview)
	preview.configure(
		float(option.get("command_radius", 1.0))
		* ReinforcementDropScript.RANGE_PIXELS_PER_UNIT
	)
	return true


func cancel_targeting() -> bool:
	var was_targeting := targeting or is_instance_valid(preview)
	targeting = false
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	return was_targeting


func is_valid_drop_position(world_position: Vector2) -> bool:
	return position_validator.is_valid() and bool(position_validator.call(world_position))


func deploy(world_position: Vector2, wave_number: int) -> bool:
	if not targeting or host == null or not is_valid_drop_position(world_position):
		return false
	var option := get_selected_option()
	var drop := ReinforcementDropScript.new() as ReinforcementDrop
	host.add_child(drop)
	drop.global_position = world_position
	drop.setup(option, maxi(wave_number, 1))
	cooldown_remaining = maxf(float(option.get("cooldown", 0.0)), 0.0)
	cancel_targeting()
	return true


func clear_drops() -> void:
	if host == null or not host.is_inside_tree():
		return
	for drop in host.get_tree().get_nodes_in_group("reinforcement_drops"):
		if is_instance_valid(drop):
			drop.queue_free()
