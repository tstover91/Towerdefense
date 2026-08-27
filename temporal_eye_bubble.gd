class_name TemporalEyeBubble
extends Node2D

const BEAM_COUNT := 4

var tower_ref: WeakRef
var attack_damage := 1
var duration := 3.0
var radius := 96.0
var tick_interval := 0.2
var beam_half_width := 9.6
var rotation_radians := PI * 0.5
var center_damage_multiplier := 1.0
var final_stun_duration := 0.0
var attack_context: AttackContext
var elapsed := 0.0
var tick_remaining := 0.0
var resolving := false
var revealed_mobs: Array[Node] = []


func _ready() -> void:
	add_to_group("tower_attack_resolvers")
	add_to_group("tower_attack_visuals")
	z_index = 11
	z_as_relative = false


func setup(
	owner_tower: BaseTower,
	total_attack_damage: int,
	active_duration: float,
	bubble_radius: float,
	damage_tick_interval: float,
	damage_beam_half_width: float,
	total_rotation_radians: float,
	convergence_damage_multiplier: float,
	ending_stun_duration: float,
	ownership_context: AttackContext
) -> void:
	tower_ref = weakref(owner_tower)
	attack_damage = maxi(total_attack_damage, 1)
	duration = maxf(active_duration, 0.1)
	radius = maxf(bubble_radius, 1.0)
	tick_interval = maxf(damage_tick_interval, 0.05)
	beam_half_width = maxf(damage_beam_half_width, 1.0)
	rotation_radians = total_rotation_radians
	center_damage_multiplier = maxf(convergence_damage_multiplier, 0.0)
	final_stun_duration = maxf(ending_stun_duration, 0.0)
	attack_context = ownership_context
	tick_remaining = tick_interval
	_apply_tick()
	queue_redraw()


func _process(delta: float) -> void:
	if resolving:
		return
	var tower := get_tower()
	if tower == null or not tower.is_placed or not tower.is_combat_active():
		finish(false)
		return
	elapsed += delta
	tick_remaining -= delta
	while tick_remaining <= 0.0 and elapsed < duration:
		_apply_tick()
		tick_remaining += tick_interval
	queue_redraw()
	if elapsed >= duration:
		finish(true)


func _apply_tick() -> void:
	var tower := get_tower()
	if tower == null:
		return
	var enemies_in_bubble := _get_enemies_in_bubble(tower)
	_refresh_reveal(enemies_in_bubble)
	var slow_context := attack_context.derive(
		self, &"persistent_effect", &"temporal_eye_slow", true
	)
	for enemy in enemies_in_bubble:
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(tick_interval * 2.5, slow_context)
	var current_angle := _get_current_angle()
	for beam_index in BEAM_COUNT:
		var angle := current_angle + TAU * float(beam_index) / float(BEAM_COUNT)
		var beam_origin := global_position + Vector2.RIGHT.rotated(angle) * radius
		var beam_damage := _get_beam_damage(beam_index)
		for enemy in enemies_in_bubble:
			if _distance_to_segment(enemy.global_position, beam_origin, global_position) > beam_half_width:
				continue
			var resolved_damage := beam_damage
			if enemy.global_position.distance_to(global_position) <= beam_half_width * 1.5:
				resolved_damage = maxi(
					roundi(float(resolved_damage) * center_damage_multiplier), 1
				)
			var hit_context := attack_context.derive(
				self,
				&"persistent_effect",
				&"temporal_eye_beam_tick",
				beam_index > 0,
				{"area_damage": true}
			)
			tower.apply_tower_damage(
				enemy,
				resolved_damage,
				BaseTower.DAMAGE_BEAM,
				false,
				hit_context
			)


func _get_enemies_in_bubble(tower: BaseTower) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if not tower.is_valid_target(candidate):
			continue
		if global_position.distance_to(candidate.global_position) <= radius:
			result.append(candidate)
	return result


func _refresh_reveal(current_mobs: Array[Node2D]) -> void:
	for mob in current_mobs:
		if mob.has_method("add_global_reveal_source"):
			mob.add_global_reveal_source(self, attack_context)
	for previous_mob in revealed_mobs:
		if (
			is_instance_valid(previous_mob)
			and not current_mobs.has(previous_mob)
			and previous_mob.has_method("remove_global_reveal_source")
		):
			previous_mob.remove_global_reveal_source(self)
	revealed_mobs.assign(current_mobs)


func _apply_final_stun() -> void:
	if final_stun_duration <= 0.0:
		return
	var tower := get_tower()
	if tower == null:
		return
	var stun_context := attack_context.derive(
		self, &"persistent_effect", &"temporal_eye_final_pulse", true
	)
	for enemy in _get_enemies_in_bubble(tower):
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(final_stun_duration, false, stun_context)


func _get_beam_damage(beam_index: int) -> int:
	var damage_before := floori(
		float(attack_damage) * float(beam_index) / float(BEAM_COUNT)
	)
	var damage_after := floori(
		float(attack_damage) * float(beam_index + 1) / float(BEAM_COUNT)
	)
	return maxi(damage_after - damage_before, 1)


func _get_current_angle() -> float:
	return rotation_radians * clampf(elapsed / duration, 0.0, 1.0)


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.30, 0.15, 0.65, 0.10))
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		64,
		Color(0.65, 0.38, 1.0, 0.58),
		2.0,
		true
	)
	var current_angle := _get_current_angle()
	for beam_index in BEAM_COUNT:
		var angle := current_angle + TAU * float(beam_index) / float(BEAM_COUNT)
		var eye_position := Vector2.RIGHT.rotated(angle) * radius
		draw_line(
			eye_position,
			Vector2.ZERO,
			Color(0.86, 0.48, 1.0, 0.82),
			maxf(beam_half_width * 0.20, 2.0),
			true
		)
		draw_circle(eye_position, 7.0, Color(0.38, 0.12, 0.62, 0.95))
		draw_circle(eye_position, 3.0, Color(0.95, 0.75, 1.0, 1.0))
	draw_circle(Vector2.ZERO, 8.0, Color(0.78, 0.42, 1.0, 0.34))


func finish(trigger_final_pulse := true) -> void:
	if resolving:
		return
	resolving = true
	if trigger_final_pulse:
		_apply_final_stun()
	_clear_reveal()
	queue_free()


func _clear_reveal() -> void:
	for mob in revealed_mobs:
		if is_instance_valid(mob) and mob.has_method("remove_global_reveal_source"):
			mob.remove_global_reveal_source(self)
	revealed_mobs.clear()


func recycle_now() -> void:
	finish(false)


func get_tower() -> BaseTower:
	if tower_ref == null:
		return null
	return tower_ref.get_ref() as BaseTower
