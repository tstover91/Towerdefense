class_name EnergyCoreAttackComponent
extends TowerAttackComponent

const SHOCKWAVE_VISUAL_DURATION := 0.3
const BRANCH_VISUAL_DURATION := 0.12

var shockwave_enabled := false
var shockwave_cooldown := 5.0
var shockwave_remaining := 0.0
var shockwave_damage_multiplier := 0.35
var shockwave_stun_duration := 1.0
var shockwave_visual_remaining := 0.0
var branching_current_enabled := false
var branch_additional_targets := 1
var branch_range_pixels := 0.0
var branch_damage_multiplier := 0.25
var branch_visual_segments: Array[Dictionary] = []
var branch_visual_remaining := 0.0
var previous_shockwave_remaining := 0.0


func reset_path_behaviors() -> void:
	previous_shockwave_remaining = shockwave_remaining
	shockwave_enabled = false
	shockwave_cooldown = 5.0
	shockwave_damage_multiplier = 0.35
	shockwave_stun_duration = 1.0
	branching_current_enabled = false
	branch_additional_targets = 1
	branch_range_pixels = 0.0
	branch_damage_multiplier = 0.25


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("energy_shockwave", false):
		shockwave_enabled = true
		shockwave_cooldown = maxf(
			float(values.get("shockwave_cooldown", 5.0)),
			0.1
		)
		shockwave_damage_multiplier = maxf(
			float(values.get("shockwave_damage_multiplier", 0.35)),
			0.0
		)
		shockwave_stun_duration = maxf(
			float(values.get("shockwave_stun_duration", 1.0)),
			0.0
		)
	if flags.get("energy_branching_current", false):
		branching_current_enabled = true
		branch_additional_targets = maxi(
			int(values.get("branch_additional_targets", 1)),
			0
		)
		branch_range_pixels = (
			maxf(float(values.get("branch_range", 4.0)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		branch_damage_multiplier = clampf(
			float(values.get("branch_damage_multiplier", 0.25)),
			0.0,
			1.0
		)


func finalize_path_behaviors() -> void:
	if shockwave_enabled:
		shockwave_remaining = (
			minf(previous_shockwave_remaining, shockwave_cooldown)
			if previous_shockwave_remaining > 0.0
			else shockwave_cooldown
		)
	else:
		shockwave_remaining = 0.0
	previous_shockwave_remaining = 0.0


func on_round_started() -> void:
	if shockwave_enabled:
		shockwave_remaining = shockwave_cooldown


func on_round_ended() -> void:
	shockwave_remaining = shockwave_cooldown
	shockwave_visual_remaining = 0.0
	tower.queue_redraw()


func process_attack(delta: float) -> void:
	_process_visuals(delta)
	if not shockwave_enabled or not tower.is_placed:
		return
	if not tower.is_combat_active():
		return
	shockwave_remaining = maxf(shockwave_remaining - delta, 0.0)
	if shockwave_remaining > 0.0:
		return
	_trigger_shockwave_if_possible()


func _process_visuals(delta: float) -> void:
	if branch_visual_remaining > 0.0:
		branch_visual_remaining = maxf(branch_visual_remaining - delta, 0.0)
		if branch_visual_remaining <= 0.0:
			branch_visual_segments.clear()
		tower.queue_redraw()
	if shockwave_visual_remaining > 0.0:
		shockwave_visual_remaining = maxf(
			shockwave_visual_remaining - delta,
			0.0
		)
		tower.queue_redraw()


func _trigger_shockwave_if_possible() -> void:
	var affected_mobs: Array[Node2D] = []
	var has_targetable_mob := false
	for mob in tower.tower_area.get_overlapping_bodies():
		if not tower.is_valid_area_target(mob):
			continue
		affected_mobs.append(mob)
		if tower.is_valid_target(mob):
			has_targetable_mob = true
	# Hidden enemies can be caught in the pulse, but cannot trigger it alone
	# when Energy Core lacks Reveal.
	if not has_targetable_mob:
		return
	shockwave_remaining = shockwave_cooldown
	shockwave_visual_remaining = SHOCKWAVE_VISUAL_DURATION
	tower.queue_redraw()
	var shockwave_damage := tower.roll_critical_damage(
		maxi(roundi(float(tower.damage) * shockwave_damage_multiplier), 1)
	)
	var shockwave_context := tower.create_attack_context(
		&"energy_shockwave", null, &"tower", null, false, true
	)
	shockwave_context.metadata["area_damage"] = true
	for mob in affected_mobs:
		if mob.has_method("apply_stun"):
			mob.apply_stun(
				shockwave_stun_duration,
				tower.stun_affects_bosses,
				shockwave_context
			)
		tower.apply_tower_damage(
			mob,
			shockwave_damage,
			tower.damage_type,
			false,
			shockwave_context
		)


func draw_attack_visuals() -> void:
	_draw_shockwave()
	_draw_branches()


func _draw_shockwave() -> void:
	if shockwave_visual_remaining <= 0.0:
		return
	var progress_ratio := 1.0 - clampf(
		shockwave_visual_remaining / SHOCKWAVE_VISUAL_DURATION,
		0.0,
		1.0
	)
	var visual_radius := tower.range_radius_pixels * progress_ratio
	tower.draw_circle(Vector2.ZERO, visual_radius, Color(0.2, 0.8, 1.0, 0.10))
	tower.draw_arc(
		Vector2.ZERO,
		visual_radius,
		0.0,
		TAU,
		64,
		Color(0.35, 0.9, 1.0, 0.9),
		3.0,
		true
	)


func _draw_branches() -> void:
	if branch_visual_remaining <= 0.0:
		return
	for segment in branch_visual_segments:
		tower.draw_line(
			tower.to_local(segment["start"]),
			tower.to_local(segment["end"]),
			Color(0.35, 0.9, 1.0, 0.95),
			2.5,
			true
		)


func execute_attack(current_target: Node2D, attack_damage: int) -> bool:
	branch_visual_segments.clear()
	var primary_targets := _get_primary_targets(current_target)
	var volley_context := tower.create_attack_context(
		&"electric_volley", null, &"tower", null, false, true
	)
	var primary_strikes: Array[Dictionary] = []
	for primary_target in primary_targets:
		var primary_context := tower.create_attack_context(
			&"electric_primary", tower, &"tower", volley_context, false
		)
		branch_visual_segments.append({
			"start": tower.muzzle.global_position,
			"end": primary_target.global_position,
		})
		tower.apply_control_effects(primary_target, primary_context)
		tower.apply_tower_damage(
			primary_target,
			attack_damage,
			tower.damage_type,
			false,
			primary_context
		)
		primary_strikes.append({
			"target": primary_target,
			"context": primary_context,
		})
	if branching_current_enabled:
		var excluded_branch_ids: Dictionary = {}
		for primary_strike in primary_strikes:
			excluded_branch_ids[primary_strike["target"].get_instance_id()] = true
		for primary_strike in primary_strikes:
			_apply_branches(
				primary_strike["target"],
				attack_damage,
				primary_strike["context"],
				excluded_branch_ids
			)
	branch_visual_remaining = BRANCH_VISUAL_DURATION
	tower.queue_redraw()
	return true


func _get_primary_targets(current_target: Node2D) -> Array[Node2D]:
	var primary_targets: Array[Node2D] = [current_target]
	var excluded_ids: Dictionary = {current_target.get_instance_id(): true}
	while primary_targets.size() < tower.projectile_count:
		var next_target := _get_preferred_primary_target(excluded_ids)
		if next_target == null:
			break
		primary_targets.append(next_target)
		excluded_ids[next_target.get_instance_id()] = true
	return primary_targets


func _get_preferred_primary_target(excluded_ids: Dictionary) -> Node2D:
	var selected_target: Node2D
	for candidate in tower.mobs_in_range:
		if (
			not tower.is_valid_target(candidate)
			or excluded_ids.has(candidate.get_instance_id())
		):
			continue
		if selected_target == null or _is_target_preferred(candidate, selected_target):
			selected_target = candidate
	return selected_target


func _is_target_preferred(candidate: Node2D, selected_target: Node2D) -> bool:
	match tower.target_mode:
		BaseTower.TargetMode.FIRST:
			return candidate.path_follow.progress > selected_target.path_follow.progress
		BaseTower.TargetMode.LAST:
			return candidate.path_follow.progress < selected_target.path_follow.progress
		BaseTower.TargetMode.LOWEST_HEALTH:
			return candidate.health < selected_target.health
		BaseTower.TargetMode.HIGHEST_HEALTH:
			return candidate.health > selected_target.health
	return false


func _apply_branches(
	primary_target: Node2D,
	attack_damage: int,
	primary_context: AttackContext,
	excluded_ids: Dictionary
) -> void:
	var branch_damage := maxi(
		roundi(float(attack_damage) * branch_damage_multiplier),
		1
	)
	for _branch_index in branch_additional_targets:
		var branch_target := _get_nearest_branch_target(
			primary_target.global_position,
			excluded_ids
		)
		if branch_target == null:
			break
		excluded_ids[branch_target.get_instance_id()] = true
		var branch_context := tower.create_attack_context(
			&"electric_branch", tower, &"tower", primary_context, true
		)
		tower.apply_control_effects(branch_target, branch_context)
		tower.apply_tower_damage(
			branch_target,
			branch_damage,
			tower.damage_type,
			false,
			branch_context
		)
		branch_visual_segments.append({
			"start": primary_target.global_position,
			"end": branch_target.global_position,
		})


func _get_nearest_branch_target(
	origin: Vector2,
	excluded_ids: Dictionary
) -> Node2D:
	var nearest_target: Node2D
	var nearest_distance := INF
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if (
			not tower.is_valid_target(candidate)
			or excluded_ids.has(candidate.get_instance_id())
		):
			continue
		var candidate_distance: float = origin.distance_to(candidate.global_position)
		if candidate_distance > branch_range_pixels:
			continue
		if candidate_distance < nearest_distance:
			nearest_distance = candidate_distance
			nearest_target = candidate
	return nearest_target
