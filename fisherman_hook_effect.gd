class_name FishermanHookEffect
extends Node2D

const AreaDamage = preload("res://area_damage_helper.gd")

const MINIMUM_VISUAL_DURATION := 0.15

var source_tower: BaseTower
var hooked_target: Node2D
var total_damage := 0
var damage_type: StringName = &"melee"
var ignores_armor := false
var tick_count := 4
var duration := 1.2
var pull_speed := 80.0
var can_pull := false
var pull_immunity_duration := 2.5
var pull_released := false
var electric_line := false
var tether_half_width := 0.0
var tether_secondary_damage_multiplier := 0.0
var tether_maximum_targets := 0
var tether_final_pulse_multiplier := 1.0
var attack_context: AttackContext
var elapsed := 0.0
var ticks_applied := 0
var tick_interval := 0.4
var cached_line_start_world := Vector2.ZERO
var cached_line_end_world := Vector2.ZERO
var has_cached_line := false


func setup(
	attack_source: BaseTower,
	target: Node2D,
	attack_damage: int,
	attack_damage_type: StringName,
	attack_ignores_armor: bool,
	attack_tick_count: int,
	attack_duration: float,
	attack_pull_speed: float,
	pull_immunity_duration: float,
	attack_can_pull: bool,
	is_electric: bool,
	parent_context: AttackContext,
	attack_tether_half_width := 0.0,
	attack_tether_secondary_damage_multiplier := 0.0,
	attack_tether_maximum_targets := 0,
	attack_tether_final_pulse_multiplier := 1.0
) -> void:
	source_tower = attack_source
	hooked_target = target
	total_damage = maxi(attack_damage, 1)
	damage_type = attack_damage_type
	ignores_armor = attack_ignores_armor
	tick_count = maxi(attack_tick_count, 1)
	duration = maxf(attack_duration, 0.01)
	pull_speed = maxf(attack_pull_speed, 0.0)
	self.pull_immunity_duration = maxf(pull_immunity_duration, 0.0)
	electric_line = is_electric
	tether_half_width = maxf(attack_tether_half_width, 0.0)
	tether_secondary_damage_multiplier = maxf(
		attack_tether_secondary_damage_multiplier, 0.0
	)
	tether_maximum_targets = maxi(attack_tether_maximum_targets, 0)
	tether_final_pulse_multiplier = maxf(
		attack_tether_final_pulse_multiplier, 0.0
	)
	attack_context = parent_context
	tick_interval = duration / float(maxi(tick_count - 1, 1))
	z_index = 12
	z_as_relative = false
	_cache_live_line_endpoints()
	if attack_can_pull and hooked_target.has_method("try_begin_fisherman_pull"):
		can_pull = hooked_target.try_begin_fisherman_pull(
			pull_immunity_duration,
			pull_speed * duration
		)
	_apply_damage_tick()
	queue_redraw()


func _exit_tree() -> void:
	_release_pull()


func _release_pull() -> void:
	if pull_released or not can_pull:
		return
	pull_released = true
	if (
		is_instance_valid(hooked_target)
		and hooked_target.has_method("end_fisherman_pull")
	):
		hooked_target.end_fisherman_pull(pull_immunity_duration)


func _process(delta: float) -> void:
	elapsed += delta
	_cache_live_line_endpoints()
	if not _combat_is_active():
		_release_pull()
		if elapsed >= MINIMUM_VISUAL_DURATION:
			queue_free()
		else:
			queue_redraw()
		return
	if can_pull and hooked_target.has_method("apply_fisherman_pull_toward"):
		var reel_distance := pull_speed * delta
		if hooked_target.has_method("get_effective_speed"):
			# Cancel the enemy's own forward step so hook_pull_speed represents
			# visible backward reel speed rather than only a slowing force.
			reel_distance += hooked_target.get_effective_speed() * delta
		hooked_target.apply_fisherman_pull_toward(
			source_tower.global_position,
			reel_distance,
			attack_context
		)
	while ticks_applied < tick_count and elapsed + 0.0001 >= tick_interval * ticks_applied:
		_apply_damage_tick()
		if not _target_is_active():
			queue_free()
			return
	queue_redraw()
	if ticks_applied >= tick_count and elapsed >= duration:
		queue_free()


