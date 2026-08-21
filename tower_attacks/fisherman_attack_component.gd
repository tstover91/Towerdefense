class_name FishermanAttackComponent
extends TowerAttackComponent

const FISHERMAN_HOOK_EFFECT = preload("res://fisherman_hook_effect.gd")
const FISHERMAN_MINE_SCENE = preload("res://fisherman_mine.tscn")
const TRACKING_CONE_DEGREES := 60.0

var hook_tick_count := 4
var hook_duration := 1.2
var hook_pull_speed := 80.0
var hook_pull_immunity := 2.5
var electric_line_enabled := false
var mines_enabled := false
var mine_interval := 6.0
var mine_remaining := 0.0
var mine_maximum_count := 3
var mine_placement_radius_pixels := 0.0
var mine_trigger_radius_pixels := 0.0
var mine_explosion_radius_pixels := 0.0
var mine_damage_multiplier := 1.0
var active_mines: Array[Node] = []
var previous_mine_remaining := 0.0


func uses_directional_aim() -> bool:
	return true


func uses_tracking_cone() -> bool:
	return true


func uses_finite_directional_range() -> bool:
	return true


func get_tracking_cone_degrees() -> float:
	return TRACKING_CONE_DEGREES


func is_target_in_tracking_cone(candidate: Variant) -> bool:
	if not tower.is_valid_target(candidate):
		return false
	if (
		tower.global_position.distance_to(candidate.global_position)
		> tower.range_radius_pixels
	):
		return false
	var offset: Vector2 = candidate.global_position - tower.muzzle.global_position
	if offset.is_zero_approx():
		return true
	var half_angle_radians := deg_to_rad(TRACKING_CONE_DEGREES * 0.5)
	return offset.normalized().dot(tower.aim_direction) >= cos(half_angle_radians)


