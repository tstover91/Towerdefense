class_name BeholderConvergingBeams
extends Node2D

const GameStats = preload("res://stat_database.gd")

const BEAM_DURATION := 1.0
const TICK_INTERVAL := 0.1
const TICK_COUNT := 10

var tower_ref: WeakRef
var target_ref: WeakRef
var beam_origins: Array[Vector2] = []
var beam_endpoints: Array[Vector2] = []
var total_damage_per_beam := 0
var tick_index := 0
var tick_remaining := TICK_INTERVAL
var elapsed := 0.0
var attack_context: AttackContext
var damage_mark_enabled := false
var mark_duration := 3.0
var mark_damage_per_stack := 0.02
var mark_maximum_stacks := 10
var resolving := false


func _ready() -> void:
	add_to_group("tower_attack_resolvers")
	add_to_group("tower_attack_visuals")
	add_to_group("beholder_converging_beams")


func setup(
	owner_tower: BaseTower,
	attack_target: Node2D,
	launch_positions: Array[Vector2],
	attack_damage: int,
	ownership_context: AttackContext,
	attack_applies_damage_mark := false,
	attack_mark_duration := 3.0,
	attack_mark_damage_per_stack := 0.02,
	attack_mark_maximum_stacks := 10
) -> void:
	tower_ref = weakref(owner_tower)
	target_ref = weakref(attack_target)
	beam_origins.assign(launch_positions)
	beam_endpoints.assign(launch_positions)
	total_damage_per_beam = maxi(attack_damage, 0)
	attack_context = ownership_context
	damage_mark_enabled = attack_applies_damage_mark
	mark_duration = maxf(attack_mark_duration, 0.01)
	mark_damage_per_stack = maxf(attack_mark_damage_per_stack, 0.0)
	mark_maximum_stacks = maxi(attack_mark_maximum_stacks, 1)
	_refresh_beam_endpoints()
	_apply_damage_tick()
	queue_redraw()


func _process(delta: float) -> void:
	if resolving:
		return
	var tower := get_tower()
	if tower == null:
		finish()
		return
	if tower.main != null and not bool(tower.main.get("round_active")):
		finish()
		return
	elapsed += delta
	tick_remaining -= delta
	_refresh_beam_endpoints()
	while tick_remaining <= 0.0 and tick_index < TICK_COUNT:
		_apply_damage_tick()
		tick_remaining += TICK_INTERVAL
	if elapsed >= BEAM_DURATION:
		# Never lose the last budgeted tick to accumulator rounding or a long frame.
		while tick_index < TICK_COUNT:
			_apply_damage_tick()
		finish()
		return
	queue_redraw()


func _apply_damage_tick() -> void:
	if tick_index >= TICK_COUNT:
		return
	var tower := get_tower()
	var target := get_target()
	if tower != null and target != null and tower.is_valid_target(target):
		var marked_target_ids: Dictionary = {}
		for beam_index in beam_origins.size():
			var hit_targets := _get_beam_targets(
				tower,
				beam_origins[beam_index],
				target.global_position
			)
			for hit_index in hit_targets.size():
				var hit_target := hit_targets[hit_index]
				if damage_mark_enabled:
					var target_id := hit_target.get_instance_id()
					if not marked_target_ids.has(target_id):
						marked_target_ids[target_id] = true
						if hit_target.has_method("apply_beholder_damage_mark"):
							hit_target.apply_beholder_damage_mark(
								mark_duration,
								mark_damage_per_stack,
								mark_maximum_stacks
							)
				var hit_total := GameStats.get_piercing_damage(
					total_damage_per_beam,
					hit_index,
					tower.pierce_loses_no_power
				)
				var tick_damage := get_budgeted_tick_damage(
					hit_total,
					tick_index,
					TICK_COUNT
				)
				if tick_damage <= 0:
					continue
				var tick_context := tower.create_attack_context(
					&"beholder_beam_tick",
					self,
					&"persistent_effect",
					attack_context,
					hit_index > 0
				)
				tower.apply_control_effects(hit_target, tick_context)
				tower.apply_tower_damage(
					hit_target,
					tick_damage,
					&"beam",
					false,
					tick_context
				)
	tick_index += 1


func _get_beam_targets(
	tower: BaseTower,
	origin: Vector2,
	intended_endpoint: Vector2
) -> Array[Node2D]:
	var segment := intended_endpoint - origin
	var query_endpoint := intended_endpoint
	if not segment.is_zero_approx():
		# Extend past the target center by a fraction of a pixel so floating-point
		# projection at the exact segment boundary cannot omit the intended target.
		query_endpoint += segment.normalized() * 0.5
	var intersected := tower.get_targets_along_line(
		origin,
		query_endpoint,
		null,
		tower.beam_hit_half_width_pixels
	)
	var maximum_hits := 1
	if tower.infinite_pierce:
		maximum_hits = intersected.size()
	else:
		maximum_hits += tower.pierce_count
	if intersected.size() > maximum_hits:
		intersected.resize(maximum_hits)
	return intersected


func _refresh_beam_endpoints() -> void:
	var tower := get_tower()
	var target := get_target()
	if tower == null or target == null or not tower.is_valid_target(target):
		return
	var target_position := target.global_position
	for beam_index in beam_origins.size():
		var hits := _get_beam_targets(
			tower,
			beam_origins[beam_index],
			target_position
		)
		beam_endpoints[beam_index] = (
			target_position if hits.is_empty() else hits.back().global_position
		)


func _draw() -> void:
	var life_ratio := clampf(elapsed / BEAM_DURATION, 0.0, 1.0)
	var pulse := 0.82 + sin(elapsed * 28.0) * 0.12
	var fade := minf((1.0 - life_ratio) * 5.0, 1.0)
	for beam_index in mini(beam_origins.size(), beam_endpoints.size()):
		var start := to_local(beam_origins[beam_index])
		var finish_position := to_local(beam_endpoints[beam_index])
		draw_line(
			start,
			finish_position,
			Color(0.42, 0.08, 0.78, 0.42 * fade),
			7.0,
			true
		)
		draw_line(
			start,
			finish_position,
			Color(0.92, 0.58, 1.0, pulse * fade),
			2.2,
			true
		)
		draw_circle(
			finish_position,
			3.0,
			Color(0.96, 0.78, 1.0, 0.9 * fade)
		)


func finish() -> void:
	if resolving:
		return
	resolving = true
	queue_free()


func recycle_now() -> void:
	finish()


func get_tower() -> BaseTower:
	if tower_ref == null:
		return null
	return tower_ref.get_ref() as BaseTower


func get_target() -> Node2D:
	if target_ref == null:
		return null
	return target_ref.get_ref() as Node2D


static func get_budgeted_tick_damage(
	total_damage: int,
	current_tick: int,
	total_ticks: int
) -> int:
	if total_damage <= 0 or total_ticks <= 0:
		return 0
	var bounded_tick := clampi(current_tick, 0, total_ticks - 1)
	var damage_before := floori(
		float(total_damage) * float(bounded_tick) / float(total_ticks)
	)
	var damage_after := floori(
		float(total_damage) * float(bounded_tick + 1) / float(total_ticks)
	)
	return damage_after - damage_before
