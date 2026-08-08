class_name TowerProjectile
extends Node2D

const GameStats = preload("res://stat_database.gd")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
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
var slow_speed_multiplier := 1.0
var slow_duration := 0.0
var stun_duration := 0.0
var stun_affects_bosses := false
var bounce_count := 0
var bounce_range := 0.0
var remaining_bounces := 0
var remaining_pierce_hits := 0
var pierce_chain_hit_count := 0
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
	attack_pierce_count := 0,
	attack_slow_speed_multiplier := 1.0,
	attack_slow_duration := 0.0,
	attack_stun_duration := 0.0,
	attack_stun_affects_bosses := false,
	attack_bounce_count := 0,
	attack_bounce_range := 0.0
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
	slow_speed_multiplier = clampf(attack_slow_speed_multiplier, 0.0, 1.0)
	slow_duration = maxf(attack_slow_duration, 0.0)
	stun_duration = maxf(attack_stun_duration, 0.0)
	stun_affects_bosses = attack_stun_affects_bosses
	bounce_count = maxi(attack_bounce_count, 0)
	bounce_range = maxf(attack_bounce_range, 0.0)
	remaining_bounces = bounce_count
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

	hit_target_ids[primary_target.get_instance_id()] = true
	apply_damage_and_effects(primary_target, pierce_count > 0, damage)
	pierce_chain_hit_count = 1
	if begin_next_bounce():
		return
	if pierce_count < 1 or continuation_distance <= 0.0:
		queue_free()
		return

	piercing_after_primary = true
	distance_traveled = 0.0


func begin_next_bounce() -> bool:
	if remaining_bounces <= 0 or bounce_range <= 0.0:
		return false
	var next_target := get_nearest_bounce_target()
	if next_target == null:
		return false

	remaining_bounces -= 1
	primary_target = next_target
	impact_position = next_target.global_position
	var aim_offset := impact_position - global_position
	if not aim_offset.is_zero_approx():
		direction = aim_offset.normalized()
	distance_to_impact = aim_offset.length()
	distance_traveled = 0.0
	continuation_distance = maxf(bounce_range - distance_to_impact, 0.0)
	rotation = direction.angle()
	return true


func get_nearest_bounce_target() -> Node2D:
	var selected_target: Node2D
	var selected_distance := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(candidate):
			continue
		if hit_target_ids.has(candidate.get_instance_id()):
			continue
		var candidate_distance := global_position.distance_to(
			candidate.global_position
		)
		if candidate_distance > bounce_range:
			continue
		if candidate_distance < selected_distance:
			selected_distance = candidate_distance
			selected_target = candidate
	return selected_target


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
		var pierced_damage := GameStats.get_piercing_damage(
			damage,
			pierce_chain_hit_count
		)
		apply_damage_and_effects(mob, true, pierced_damage)
		pierce_chain_hit_count += 1
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
		var contact_damage := GameStats.get_piercing_damage(
			damage,
			pierce_chain_hit_count
		)
		apply_damage_and_effects(
			mob,
			pierce_count > 0,
			contact_damage
		)
		pierce_chain_hit_count += 1
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
	spawn_explosion_zone(center)
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(mob):
			continue
		var distance_from_center: float = mob.global_position.distance_to(center)
		if distance_from_center > splash_radius:
			continue
		var explosion_damage: int = GameStats.get_explosion_damage(
			damage,
			distance_from_center,
			splash_radius
		)
		apply_damage_and_effects(
			mob,
			pierce_count > 0,
			explosion_damage
		)


func spawn_explosion_zone(center: Vector2) -> void:
	if EXPLOSION_ZONE_SCENE == null or get_tree().current_scene == null:
		return
	var explosion_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(explosion_zone)
	explosion_zone.global_position = center
	explosion_zone.setup(splash_radius)


func apply_damage_and_effects(
	mob: Node,
	ignores_armor: bool,
	attack_damage: int
) -> void:
	if slow_duration > 0.0 and mob.has_method("apply_slow"):
		mob.apply_slow(slow_speed_multiplier, slow_duration)
	if stun_duration > 0.0 and mob.has_method("apply_stun"):
		mob.apply_stun(stun_duration, stun_affects_bosses)
	mob.apply_damage(attack_damage, damage_type, ignores_armor)


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
