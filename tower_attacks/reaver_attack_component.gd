class_name ReaverAttackComponent
extends TowerAttackComponent

const AreaDamage = preload("res://area_damage_helper.gd")
const SECONDARY_SWEEP_DAMAGE_MULTIPLIER := 0.75

var melee_arc_degrees := 120.0
var melee_max_targets := 2
var assassinate_enabled := false
var assassinate_attack_interval := 3
var assassinate_critical_multiplier_bonus := 0.0
var assassinate_attack_counter := 0
var champion_enabled := false
var champion_spin_interval := 4
var champion_spin_damage_multiplier := 1.5
var champion_spin_radius_multiplier := 1.0
var champion_spin_max_targets := 8
var champion_attack_counter := 0
var enforcer_enabled := false
var enforcer_slam_interval := 4
var enforcer_slam_radius_units := 2.5
var enforcer_slam_max_targets := 8
var enforcer_secondary_damage_multiplier := 0.75
var enforcer_stun_duration := 0.5
var enforcer_push_distance_units := 1.0
var enforcer_attack_counter := 0
var time_bubble_enabled := false
var time_bubble_active_duration := 3.0
var time_bubble_cooldown := 7.0
var time_bubble_refresh_interval := 0.20
var time_bubble_slow_duration := 0.30
var time_bubble_active_remaining := 0.0
var time_bubble_cooldown_remaining := 0.0
var time_bubble_refresh_remaining := 0.0
var sweep_visual_remaining := 0.0
var sweep_visual_direction := Vector2.RIGHT
var sweep_visual_arc_degrees := 120.0
var sweep_visual_radius := 0.0
var roaming_enabled := false
var roaming_move_speed := 80.0
var melee_attack_radius_pixels := 48.0
var roaming_offset := Vector2.ZERO


func load_level_stats(stats: Dictionary) -> void:
	melee_arc_degrees = clampf(float(stats.get("melee_arc_degrees", 120.0)), 0.0, 360.0)
	melee_max_targets = maxi(int(stats.get("melee_max_targets", 1)), 1)
	roaming_move_speed = maxf(float(stats.get("roaming_move_speed", 80.0)), 0.0)
	melee_attack_radius_pixels = maxf(
		float(stats.get("melee_attack_radius", 1.5)) * BaseTower.BUILD_CELL_SIZE,
		1.0
	)


func reset_path_behaviors() -> void:
	assassinate_enabled = false
	assassinate_attack_interval = 3
	assassinate_critical_multiplier_bonus = 0.0
	champion_enabled = false
	champion_spin_interval = 4
	champion_spin_damage_multiplier = 1.5
	champion_spin_radius_multiplier = 1.0
	champion_spin_max_targets = 8
	enforcer_enabled = false
	enforcer_slam_interval = 4
	enforcer_slam_radius_units = 2.5
	enforcer_slam_max_targets = 8
	enforcer_secondary_damage_multiplier = 0.75
	enforcer_stun_duration = 0.5
	enforcer_push_distance_units = 1.0
	time_bubble_enabled = false
	roaming_enabled = false


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("reaver_roaming", false):
		roaming_enabled = true
	if flags.get("reaver_time_bubble", false):
		time_bubble_enabled = true
		time_bubble_active_duration = maxf(
			float(values.get("time_bubble_active_duration", 3.0)), 0.1
		)
		time_bubble_cooldown = maxf(
			float(values.get("time_bubble_cooldown", 7.0)), 0.1
		)
		time_bubble_refresh_interval = maxf(
			float(values.get("time_bubble_refresh_interval", 0.20)), 0.05
		)
		time_bubble_slow_duration = maxf(
			float(values.get("time_bubble_slow_duration", 0.30)), 0.05
		)
	if flags.get("reaver_assassinate", false):
		assassinate_enabled = true
		assassinate_attack_interval = maxi(int(values.get("assassinate_attack_interval", 3)), 1)
		assassinate_critical_multiplier_bonus = maxf(float(values.get("assassinate_critical_multiplier_bonus", 0.0)), 0.0)
	if flags.get("reaver_champion", false):
		champion_enabled = true
		champion_spin_interval = maxi(int(values.get("champion_spin_interval", 4)), 1)
		champion_spin_damage_multiplier = maxf(float(values.get("champion_spin_damage_multiplier", 1.5)), 0.0)
		champion_spin_radius_multiplier = maxf(float(values.get("champion_spin_radius_multiplier", 1.0)), 0.1)
		champion_spin_max_targets = maxi(int(values.get("champion_spin_max_targets", 8)), 1)
	if flags.get("reaver_enforcer", false):
		enforcer_enabled = true
		enforcer_slam_interval = maxi(int(values.get("enforcer_slam_interval", 4)), 1)
		enforcer_slam_radius_units = maxf(float(values.get("enforcer_slam_radius", 2.5)), 0.1)
		enforcer_slam_max_targets = maxi(int(values.get("enforcer_slam_max_targets", 8)), 1)
		enforcer_secondary_damage_multiplier = maxf(float(values.get("enforcer_secondary_damage_multiplier", 0.75)), 0.0)
		enforcer_stun_duration = maxf(float(values.get("enforcer_stun_duration", 0.5)), 0.0)
		enforcer_push_distance_units = maxf(float(values.get("enforcer_push_distance", 1.0)), 0.0)


