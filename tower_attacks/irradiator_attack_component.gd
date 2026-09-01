class_name IrradiatorAttackComponent
extends TowerAttackComponent

const AreaDamage = preload("res://area_damage_helper.gd")
const RADIATION_TICK_INTERVAL := 1.0
const FIELD_COLOR := Color(0.64, 0.95, 0.10, 0.13)
const EDGE_COLOR := Color(0.82, 1.0, 0.18, 0.82)

var cone_degrees := 60.0
var stacks_per_application := 1
var application_remaining := 0.0
var reactor_enabled := false
var reactor_radius_pixels := 0.0
var reactor_application_interval := 0.75
var decay_suppressor_enabled := false
var last_application_count := 0
var total_reactor_applications := 0


func uses_shared_attack_scheduler() -> bool:
	return false


func shows_target_mode_control() -> bool:
	return not reactor_enabled


func load_level_stats(stats: Dictionary) -> void:
	cone_degrees = maxf(float(stats.get("radiation_cone_degrees", 60.0)), 1.0)
	stacks_per_application = maxi(
		int(stats.get("radiation_stacks_per_application", 1)), 1
	)


func reset_path_behaviors() -> void:
	reactor_enabled = false
	decay_suppressor_enabled = false
	reactor_radius_pixels = 0.0
	reactor_application_interval = 0.75


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if bool(flags.get("irradiator_decay_suppressor", false)):
		decay_suppressor_enabled = true
	if not bool(flags.get("irradiator_reactor", false)):
		return
	reactor_enabled = true
	reactor_radius_pixels = (
		maxf(float(values.get("reactor_radius", 4.5)), 0.1)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	reactor_application_interval = maxf(
		float(values.get("reactor_application_interval", 0.75)), 0.05
	)
	stacks_per_application = maxi(
		int(values.get("reactor_stacks_per_application", stacks_per_application)), 1
	)


func finalize_path_behaviors() -> void:
	application_remaining = minf(application_remaining, _get_application_interval())
	tower.queue_redraw()


func on_round_started() -> void:
	application_remaining = 0.0


func on_round_ended() -> void:
	application_remaining = 0.0
	last_application_count = 0
	tower.queue_redraw()


func process_attack(delta: float) -> void:
	if not tower.is_placed or not tower.is_combat_active():
		return
	application_remaining = maxf(application_remaining - delta, 0.0)
	if application_remaining > 0.0:
		return
	var affected := _get_reactor_targets() if reactor_enabled else _get_cone_targets()
	if affected.is_empty():
		return
	application_remaining = _get_application_interval()
	last_application_count = affected.size()
	if not reactor_enabled:
		tower.notify_attack_started(tower.target)
	var attack_kind: StringName = (
		&"reactor_exposure" if reactor_enabled else &"irradiator_cone"
	)
	var context := tower.create_attack_context(attack_kind)
	context.metadata["radiation_application"] = true
	context.metadata["area_damage"] = true
	for mob in affected:
		if not mob.has_method("apply_radiation"):
			continue
		mob.apply_radiation(
			stacks_per_application,
			maxi(tower.damage, 1),
			context,
			RADIATION_TICK_INTERVAL
		)
		if reactor_enabled:
			total_reactor_applications += stacks_per_application
	tower.queue_redraw()


func draw_attack_visuals() -> void:
	if reactor_enabled:
		tower.draw_circle(Vector2.ZERO, reactor_radius_pixels, FIELD_COLOR)
		tower.draw_arc(
			Vector2.ZERO, reactor_radius_pixels, 0.0, TAU,
			64, EDGE_COLOR, 2.0, true
		)
		return
	if not tower.is_placed or not tower.is_combat_active() or tower.target == null:
		return
	var direction := tower.global_position.direction_to(tower.target.global_position)
	var half_angle := deg_to_rad(cone_degrees) * 0.5
	var left := direction.rotated(-half_angle) * tower.range_radius_pixels
	var right := direction.rotated(half_angle) * tower.range_radius_pixels
	var points := PackedVector2Array([Vector2.ZERO, left, right])
	tower.draw_colored_polygon(points, Color(0.65, 1.0, 0.12, 0.10))
	tower.draw_line(Vector2.ZERO, left, EDGE_COLOR, 1.5, true)
	tower.draw_line(Vector2.ZERO, right, EDGE_COLOR, 1.5, true)


func get_radiation_debug_state() -> Dictionary:
	return {
		"mode": &"reactor" if reactor_enabled else &"cone",
		"application_interval": _get_application_interval(),
		"last_application_count": last_application_count,
		"total_reactor_applications": total_reactor_applications,
		"reactor_radius_pixels": reactor_radius_pixels,
		"cone_degrees": cone_degrees,
	}


func _get_application_interval() -> float:
	return reactor_application_interval if reactor_enabled else tower.loaded_attack_interval


func _get_reactor_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for candidate in AreaDamage.get_targets_near(
		tower.get_tree(), tower.global_position, reactor_radius_pixels
	):
		if not tower.is_valid_area_target(candidate):
			continue
		if tower.global_position.distance_to(candidate.global_position) <= reactor_radius_pixels:
			targets.append(candidate as Node2D)
	return targets


func _get_cone_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if not tower.is_valid_target(tower.target):
		return targets
	var aim_direction := tower.global_position.direction_to(tower.target.global_position)
	var minimum_dot := cos(deg_to_rad(cone_degrees) * 0.5)
	for candidate in AreaDamage.get_targets_near(
		tower.get_tree(), tower.global_position, tower.range_radius_pixels
	):
		if not tower.is_valid_area_target(candidate):
			continue
		var offset: Vector2 = candidate.global_position - tower.global_position
		if offset.length() > tower.range_radius_pixels or offset.is_zero_approx():
			continue
		if aim_direction.dot(offset.normalized()) >= minimum_dot:
			targets.append(candidate as Node2D)
	return targets


func suppresses_radiation_decay_for(candidate: Node2D) -> bool:
	if (
		not decay_suppressor_enabled
		or not tower.is_placed
		or not tower.is_combat_active()
		or not tower.is_valid_area_target(candidate)
		or not tower.is_valid_target(tower.target)
	):
		return false
	var offset := candidate.global_position - tower.global_position
	if offset.is_zero_approx() or offset.length() > tower.range_radius_pixels:
		return false
	var aim_direction := tower.global_position.direction_to(
		tower.target.global_position
	)
	var minimum_dot := cos(deg_to_rad(cone_degrees) * 0.5)
	return aim_direction.dot(offset.normalized()) >= minimum_dot
