class_name InvaderLaserAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const DEFAULT_BEAM_DURATION := 1.0
const DEFAULT_TICK_INTERVAL := 0.25

var enabled := false
var beam_duration := DEFAULT_BEAM_DURATION
var tick_interval := DEFAULT_TICK_INTERVAL
var charge_remaining := 0.0
var charge_duration := 0.0
var beam_remaining := 0.0
var tick_remaining := 0.0
var locked_direction := Vector2.RIGHT
var locked_endpoint := Vector2.ZERO
var snapshotted_tick_damage := 0


func uses_shared_attack_scheduler() -> bool:
	return false


func locks_aim_during_attack() -> bool:
	return beam_remaining > 0.0


func reset_path_behaviors() -> void:
	enabled = false
	beam_duration = DEFAULT_BEAM_DURATION
	tick_interval = DEFAULT_TICK_INTERVAL


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if not flags.get("charged_laser_burst", false):
		return
	enabled = true
	beam_duration = maxf(
		float(values.get("laser_duration", DEFAULT_BEAM_DURATION)), 0.05
	)
	tick_interval = maxf(
		float(values.get("laser_tick_interval", DEFAULT_TICK_INTERVAL)), 0.05
	)


func on_round_ended() -> void:
	_cancel_attack()


func process_attack(delta: float) -> void:
	if not enabled or not tower.is_placed or not tower.is_combat_active():
		return
	if beam_remaining > 0.0:
		_process_active_beam(delta)
		return
	if charge_remaining > 0.0:
		_process_charge(delta)
		return
	if tower.is_valid_target(tower.target) and tower.mobs_in_range.has(tower.target):
		charge_duration = maxf(tower.get_current_attack_interval(), 0.05)
		charge_remaining = charge_duration
		tower.queue_redraw()


func draw_attack_visuals() -> void:
	if charge_remaining > 0.0:
		var progress := 1.0 - charge_remaining / maxf(charge_duration, 0.01)
		var charge_radius := lerpf(6.0, 15.0, clampf(progress, 0.0, 1.0))
		tower.draw_arc(
			tower.to_local(tower.muzzle.global_position),
			charge_radius,
			0.0,
			TAU,
			24,
			Color(0.2, 0.85, 1.0, 0.9),
			2.5,
			true
		)
	if beam_remaining <= 0.0:
		return
	var start := tower.to_local(tower.muzzle.global_position)
	var finish := tower.to_local(locked_endpoint)
	var width := tower.beam_hit_half_width_pixels
	tower.draw_line(
		start, finish, Color(0.1, 0.55, 1.0, 0.35), width * 2.4, true
	)
	tower.draw_line(
		start, finish, Color(0.75, 0.95, 1.0, 0.95), width, true
	)


func _process_charge(delta: float) -> void:
	charge_remaining = maxf(charge_remaining - delta, 0.0)
	tower.queue_redraw()
	if charge_remaining > 0.0:
		return
	if not tower.is_valid_target(tower.target) or not tower.mobs_in_range.has(tower.target):
		return
	var aim_offset := tower.target.global_position - tower.muzzle.global_position
	if aim_offset.is_zero_approx():
		return
	locked_direction = aim_offset.normalized()
	locked_endpoint = tower.target.global_position
	tower.rotator.rotation = locked_direction.angle()
	tower.notify_attack_started(tower.target)
	var prepared_damage := tower.damage
	if tower.item_controller != null:
		prepared_damage = maxi(roundi(
			float(prepared_damage)
			* tower.item_controller.get_pending_attack_damage_multiplier()
		), 1)
	var tick_count := maxi(ceili(beam_duration / tick_interval), 1)
	snapshotted_tick_damage = maxi(roundi(
		float(prepared_damage) / float(tick_count)
	), 1)
	beam_remaining = beam_duration
	tick_remaining = tick_interval
	tower.queue_redraw()


func _process_active_beam(delta: float) -> void:
	beam_remaining = maxf(beam_remaining - delta, 0.0)
	tick_remaining -= delta
	while tick_remaining <= 0.0:
		_apply_beam_tick()
		tick_remaining += tick_interval
		if beam_remaining <= 0.0:
			break
	tower.rotator.rotation = locked_direction.angle()
	tower.queue_redraw()
	if beam_remaining <= 0.0:
		snapshotted_tick_damage = 0


func _apply_beam_tick() -> void:
	if snapshotted_tick_damage <= 0:
		return
	var origin := tower.muzzle.global_position
	var line_end := locked_endpoint
	var targets := tower.get_targets_along_line(
		origin, line_end, null, tower.beam_hit_half_width_pixels
	)
	targets = _select_targets_before_endpoint(targets)
	var rolled_damage := tower.roll_critical_damage(snapshotted_tick_damage)
	var tick_context := tower.create_attack_context(
		&"charged_laser_tick", null, &"tower", null, false, true
	)
	for index in targets.size():
		var target := targets[index]
		tower.apply_control_effects(target, tick_context)
		tower.apply_tower_damage(
			target,
			_get_beam_target_damage(rolled_damage, index, targets.size()),
			&"beam",
			index > 0,
			tick_context
		)


func _get_beam_target_damage(
	base_damage: int,
	hit_index: int,
	target_count: int
) -> int:
	# The selected endpoint is always appended last. Earlier enemies consume
	# Pierce falloff, while the enemy the tower aimed at receives full damage.
	if hit_index == target_count - 1:
		return base_damage
	return GameStats.get_piercing_damage(
		base_damage, hit_index, tower.pierce_loses_no_power
	)


func _select_targets_before_endpoint(targets: Array[Node2D]) -> Array[Node2D]:
	if tower.infinite_pierce or targets.size() <= 1 + tower.pierce_count:
		return targets
	var selected: Array[Node2D] = []
	# Pierce slots are consumed from the muzzle outward. The final hit is
	# reserved for the enemy nearest the snapshotted endpoint so the beam still
	# reaches the target it was charged toward.
	for index in mini(tower.pierce_count, targets.size() - 1):
		selected.append(targets[index])
	var endpoint_target: Node2D = targets.back()
	if not selected.has(endpoint_target):
		selected.append(endpoint_target)
	return selected


func _cancel_attack() -> void:
	charge_remaining = 0.0
	beam_remaining = 0.0
	tick_remaining = 0.0
	locked_endpoint = Vector2.ZERO
	snapshotted_tick_damage = 0
	tower.queue_redraw()
