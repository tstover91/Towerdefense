class_name TowerProjectile
extends Node2D

const GameStats = preload("res://stat_database.gd")
const PROJECTILE_RADIUS := 3.0

var primary_target: Node2D
var impact_position := Vector2.ZERO
var direction := Vector2.RIGHT
var speed := 600.0
var distance_to_impact := 0.0
var distance_traveled := 0.0
var continuation_distance := 0.0
var damage := 0
var damage_type: StringName = &""
var impact_mode: StringName = GameStats.IMPACT_PRIMARY
var splash_radius := 0.0
var pierce_count := 0
var remaining_pierce_hits := 0
var piercing_after_primary := false
var first_contact_made := false
var hit_target_ids: Dictionary = {}


func setup(
	target_node: Node2D,
	target_position: Vector2,
	move_speed: float,
	max_travel_distance: float,
	attack_damage: int,
	attack_type: StringName,
	attack_impact_mode: StringName,
	attack_splash_radius := 0.0,
	attack_pierce_count := 0
) -> void:
	primary_target = target_node
	impact_position = target_position
	var aim_offset := impact_position - global_position
	if not aim_offset.is_zero_approx():
		direction = aim_offset.normalized()
	distance_to_impact = aim_offset.length()
	continuation_distance = maxf(max_travel_distance - distance_to_impact, 0.0)
	speed = maxf(move_speed, 1.0)
	damage = attack_damage
	damage_type = attack_type
	impact_mode = attack_impact_mode
	splash_radius = attack_splash_radius
	pierce_count = maxi(attack_pierce_count, 0)
	remaining_pierce_hits = (
		1 + pierce_count
		if impact_mode == GameStats.IMPACT_FIRST_CONTACT
		else pierce_count
	)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if piercing_after_primary:
		process_pierce_travel(delta)
	else:
		process_primary_travel(delta)


func process_primary_travel(delta: float) -> void:
	var travel_distance := minf(
		speed * delta,
		distance_to_impact - distance_traveled
	)
	if travel_distance > 0.0:
		var start := global_position
		var end := start + direction * travel_distance
		if (
			impact_mode == GameStats.IMPACT_FIRST_CONTACT
			and resolve_first_contact_segment(start, end)
		):
			global_position = end
			queue_free()
			return
		global_position = end
		distance_traveled += travel_distance

	if distance_traveled < distance_to_impact:
		return

	global_position = impact_position
	if impact_mode == GameStats.IMPACT_FIRST_CONTACT:
		resolve_first_contact_destination()
	else:
		resolve_primary_impact()


func resolve_first_contact_destination() -> void:
	if damage_type == &"explosive":
		resolve_explosion(impact_position)
		queue_free()
		return
	if not first_contact_made or remaining_pierce_hits <= 0:
		queue_free()
		return
	if continuation_distance <= 0.0:
		queue_free()
		return
	piercing_after_primary = true
	distance_traveled = 0.0


func resolve_primary_impact() -> void:
	if damage_type == &"explosive":
		resolve_explosion(impact_position)
		queue_free()
		return

	if not primary_target_is_at_impact():
		queue_free()
		return

	primary_target.apply_damage(damage, damage_type, pierce_count > 0)
	if pierce_count < 1 or continuation_distance <= 0.0:
		queue_free()
		return

	hit_target_ids[primary_target.get_instance_id()] = true
	piercing_after_primary = true
	distance_traveled = 0.0


func primary_target_is_at_impact() -> bool:
	if not is_valid_target(primary_target):
		return false
	var hit_radius := get_target_hit_radius(primary_target)
	return (
		primary_target.global_position.distance_to(impact_position)
		<= hit_radius + PROJECTILE_RADIUS
	)


func process_pierce_travel(delta: float) -> void:
	var travel_distance := minf(
		speed * delta,
		continuation_distance - distance_traveled
	)
	if travel_distance <= 0.0:
		queue_free()
		return

	var start := global_position
	var end := start + direction * travel_distance
	if resolve_pierce_segment(start, end):
		global_position = end
		queue_free()
		return

	global_position = end
	distance_traveled += travel_distance
	if distance_traveled >= continuation_distance:
		queue_free()


func resolve_pierce_segment(start: Vector2, end: Vector2) -> bool:
	for candidate in get_segment_candidates(start, end):
		var mob: Node2D = candidate["mob"]
		if not is_valid_target(mob):
			continue
		hit_target_ids[mob.get_instance_id()] = true
		mob.apply_damage(damage, damage_type, true)
		remaining_pierce_hits -= 1
		if remaining_pierce_hits <= 0:
			return true
	return false


func resolve_first_contact_segment(start: Vector2, end: Vector2) -> bool:
	for candidate in get_segment_candidates(start, end):
		var mob: Node2D = candidate["mob"]
		if not is_valid_target(mob):
			continue
		if damage_type == &"explosive":
			resolve_explosion(mob.global_position)
			return true
		hit_target_ids[mob.get_instance_id()] = true
		mob.apply_damage(damage, damage_type, pierce_count > 0)
		first_contact_made = true
		remaining_pierce_hits -= 1
		if remaining_pierce_hits <= 0:
			return true
	return false


func get_segment_candidates(start: Vector2, end: Vector2) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var segment := end - start
	var segment_length := segment.length()
	if segment_length <= 0.0:
		return candidates
	var segment_direction := segment / segment_length

	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(mob) or hit_target_ids.has(mob.get_instance_id()):
			continue
		var distance_along_segment: float = (
			mob.global_position - start
		).dot(segment_direction)
		if distance_along_segment < 0.0 or distance_along_segment > segment_length:
			continue
		var closest_point := Geometry2D.get_closest_point_to_segment(
			mob.global_position,
			start,
			end
		)
		if (
			mob.global_position.distance_to(closest_point)
			> get_target_hit_radius(mob) + PROJECTILE_RADIUS
		):
			continue
		candidates.append({
			"mob": mob,
			"distance": distance_along_segment,
		})

	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["distance"]) < float(b["distance"])
	)
	return candidates


func resolve_explosion(center: Vector2) -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		if (
			is_valid_target(mob)
			and mob.global_position.distance_to(center) <= splash_radius
		):
			mob.apply_damage(damage, damage_type, pierce_count > 0)


func get_target_hit_radius(candidate: Node) -> float:
	if candidate.has_method("get_projectile_hit_radius"):
		return candidate.get_projectile_hit_radius()
	return 12.0


func is_valid_target(candidate: Variant) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)
