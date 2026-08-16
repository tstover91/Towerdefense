class_name GaussRepeaterAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")

var maximum_spread_degrees := 0.0
var minimum_spread_degrees := 0.0
var current_spread_degrees := 0.0
var spread_tighten_per_shot := 0.0
var spread_tighten_duration := 0.0
var spread_recovery_delay := 0.0
var spread_recovery_per_second := 0.0
var time_without_target := 0.0
var spread_initialized := false
var overclock_enabled := false
var overclock_elapsed := 0.0
var overclock_max_speed_bonus := 0.0
var overclock_ramp_duration := 3.0
var overclock_decay_duration := 1.0
var heavy_shot_enabled := false
var heavy_shot_interval := 0.0
var heavy_shot_remaining := 0.0
var heavy_shot_damage_multiplier := 1.0
var heavy_shot_speed_multiplier := 1.0
var tracking_cone_enabled := false
var tracking_cone_degrees := 45.0
var previous_heavy_shot_remaining := 0.0


func uses_directional_aim() -> bool:
	return true


func load_level_stats(stats: Dictionary) -> void:
	maximum_spread_degrees = maxf(
		float(stats.get("maximum_spread_degrees", 0.0)), 0.0
	)
	minimum_spread_degrees = clampf(
		float(stats.get("minimum_spread_degrees", 0.0)),
		0.0,
		maximum_spread_degrees
	)
	spread_tighten_duration = maxf(
		float(stats.get("spread_tighten_duration", 0.0)), 0.0
	)
	spread_tighten_per_shot = 0.0
	if spread_tighten_duration > 0.0:
		spread_tighten_per_shot = (
			(maximum_spread_degrees - minimum_spread_degrees)
			* float(stats.get("firerate", 1.0))
			/ spread_tighten_duration
		)
	spread_recovery_delay = maxf(
		float(stats.get("spread_recovery_delay", 0.0)), 0.0
	)
	spread_recovery_per_second = maxf(
		float(stats.get("spread_recovery_per_second", 0.0)), 0.0
	)
	overclock_enabled = bool(stats.get("gauss_overclock_enabled", false))
	overclock_max_speed_bonus = maxf(
		float(stats.get("gauss_overclock_max_speed_bonus", 0.0)), 0.0
	)
	overclock_ramp_duration = maxf(
		float(stats.get("gauss_overclock_ramp_duration", 3.0)), 0.01
	)
	overclock_decay_duration = maxf(
		float(stats.get("gauss_overclock_decay_duration", 1.0)), 0.01
	)
	if not overclock_enabled:
		overclock_elapsed = 0.0
	else:
		overclock_elapsed = minf(overclock_elapsed, overclock_ramp_duration)
	if not spread_initialized:
		current_spread_degrees = maximum_spread_degrees
		spread_initialized = true
	else:
		current_spread_degrees = clampf(
			current_spread_degrees,
			minimum_spread_degrees,
			maximum_spread_degrees
		)


func reset_path_behaviors() -> void:
	previous_heavy_shot_remaining = heavy_shot_remaining
	heavy_shot_enabled = false
	heavy_shot_interval = 0.0
	heavy_shot_damage_multiplier = 1.0
	heavy_shot_speed_multiplier = 1.0
	tracking_cone_enabled = false
	tracking_cone_degrees = 45.0


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("gauss_heavy_shot", false):
		heavy_shot_enabled = true
		heavy_shot_interval = maxf(
			float(values.get("heavy_shot_interval", 4.0)), 0.1
		)
		heavy_shot_damage_multiplier = maxf(
			float(values.get("heavy_shot_damage_multiplier", 3.0)), 1.0
		)
		heavy_shot_speed_multiplier = maxf(
			float(values.get("heavy_shot_speed_multiplier", 0.60)), 0.1
		)
	if flags.get("gauss_tracking_cone", false):
		tracking_cone_enabled = true
		tracking_cone_degrees = clampf(
			float(values.get("tracking_cone_degrees", 45.0)), 1.0, 180.0
		)


func finalize_path_behaviors() -> void:
	if heavy_shot_enabled:
		heavy_shot_remaining = (
			minf(previous_heavy_shot_remaining, heavy_shot_interval)
			if previous_heavy_shot_remaining > 0.0
			else heavy_shot_interval
		)
	else:
		heavy_shot_remaining = 0.0
	previous_heavy_shot_remaining = 0.0


func on_round_started() -> void:
	overclock_elapsed = 0.0
	if heavy_shot_enabled:
		heavy_shot_remaining = heavy_shot_interval


func on_round_ended() -> void:
	overclock_elapsed = 0.0


func on_aim_direction_changed() -> void:
	reset_spread()
	overclock_elapsed = 0.0


func modify_attack_interval(base_interval: float) -> float:
	if not overclock_enabled or overclock_elapsed <= 0.0:
		return base_interval
	var overclock_progress := clampf(
		overclock_elapsed / overclock_ramp_duration, 0.0, 1.0
	)
	return base_interval / (1.0 + overclock_max_speed_bonus * overclock_progress)


func uses_tracking_cone() -> bool:
	return tracking_cone_enabled


func get_tracking_cone_degrees() -> float:
	return tracking_cone_degrees


