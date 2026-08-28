class_name FalloutZone
extends Node2D

signal finished(zone: Node2D)

var source_tower: BaseTower
var radius := 0.0
var duration := 8.0
var remaining := 8.0
var elapsed := 0.0
var application_interval := 1.0
var application_remaining := 1.0
var stacks_per_application := 1
var radiation_damage := 1
var attack_context: AttackContext
var total_applications := 0


func setup(
	owner_tower: BaseTower,
	zone_radius: float,
	zone_duration: float,
	interval: float,
	stack_count: int,
	damage_per_stack: int,
	parent_context: AttackContext
) -> void:
	source_tower = owner_tower
	radius = maxf(zone_radius, 0.1)
	duration = maxf(zone_duration, 0.1)
	remaining = duration
	elapsed = 0.0
	application_interval = maxf(interval, 0.05)
	application_remaining = application_interval
	stacks_per_application = maxi(stack_count, 1)
	radiation_damage = maxi(damage_per_stack, 1)
	attack_context = parent_context.derive(
		self, &"persistent_effect", &"fallout_exposure", true,
		{"fallout": true, "area_damage": true}
	)
	add_to_group("tower_attack_visuals")
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	remaining = maxf(remaining - delta, 0.0)
	application_remaining -= delta
	while application_remaining <= 0.0 and remaining > 0.0:
		application_remaining += application_interval
		apply_fallout()
	queue_redraw()
	if remaining <= 0.0:
		finished.emit(self)
		queue_free()


func apply_fallout() -> void:
	if not is_instance_valid(source_tower) or not source_tower.is_combat_active():
		return
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not source_tower.is_valid_area_target(mob):
			continue
		if mob.global_position.distance_to(global_position) > radius:
			continue
		if not mob.has_method("apply_radiation"):
			continue
		mob.apply_radiation(
			stacks_per_application, radiation_damage, attack_context, 1.0
		)
		total_applications += stacks_per_application


func get_debug_state() -> Dictionary:
	return {
		"remaining": remaining,
		"radius": radius,
		"application_interval": application_interval,
		"total_applications": total_applications,
	}


func _draw() -> void:
	var fade := clampf(remaining / minf(duration, 1.5), 0.0, 1.0)
	var blast_flash := clampf(1.0 - elapsed / 0.45, 0.0, 1.0)
	if blast_flash > 0.0:
		draw_circle(
			Vector2.ZERO,
			radius * (1.15 - blast_flash * 0.35),
			Color(1.0, 0.92, 0.35, 0.50 * blast_flash)
		)
		draw_arc(
			Vector2.ZERO, radius * (1.25 - blast_flash * 0.25),
			0.0, TAU, 64, Color(0.9, 1.0, 0.5, blast_flash),
			4.0, true
		)
	draw_circle(Vector2.ZERO, radius, Color(0.48, 0.72, 0.08, 0.13 * fade))
	draw_arc(
		Vector2.ZERO, radius, 0.0, TAU, 64,
		Color(0.76, 0.94, 0.13, 0.70 * fade), 2.0, true
	)
	for ring_ratio in [0.33, 0.66]:
		draw_arc(
			Vector2.ZERO, radius * ring_ratio, 0.0, TAU, 48,
			Color(0.62, 0.82, 0.10, 0.24 * fade), 1.0, true
		)
