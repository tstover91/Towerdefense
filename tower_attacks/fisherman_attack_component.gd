class_name FishermanAttackComponent
extends TowerAttackComponent

const FISHERMAN_HOOK_EFFECT = preload("res://fisherman_hook_effect.gd")
const FISHERMAN_MINE_SCENE = preload("res://fisherman_mine.tscn")
const DEFAULT_TRACKING_CONE_DEGREES := 60.0

var hook_tick_count := 4
var hook_duration := 1.2
var hook_pull_speed := 80.0
var hook_pull_immunity := 2.5
var tracking_cone_degrees := DEFAULT_TRACKING_CONE_DEGREES
var hook_target_count := 1
var secondary_hook_damage_multiplier := 1.0
var electric_tether_enabled := false
var tether_half_width_pixels := 0.0
var tether_secondary_damage_multiplier := 0.0
var tether_maximum_targets := 0
var tether_final_pulse_multiplier := 1.0
var mines_enabled := false
var mine_interval := 6.0
var mine_remaining := 0.0
var mine_maximum_count := 3
var mine_placement_radius_pixels := 0.0
var mine_trigger_radius_pixels := 0.0
var mine_explosion_radius_pixels := 0.0
var mine_damage_multiplier := 1.0
var mine_chain_reaction_radius_pixels := 0.0
var mine_chain_damage_multiplier := 1.0
var active_mines: Array[Node] = []
var previous_mine_remaining := 0.0


func uses_directional_aim() -> bool:
	return true


func uses_tracking_cone() -> bool:
	return true


func uses_finite_directional_range() -> bool:
	return true


func get_tracking_cone_degrees() -> float:
	return tracking_cone_degrees


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
	var half_angle_radians := deg_to_rad(tracking_cone_degrees * 0.5)
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
	tracking_cone_degrees = DEFAULT_TRACKING_CONE_DEGREES
	hook_target_count = 1
	secondary_hook_damage_multiplier = 1.0
	electric_tether_enabled = false
	tether_half_width_pixels = 0.0
	tether_secondary_damage_multiplier = 0.0
	tether_maximum_targets = 0
	tether_final_pulse_multiplier = 1.0
	mines_enabled = false
	mine_interval = 6.0
	mine_maximum_count = 3
	mine_placement_radius_pixels = 0.0
	mine_trigger_radius_pixels = 0.0
	mine_explosion_radius_pixels = 0.0
	mine_damage_multiplier = 1.0
	mine_chain_reaction_radius_pixels = 0.0
	mine_chain_damage_multiplier = 1.0


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("fisherman_multi_hook", false):
		hook_target_count = maxi(int(values.get("hook_target_count", 2)), 1)
		secondary_hook_damage_multiplier = maxf(
			float(values.get("secondary_hook_damage_multiplier", 0.70)), 0.0
		)
		tracking_cone_degrees = clampf(
			float(values.get("tracking_cone_degrees", 75.0)), 1.0, 180.0
		)
	if flags.get("fisherman_electric_tether", false):
		electric_tether_enabled = true
		tether_half_width_pixels = maxf(
			float(values.get("tether_half_width", 0.75)), 0.0
		) * BaseTower.BUILD_CELL_SIZE
		tether_secondary_damage_multiplier = maxf(
			float(values.get("tether_secondary_damage_multiplier", 0.50)), 0.0
		)
		tether_maximum_targets = maxi(
			int(values.get("tether_maximum_targets", 4)), 0
		)
		tether_final_pulse_multiplier = maxf(
			float(values.get("tether_final_pulse_multiplier", 1.0)), 0.0
		)
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
	mine_chain_reaction_radius_pixels = maxf(
		float(values.get("mine_chain_reaction_radius", 0.0)), 0.0
	) * BaseTower.RANGE_PIXELS_PER_UNIT
	mine_chain_damage_multiplier = maxf(
		float(values.get("mine_chain_damage_multiplier", 1.0)), 0.0
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
	var hook_targets := _get_hook_targets(current_target)
	for target_index in hook_targets.size():
		var hook_target := hook_targets[target_index]
		var hook_damage := (
			attack_damage
			if target_index == 0
			else maxi(roundi(float(attack_damage) * secondary_hook_damage_multiplier), 1)
		)
		_cast_hook(hook_target, hook_damage, cast_context, target_index > 0)
	return true


func _cast_hook(
	hook_target: Node2D,
	hook_damage: int,
	cast_context: AttackContext,
	secondary: bool
) -> void:
	var hook_context := tower.create_attack_context(
		&"fisherman_hook", tower, &"tower", cast_context, secondary
	)
	tower.apply_control_effects(hook_target, hook_context)
	var hook_effect := FISHERMAN_HOOK_EFFECT.new()
	tower.get_tree().current_scene.add_child(hook_effect)
	hook_effect.setup(
		tower,
		hook_target,
		hook_damage,
		tower.damage_type,
		false,
		hook_tick_count,
		hook_duration,
		hook_pull_speed,
		hook_pull_immunity,
		true,
		electric_tether_enabled,
		hook_context,
		tether_half_width_pixels,
		tether_secondary_damage_multiplier,
		tether_maximum_targets,
		tether_final_pulse_multiplier
	)


func _get_hook_targets(primary_target: Node2D) -> Array[Node2D]:
	var result: Array[Node2D] = [primary_target]
	if hook_target_count <= 1:
		return result
	var candidates: Array[Node2D] = []
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if candidate != primary_target and is_target_in_tracking_cone(candidate):
			candidates.append(candidate)
	candidates.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		match tower.target_mode:
			BaseTower.TargetMode.LAST:
				return left.path_follow.progress < right.path_follow.progress
			BaseTower.TargetMode.LOWEST_HEALTH:
				return left.health < right.health
			BaseTower.TargetMode.HIGHEST_HEALTH:
				return left.health > right.health
			_:
				return left.path_follow.progress > right.path_follow.progress
	)
	for candidate in candidates:
		result.append(candidate)
		if result.size() >= hook_target_count:
			break
	return result


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
		tower.create_attack_context(&"fisherman_mine_explosion", mine, &"mine"),
		mine_chain_reaction_radius_pixels,
		mine_chain_damage_multiplier
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