func _draw() -> void:
	if not has_cached_line or not is_instance_valid(source_tower):
		return
	_cache_live_line_endpoints()
	var start := to_local(cached_line_start_world)
	var finish := to_local(cached_line_end_world)
	if electric_line:
		draw_line(start, finish, Color(0.10, 0.75, 1.0, 0.28), 7.0, true)
		var points := PackedVector2Array([start])
		var segment := finish - start
		var perpendicular := segment.normalized().orthogonal()
		for index in range(1, 8):
			var ratio := float(index) / 8.0
			var offset := perpendicular * (3.0 if index % 2 == 0 else -3.0)
			points.append(start + segment * ratio + offset)
		points.append(finish)
		draw_polyline(points, Color(0.40, 0.95, 1.0, 1.0), 2.5, true)
		return
	draw_line(start, finish, Color(0.25, 0.85, 0.95, 0.95), 2.0, true)
	draw_circle(finish, 3.5, Color(1.0, 0.55, 0.18, 0.95))


func _cache_live_line_endpoints() -> void:
	if is_instance_valid(source_tower) and is_instance_valid(source_tower.muzzle):
		cached_line_start_world = source_tower.muzzle.global_position
	if is_instance_valid(hooked_target):
		cached_line_end_world = hooked_target.global_position
		has_cached_line = true


func _apply_damage_tick() -> void:
	if ticks_applied >= tick_count or not _combat_is_active():
		return
	var tick_damage := total_damage / tick_count
	if ticks_applied < total_damage % tick_count:
		tick_damage += 1
	tick_damage = maxi(tick_damage, 1)
	var tick_context := source_tower.create_attack_context(
		&"fisherman_hook_tick",
		self,
		&"persistent_effect",
		attack_context,
		ticks_applied > 0
	)
	source_tower.apply_tower_damage(
		hooked_target,
		tick_damage,
		damage_type,
		ignores_armor,
		tick_context
	)
	if electric_line and tether_half_width > 0.0 and tether_maximum_targets > 0:
		_apply_tether_damage(tick_damage, tick_context)
	ticks_applied += 1


func _apply_tether_damage(
	primary_tick_damage: int,
	parent_tick_context: AttackContext
) -> void:
	var start := cached_line_start_world
	var finish := cached_line_end_world
	var damage_multiplier := tether_secondary_damage_multiplier
	if ticks_applied == tick_count - 1:
		damage_multiplier *= tether_final_pulse_multiplier
	var secondary_damage := maxi(
		roundi(float(primary_tick_damage) * damage_multiplier), 1
	)
	var candidates: Array[Node2D] = []
	var segment_center := (start + finish) * 0.5
	var search_radius := start.distance_to(finish) * 0.5 + tether_half_width
	for candidate in AreaDamage.get_targets_near(
		source_tower.get_tree(), segment_center, search_radius
	):
		if candidate == hooked_target or not source_tower.is_valid_target(candidate):
			continue
		if _distance_to_segment(candidate.global_position, start, finish) <= tether_half_width:
			candidates.append(candidate)
	candidates.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		return start.distance_squared_to(left.global_position) < start.distance_squared_to(right.global_position)
	)
	for target_index in mini(candidates.size(), tether_maximum_targets):
		var tether_context := parent_tick_context.derive(
			self,
			&"persistent_effect",
			&"fisherman_tether_tick",
			true,
			{"area_damage": true}
		)
		source_tower.apply_tower_damage(
			candidates[target_index],
			secondary_damage,
			&"electric",
			false,
			tether_context
		)


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _combat_is_active() -> bool:
	return (
		_target_is_active()
		and is_instance_valid(source_tower)
		and source_tower.is_placed
	)


func _target_is_active() -> bool:
	return (
		is_instance_valid(hooked_target)
		and not hooked_target.is_queued_for_deletion()
		and not bool(hooked_target.get("finished"))
	)