func on_placement_confirmed() -> void:
	_apply_roaming_offset(Vector2.ZERO)


func process_pre_targeting(delta: float) -> void:
	if not roaming_enabled or not tower.is_placed:
		return
	var destination := Vector2.ZERO
	if tower.is_valid_target(tower.target):
		var target_offset := tower.target.global_position - tower.global_position
		if target_offset.length() <= tower.range_radius_pixels:
			destination = target_offset
			var current_distance := get_combat_origin().distance_to(
				tower.target.global_position
			)
			if current_distance <= melee_attack_radius_pixels * 0.72:
				destination = roaming_offset
	var maximum_offset := maxf(
		tower.range_radius_pixels - melee_attack_radius_pixels * 0.25,
		0.0
	)
	if destination.length() > maximum_offset:
		destination = destination.normalized() * maximum_offset
	_apply_roaming_offset(
		roaming_offset.move_toward(destination, roaming_move_speed * delta)
	)


func _apply_roaming_offset(new_offset: Vector2) -> void:
	roaming_offset = new_offset
	if is_instance_valid(tower.visual_sprite):
		tower.visual_sprite.position = roaming_offset
	if is_instance_valid(tower.rotator):
		tower.rotator.position = roaming_offset
	tower.queue_redraw()


func get_combat_origin() -> Vector2:
	return tower.global_position + roaming_offset


func process_attack(delta: float) -> void:
	_process_time_bubble(delta)
	if sweep_visual_remaining <= 0.0:
		return
	sweep_visual_remaining = maxf(sweep_visual_remaining - delta, 0.0)
	tower.queue_redraw()


func on_round_started() -> void:
	if time_bubble_enabled:
		time_bubble_active_remaining = time_bubble_active_duration
		time_bubble_cooldown_remaining = 0.0
		time_bubble_refresh_remaining = 0.0


func on_round_ended() -> void:
	time_bubble_active_remaining = 0.0
	time_bubble_cooldown_remaining = 0.0
	time_bubble_refresh_remaining = 0.0


func _process_time_bubble(delta: float) -> void:
	if not time_bubble_enabled or not tower.is_combat_active():
		return
	if time_bubble_active_remaining > 0.0:
		time_bubble_active_remaining = maxf(time_bubble_active_remaining - delta, 0.0)
		time_bubble_refresh_remaining = maxf(time_bubble_refresh_remaining - delta, 0.0)
		if time_bubble_refresh_remaining <= 0.0:
			time_bubble_refresh_remaining = time_bubble_refresh_interval
			var context := tower.create_attack_context(&"reaver_time_bubble")
			for candidate in AreaDamage.get_targets_near(
				tower.get_tree(), get_combat_origin(), tower.range_radius_pixels
			):
				if tower.is_valid_area_target(candidate) and candidate.has_method("apply_slow"):
					candidate.apply_slow(time_bubble_slow_duration, context)
		if time_bubble_active_remaining <= 0.0:
			time_bubble_cooldown_remaining = time_bubble_cooldown
		tower.queue_redraw()
		return
	time_bubble_cooldown_remaining = maxf(time_bubble_cooldown_remaining - delta, 0.0)
	if time_bubble_cooldown_remaining <= 0.0:
		time_bubble_active_remaining = time_bubble_active_duration
		time_bubble_refresh_remaining = 0.0