func select_directional_target() -> Node2D:
	var candidates: Array[Node2D] = []
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if is_target_in_tracking_cone(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		return null
	var selected_target := candidates[0]
	for candidate in candidates:
		match tower.target_mode:
			BaseTower.TargetMode.FIRST:
				if candidate.path_follow.progress > selected_target.path_follow.progress:
					selected_target = candidate
			BaseTower.TargetMode.LAST:
				if candidate.path_follow.progress < selected_target.path_follow.progress:
					selected_target = candidate
			BaseTower.TargetMode.LOWEST_HEALTH:
				if candidate.health < selected_target.health:
					selected_target = candidate
			BaseTower.TargetMode.HIGHEST_HEALTH:
				if candidate.health > selected_target.health:
					selected_target = candidate
	return selected_target


func load_level_stats(stats: Dictionary) -> void:
	hook_tick_count = maxi(int(stats.get("hook_tick_count", 4)), 1)
	hook_duration = maxf(float(stats.get("hook_duration", 1.2)), 0.01)
	hook_pull_speed = maxf(float(stats.get("hook_pull_speed", 80.0)), 0.0)
	hook_pull_immunity = maxf(float(stats.get("hook_pull_immunity", 2.5)), 0.0)


func reset_path_behaviors() -> void:
	previous_mine_remaining = mine_remaining
	electric_line_enabled = false
	mines_enabled = false
	mine_interval = 6.0
	mine_maximum_count = 3
	mine_placement_radius_pixels = 0.0
	mine_trigger_radius_pixels = 0.0
	mine_explosion_radius_pixels = 0.0
	mine_damage_multiplier = 1.0


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("fisherman_electric_line", false):
		electric_line_enabled = true
	if not flags.get("fisherman_mines", false):
		return
	mines_enabled = true
	mine_interval = maxf(float(values.get("mine_interval", 6.0)), 0.1)
	mine_maximum_count = maxi(int(values.get("mine_maximum_count", 3)), 1)
	mine_placement_radius_pixels = (
		maxf(float(values.get("mine_placement_radius", 6.0)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	mine_trigger_radius_pixels = (
		maxf(float(values.get("mine_trigger_radius", 1.0)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	mine_explosion_radius_pixels = (
		maxf(float(values.get("mine_explosion_radius", 2.5)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	mine_damage_multiplier = maxf(
		float(values.get("mine_damage_multiplier", 1.25)), 0.0
	)


func finalize_path_behaviors() -> void:
	if mines_enabled and tower.has_damage_tag(BaseTower.DAMAGE_EXPLOSIVE):
		if tower.get_primary_damage_type() != BaseTower.DAMAGE_EXPLOSIVE:
			mine_damage_multiplier *= tower.get_explosion_damage_multiplier()
		mine_explosion_radius_pixels *= tower.get_explosion_radius_multiplier()
		mine_interval *= tower.get_explosion_interval_multiplier()
	if mines_enabled:
		mine_remaining = (
			minf(previous_mine_remaining, mine_interval)
			if previous_mine_remaining > 0.0
			else mine_interval
		)
	else:
		mine_remaining = 0.0
	previous_mine_remaining = 0.0


func on_round_started() -> void:
	if mines_enabled:
		mine_remaining = mine_interval


func on_round_ended() -> void:
	clear_mines()
	mine_remaining = mine_interval


func _exit_tree() -> void:
	clear_mines()


func process_attack(delta: float) -> void:
	if not mines_enabled or not tower.is_placed:
		return
	if not tower.is_combat_active():
		return
	prune_mines()
	if active_mines.size() >= mine_maximum_count:
		return
	mine_remaining = maxf(mine_remaining - delta, 0.0)
	if mine_remaining > 0.0:
		return
	mine_remaining = mine_interval
	place_mine()


func execute_attack(current_target: Node2D, attack_damage: int) -> bool:
	if not tower.is_valid_target(current_target):
		return true
	var cast_context := tower.create_attack_context(
		&"fisherman_cast", tower, &"tower", null, false, true
	)
	var hook_context := tower.create_attack_context(
		&"fisherman_hook", tower, &"tower", cast_context
	)
	tower.apply_control_effects(current_target, hook_context)
	var hook_effect := FISHERMAN_HOOK_EFFECT.new()
	tower.get_tree().current_scene.add_child(hook_effect)
	hook_effect.setup(
		tower,
		current_target,
		attack_damage,
		tower.damage_type,
		false,
		hook_tick_count,
		hook_duration,
		hook_pull_speed,
		hook_pull_immunity,
		true,
		electric_line_enabled,
		hook_context
	)
	return true


func place_mine() -> void:
	if (
		tower.main == null
		or not tower.main.has_method("get_path_cell_positions_near")
		or FISHERMAN_MINE_SCENE == null
		or tower.get_tree().current_scene == null
	):
		return
	var candidates: Array = tower.main.get_path_cell_positions_near(
		tower.global_position, mine_placement_radius_pixels
	)
	for mine in active_mines:
		if not is_instance_valid(mine):
			continue
		candidates = candidates.filter(
			func(candidate_position: Vector2) -> bool:
				return candidate_position.distance_to(mine.global_position) > 1.0
		)
	if candidates.is_empty():
		return
	var mine_position: Vector2 = candidates[
		tower.spawn_rng.randi_range(0, candidates.size() - 1)
	]
	var mine := FISHERMAN_MINE_SCENE.instantiate() as Node2D
	tower.get_tree().current_scene.add_child(mine)
	mine.global_position = mine_position
	mine.setup(
		tower.main,
		maxi(roundi(float(tower.damage) * mine_damage_multiplier), 1),
		mine_trigger_radius_pixels,
		mine_explosion_radius_pixels,
		tower.create_attack_context(&"fisherman_mine_explosion", mine, &"mine")
	)
	mine.detonated.connect(_on_mine_detonated)
	active_mines.append(mine)


func _on_mine_detonated(mine: Node2D) -> void:
	active_mines.erase(mine)
	mine_remaining = mine_interval


func prune_mines() -> void:
	active_mines = active_mines.filter(
		func(mine: Node) -> bool:
			return is_instance_valid(mine) and not mine.is_queued_for_deletion()
	)


func clear_mines() -> void:
	for mine in active_mines:
		if is_instance_valid(mine):
			mine.queue_free()
	active_mines.clear()
