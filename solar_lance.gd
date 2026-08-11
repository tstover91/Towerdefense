class_name SolarLance
extends Node2D

const GameStats = preload("res://stat_database.gd")
const ORBITAL_CANNON_TOWER_ID: StringName = &"orbitalcannon"

signal finished(lance: Node2D)

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
	tick_remaining = 0.0
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


func finish() -> void:
	if resolving:
		return
	resolving = true
	finished.emit(self)
	queue_free()


func cancel() -> void:
	finish()


func is_valid_mob(candidate: Variant) -> bool:
	var valid_mob: bool = (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)
	return valid_mob and (
		not candidate.traits.has(&"hidden")
		or (
			candidate.has_method("is_revealed_for_all")
			and candidate.is_revealed_for_all()
		)
	)