func draw_attack_visuals() -> void:
	if time_bubble_active_remaining > 0.0 and tower.is_placed:
		tower.draw_circle(
			roaming_offset,
			tower.range_radius_pixels,
			Color(0.48, 0.88, 0.78, 0.10)
		)
		tower.draw_arc(
			roaming_offset,
			tower.range_radius_pixels,
			0.0,
			TAU,
			64,
			Color(0.62, 1.0, 0.88, 0.60),
			2.0,
			true
		)
	if sweep_visual_remaining <= 0.0 or not tower.is_placed:
		return
	var alpha := clampf(sweep_visual_remaining / 0.14, 0.0, 1.0)
	var color := Color(1.0, 0.76, 0.30, 0.72 * alpha)
	if sweep_visual_arc_degrees >= 359.9:
		tower.draw_arc(roaming_offset, sweep_visual_radius, 0.0, TAU, 64, color, 4.0, true)
		return
	var center_angle := sweep_visual_direction.angle()
	var half_angle := deg_to_rad(sweep_visual_arc_degrees * 0.5)
	tower.draw_arc(roaming_offset, sweep_visual_radius, center_angle - half_angle, center_angle + half_angle, 32, color, 4.0, true)


func execute_raw_attack(current_target: Node2D, base_damage: int) -> bool:
	if not tower.is_valid_target(current_target):
		return false
	var combat_origin := get_combat_origin()
	if roaming_enabled and combat_origin.distance_to(current_target.global_position) > melee_attack_radius_pixels:
		return true
	var attack_direction := (current_target.global_position - combat_origin).normalized()
	if assassinate_enabled:
		return _execute_assassin_attack(current_target, base_damage, attack_direction)
	if champion_enabled:
		champion_attack_counter += 1
		if champion_attack_counter >= champion_spin_interval:
			champion_attack_counter = 0
			return _execute_champion_spin(current_target, base_damage, attack_direction)
	if enforcer_enabled:
		enforcer_attack_counter += 1
		if enforcer_attack_counter >= enforcer_slam_interval:
			enforcer_attack_counter = 0
			return _execute_enforcer_slam(current_target, base_damage, attack_direction)
	return _execute_sweep(current_target, base_damage, attack_direction)


func _execute_assassin_attack(current_target: Node2D, base_damage: int, attack_direction: Vector2) -> bool:
	assassinate_attack_counter += 1
	var is_assassinate := assassinate_attack_counter >= assassinate_attack_interval
	if is_assassinate:
		assassinate_attack_counter = 0
	_apply_direct_hit(current_target, base_damage, &"reaver_assassinate" if is_assassinate else &"reaver_strike", is_assassinate, assassinate_critical_multiplier_bonus if is_assassinate else 0.0)
	_show_sweep(attack_direction, 18.0, melee_attack_radius_pixels)
	return true


func _execute_sweep(current_target: Node2D, base_damage: int, attack_direction: Vector2) -> bool:
	var targets := _get_arc_targets(current_target, get_combat_origin(), attack_direction, melee_attack_radius_pixels, melee_arc_degrees, melee_max_targets)
	for target_index in targets.size():
		var target_damage := (
			base_damage if target_index == 0
			else maxi(roundi(
				float(base_damage) * SECONDARY_SWEEP_DAMAGE_MULTIPLIER
			), 1)
		)
		_apply_direct_hit(targets[target_index], target_damage, &"reaver_sweep", false, 0.0, target_index > 0)
	_show_sweep(attack_direction, melee_arc_degrees, melee_attack_radius_pixels)
	return true


func _execute_champion_spin(current_target: Node2D, base_damage: int, attack_direction: Vector2) -> bool:
	var radius := melee_attack_radius_pixels * champion_spin_radius_multiplier
	var targets := _get_radial_targets(current_target, get_combat_origin(), radius, champion_spin_max_targets)
	var spin_damage := maxi(roundi(float(base_damage) * champion_spin_damage_multiplier), 1)
	for target_index in targets.size():
		_apply_direct_hit(targets[target_index], spin_damage, &"reaver_champion_spin", false, 0.0, target_index > 0)
	_show_sweep(attack_direction, 360.0, radius)
	return true


func _execute_enforcer_slam(current_target: Node2D, base_damage: int, attack_direction: Vector2) -> bool:
	var radius := enforcer_slam_radius_units * BaseTower.BUILD_CELL_SIZE
	var targets := _get_radial_targets(current_target, current_target.global_position, radius, enforcer_slam_max_targets)
	for target_index in targets.size():
		var target := targets[target_index] as Node2D
		var target_damage := base_damage if target_index == 0 else maxi(roundi(float(base_damage) * enforcer_secondary_damage_multiplier), 1)
		var hit_context := _create_hit_context(target, target_damage, &"reaver_enforcer_slam", false, 0.0, target_index > 0)
		_apply_enforcer_control(target, hit_context)
		tower.apply_hitscan_damage(target, int(hit_context.metadata["rolled_damage"]), hit_context)
	_show_sweep(attack_direction, 360.0, radius)
	return true