func is_target_in_tracking_cone(candidate: Variant) -> bool:
	if not tower.is_valid_target(candidate):
		return false
	var offset: Vector2 = candidate.global_position - tower.muzzle.global_position
	if offset.is_zero_approx():
		return true
	var half_angle_radians := deg_to_rad(tracking_cone_degrees * 0.5)
	return offset.normalized().dot(tower.aim_direction) >= cos(half_angle_radians)


func select_directional_target() -> Node2D:
	var selected_target: Node2D
	var highest_health := -1
	var highest_progress := -INF
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if not is_target_in_tracking_cone(candidate):
			continue
		var candidate_health := int(candidate.health)
		var candidate_progress := float(candidate.path_follow.progress)
		if (
			candidate_health > highest_health
			or (
				candidate_health == highest_health
				and candidate_progress > highest_progress
			)
		):
			highest_health = candidate_health
			highest_progress = candidate_progress
			selected_target = candidate
	return selected_target


func process_attack(delta: float) -> void:
	_process_spread(delta)
	_process_overclock(delta)
	_process_heavy_shot(delta)


func execute_attack(current_target: Node2D, attack_damage: int) -> bool:
	if tower.projectile_scene == null or not tower.is_valid_target(current_target):
		return true
	var base_shot_direction := tower.aim_direction
	if tracking_cone_enabled:
		var target_offset := current_target.global_position - tower.muzzle.global_position
		if not target_offset.is_zero_approx():
			base_shot_direction = target_offset.normalized()
	var spread_offset_degrees := tower.spawn_rng.randf_range(
		-current_spread_degrees, current_spread_degrees
	)
	var projectile_direction := base_shot_direction.rotated(
		deg_to_rad(spread_offset_degrees)
	)
	var maximum_distance := tower.get_max_distance_in_direction(
		projectile_direction, tower.muzzle.global_position
	)
	var destination := (
		tower.muzzle.global_position + projectile_direction * maximum_distance
	)
	current_spread_degrees = maxf(
		current_spread_degrees - spread_tighten_per_shot,
		minimum_spread_degrees
	)
	time_without_target = 0.0
	tower.launch_projectile_from_position(
		current_target,
		tower.muzzle.global_position,
		destination,
		maximum_distance,
		attack_damage,
		0.0
	)
	return true


func _process_overclock(delta: float) -> void:
	if not overclock_enabled or not tower.is_placed:
		overclock_elapsed = 0.0
		return
	if tower.main == null or not tower.main.round_active:
		overclock_elapsed = 0.0
		return
	if tower.is_valid_target(tower.target):
		overclock_elapsed = minf(
			overclock_elapsed + delta, overclock_ramp_duration
		)
		return
	var decay_rate := overclock_ramp_duration / overclock_decay_duration
	overclock_elapsed = maxf(overclock_elapsed - decay_rate * delta, 0.0)


func _process_spread(delta: float) -> void:
	if not tower.is_placed:
		return
	if tower.is_valid_target(tower.target):
		time_without_target = 0.0
		return
	var previous_time_without_target := time_without_target
	time_without_target += delta
	var recovery_delta := (
		maxf(time_without_target - spread_recovery_delay, 0.0)
		- maxf(previous_time_without_target - spread_recovery_delay, 0.0)
	)
	if recovery_delta <= 0.0:
		return
	current_spread_degrees = minf(
		current_spread_degrees + spread_recovery_per_second * recovery_delta,
		maximum_spread_degrees
	)


func _process_heavy_shot(delta: float) -> void:
	if not heavy_shot_enabled or not tower.is_placed:
		return
	if tower.main == null or not tower.main.round_active:
		return
	heavy_shot_remaining = maxf(heavy_shot_remaining - delta, 0.0)
	if heavy_shot_remaining > 0.0 or not tower.is_valid_target(tower.target):
		return
	_launch_heavy_shot()
	heavy_shot_remaining = heavy_shot_interval


func _launch_heavy_shot() -> void:
	if tower.projectile_scene == null or not tower.is_valid_target(tower.target):
		return
	var shot_direction := tower.aim_direction
	if tracking_cone_enabled:
		var target_offset := tower.target.global_position - tower.muzzle.global_position
		if not target_offset.is_zero_approx():
			shot_direction = target_offset.normalized()
	var maximum_distance := tower.get_max_distance_in_direction(
		shot_direction, tower.muzzle.global_position
	)
	var destination := tower.muzzle.global_position + shot_direction * maximum_distance
	var heavy_projectile := tower.projectile_scene.instantiate() as TowerProjectile
	tower.get_tree().current_scene.add_child(heavy_projectile)
	heavy_projectile.global_position = tower.muzzle.global_position
	heavy_projectile.setup(
		tower.target,
		destination,
		tower.projectile_speed * heavy_shot_speed_multiplier,
		maximum_distance,
		maxi(roundi(float(tower.roll_attack_damage(tower.target)) * heavy_shot_damage_multiplier), 1),
		tower.damage_type,
		GameStats.IMPACT_FIRST_CONTACT,
		0.0,
		tower.pierce_count,
		tower.slow_duration,
		tower.stun_duration,
		tower.stun_affects_bosses,
		0,
		0.0,
		false,
		0.0,
		true,
		tower.has_bonus_tag(BaseTower.BONUS_REVEAL),
		tower.tower_id,
		false,
		tower.pierce_loses_no_power,
		1.0,
		tower.create_attack_context(
			&"gauss_heavy_shot", heavy_projectile, &"projectile"
		)
	)


func reset_spread() -> void:
	current_spread_degrees = maximum_spread_degrees
	time_without_target = 0.0
