class_name FishermanHookEffect
extends Node2D

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
	parent_context: AttackContext
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
	attack_context = parent_context
	tick_interval = duration / float(maxi(tick_count - 1, 1))
	z_index = 12
	z_as_relative = false
	_cache_live_line_endpoints()
	if attack_can_pull and hooked_target.has_method("try_begin_fisherman_pull"):
		can_pull = hooked_target.try_begin_fisherman_pull(
			pull_immunity_duration
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
		hooked_target.apply_fisherman_pull_toward(
			source_tower.global_position,
			pull_speed * delta
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
	ticks_applied += 1


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