func _apply_enforcer_control(target: Node2D, hit_context: AttackContext) -> void:
	if target.has_method("apply_stun"):
		target.apply_stun(enforcer_stun_duration, tower.stun_affects_bosses, hit_context)
	if not target.has_method("apply_backward_displacement"):
		return
	var displacement_multiplier := 1.0
	var traits: Array = target.get("traits") as Array
	if traits.has(&"boss"):
		displacement_multiplier = 0.25
	elif traits.has(&"elite"):
		displacement_multiplier = 0.60
	target.apply_backward_displacement(enforcer_push_distance_units * BaseTower.BUILD_CELL_SIZE * displacement_multiplier, hit_context)


func _apply_direct_hit(target: Node2D, base_damage: int, attack_kind: StringName, guaranteed_critical := false, critical_multiplier_bonus := 0.0, secondary := false) -> void:
	var hit_context := _create_hit_context(target, base_damage, attack_kind, guaranteed_critical, critical_multiplier_bonus, secondary)
	tower.apply_hitscan_damage(target, int(hit_context.metadata["rolled_damage"]), hit_context)


func _create_hit_context(target: Node2D, base_damage: int, attack_kind: StringName, guaranteed_critical: bool, critical_multiplier_bonus: float, secondary: bool) -> AttackContext:
	var rolled_damage: int
	if guaranteed_critical:
		rolled_damage = tower.roll_guaranteed_critical_damage(base_damage)
		if critical_multiplier_bonus > 0.0 and not tower.last_attack_roll_missed:
			rolled_damage += roundi(float(base_damage) * critical_multiplier_bonus * tower.get_death_ray_damage_multiplier())
	else:
		rolled_damage = tower.roll_critical_damage(base_damage, target)
	var context := tower.create_attack_context(attack_kind, null, &"tower", null, secondary, true)
	context.metadata["rolled_damage"] = rolled_damage
	return context


func _get_arc_targets(primary_target: Node2D, origin: Vector2, direction: Vector2, radius: float, arc_degrees: float, maximum_targets: int) -> Array[Node2D]:
	if arc_degrees <= 0.0 or maximum_targets <= 1:
		return [primary_target]
	var minimum_dot := cos(deg_to_rad(minf(arc_degrees, 360.0) * 0.5))
	var candidates: Array[Node2D] = []
	for candidate in AreaDamage.get_targets_near(tower.get_tree(), origin, radius):
		if not tower.is_valid_target(candidate):
			continue
		var candidate_node := candidate as Node2D
		var offset := candidate_node.global_position - origin
		if offset.length_squared() > radius * radius:
			continue
		if arc_degrees < 359.9 and offset.normalized().dot(direction) < minimum_dot:
			continue
		candidates.append(candidate_node)
	return _prioritize_targets(primary_target, candidates, origin, maximum_targets)


func _get_radial_targets(primary_target: Node2D, origin: Vector2, radius: float, maximum_targets: int) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	for candidate in AreaDamage.get_targets_near(tower.get_tree(), origin, radius):
		if not tower.is_valid_target(candidate):
			continue
		var candidate_node := candidate as Node2D
		if origin.distance_squared_to(candidate_node.global_position) <= radius * radius:
			candidates.append(candidate_node)
	return _prioritize_targets(primary_target, candidates, origin, maximum_targets)


func _prioritize_targets(primary_target: Node2D, candidates: Array[Node2D], origin: Vector2, maximum_targets: int) -> Array[Node2D]:
	candidates.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		return origin.distance_squared_to(left.global_position) < origin.distance_squared_to(right.global_position)
	)
	var result: Array[Node2D] = [primary_target]
	for candidate in candidates:
		if candidate == primary_target:
			continue
		result.append(candidate)
		if result.size() >= maximum_targets:
			break
	return result


func _show_sweep(direction: Vector2, arc_degrees: float, radius: float) -> void:
	sweep_visual_remaining = 0.14
	sweep_visual_direction = direction if not direction.is_zero_approx() else Vector2.RIGHT
	sweep_visual_arc_degrees = arc_degrees
	sweep_visual_radius = radius
	tower.queue_redraw()
