class_name SolarLance
extends Node2D

const GameStats = preload("res://stat_database.gd")
const ORBITAL_CANNON_TOWER_ID: StringName = &"orbitalcannon"

signal finished(lance: Node2D)

const SLOW_REFRESH_INTERVAL := 0.05

var main: Node
var radius := 40.0
var tick_start_damage := 1
var tick_end_damage := 1
var duration := 2.0
var tick_interval := 0.2
var elapsed := 0.0
var tick_remaining := 0.0
var tick_index := 0
var tick_count := 1
var resolving := false
var attack_context: AttackContext
var slowed_mobs: Dictionary = {}
var slow_refresh_remaining := 0.0


func setup(
	game_main: Node,
	lance_radius: float,
	lance_tick_start_damage: int,
	lance_tick_end_damage: int,
	lance_duration: float,
	lance_tick_interval: float,
	ownership_context: AttackContext = null
) -> void:
	main = game_main
	radius = maxf(lance_radius, 1.0)
	tick_start_damage = maxi(lance_tick_start_damage, 1)
	tick_end_damage = maxi(lance_tick_end_damage, 1)
	duration = maxf(lance_duration, 0.01)
	tick_interval = maxf(lance_tick_interval, 0.01)
	tick_count = floori(duration / tick_interval) + 1
	tick_index = 0
	attack_context = ownership_context
	if attack_context == null:
		attack_context = AttackContext.legacy(
			ORBITAL_CANNON_TOWER_ID,
			&"solar_lance"
		)
	attack_context.metadata["area_damage"] = true
	tick_remaining = 0.0
	slow_refresh_remaining = 0.0
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.08, 0.16))
	draw_circle(
		Vector2.ZERO,
		radius * GameStats.EXPLOSION_INNER_RADIUS_RATIO,
		Color(1.0, 0.9, 0.35, 0.24)
	)
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		64,
		Color(1.0, 0.65, 0.15, 0.9),
		2.0,
		true
	)


func _process(delta: float) -> void:
	if resolving:
		return
	if main == null or not main.round_active:
		cancel()
		return
	elapsed += delta
	slow_refresh_remaining -= delta
	if slow_refresh_remaining <= 0.0:
		update_zone_slow()
		slow_refresh_remaining = SLOW_REFRESH_INTERVAL
	tick_remaining -= delta
	while tick_remaining <= 0.0 and elapsed <= duration:
		apply_damage_tick()
		tick_remaining += tick_interval
	if elapsed >= duration:
		finish()


func apply_damage_tick() -> void:
	var tick_context := attack_context
	var ramp_progress := (
		float(tick_index) / float(tick_count - 1)
		if tick_count > 1
		else 1.0
	)
	var tick_damage := maxi(roundi(lerpf(
		float(tick_start_damage),
		float(tick_end_damage),
		ramp_progress
	)), 1)
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_mob(mob):
			continue
		var distance_from_center: float = global_position.distance_to(mob.global_position)
		if distance_from_center > radius:
			continue
		if mob.has_method("apply_damage_from_tower"):
			mob.apply_damage_from_tower(
				tick_damage,
				&"beam",
				false,
				ORBITAL_CANNON_TOWER_ID,
				tick_context
			)
		else:
			mob.apply_damage(tick_damage, &"beam", false, true, tick_context)
	tick_index += 1


func update_zone_slow() -> void:
	var mob_ids_inside: Dictionary = {}
	var refresh_duration := SLOW_REFRESH_INTERVAL * 1.5
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_mob(mob):
			continue
		if global_position.distance_to(mob.global_position) > radius:
			continue
		var mob_id := mob.get_instance_id()
		mob_ids_inside[mob_id] = true
		slowed_mobs[mob_id] = weakref(mob)
		if mob.has_method("apply_slow"):
			mob.apply_slow(refresh_duration, attack_context)
	for mob_id in slowed_mobs.keys():
		if mob_ids_inside.has(mob_id):
			continue
		clear_lance_slow_from_mob(get_tracked_slowed_mob(mob_id))
		slowed_mobs.erase(mob_id)


func clear_all_lance_slows() -> void:
	for mob_id in slowed_mobs.keys():
		clear_lance_slow_from_mob(get_tracked_slowed_mob(mob_id))
	slowed_mobs.clear()


func get_tracked_slowed_mob(mob_id: int) -> Variant:
	var mob_reference: Variant = slowed_mobs.get(mob_id)
	if mob_reference is not WeakRef:
		return null
	return mob_reference.get_ref()


func clear_lance_slow_from_mob(mob: Variant) -> void:
	if is_instance_valid(mob) and mob.has_method("clear_slow_from_context"):
		mob.clear_slow_from_context(attack_context)


func finish() -> void:
	if resolving:
		return
	resolving = true
	clear_all_lance_slows()
	finished.emit(self)
	queue_free()


func cancel() -> void:
	finish()


func is_valid_mob(candidate: Variant) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)
