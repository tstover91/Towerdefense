class_name BrainiacConvergenceResolver
extends Node

const GameStats = preload("res://stat_database.gd")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")

var main_ref: WeakRef
var expected_arrivals := 0
var arrivals := 0
var base_damage := 0
var damage_per_arrival := 1.0
var base_radius := 0.0
var radius_per_arrival := 0.0
var convergence_position := Vector2.ZERO
var can_hit_hidden := false
var attack_context: AttackContext
var timeout_remaining := 0.0
var armed := false
var resolved := false


func _ready() -> void:
	add_to_group("tower_attack_resolvers")


func setup(
	main_node: Node,
	expected_projectile_count: int,
	attack_damage: int,
	attack_damage_per_arrival: float,
	explosion_base_radius: float,
	explosion_radius_per_arrival: float,
	target_position: Vector2,
	attack_can_hit_hidden: bool,
	ownership_context: AttackContext
) -> void:
	main_ref = weakref(main_node) if is_instance_valid(main_node) else null
	expected_arrivals = maxi(expected_projectile_count, 0)
	base_damage = maxi(attack_damage, 0)
	damage_per_arrival = maxf(attack_damage_per_arrival, 0.0)
	base_radius = maxf(explosion_base_radius, 0.0)
	radius_per_arrival = maxf(explosion_radius_per_arrival, 0.0)
	convergence_position = target_position
	can_hit_hidden = attack_can_hit_hidden
	attack_context = ownership_context


func track_projectile(projectile: Node) -> void:
	if resolved or not is_instance_valid(projectile):
		return
	projectile.destination_reached.connect(
		_on_projectile_reached_destination,
		CONNECT_ONE_SHOT
	)


func arm_timeout(duration: float) -> void:
	timeout_remaining = maxf(duration, 0.0)
	armed = true
	if expected_arrivals <= 0:
		resolve()


func _process(delta: float) -> void:
	if resolved:
		return
	var main := get_main()
	if main == null or not bool(main.get("round_active")):
		resolved = true
		queue_free()
		return
	if not armed:
		return
	timeout_remaining = maxf(timeout_remaining - delta, 0.0)
	if timeout_remaining <= 0.0:
		resolve()


func _on_projectile_reached_destination(_projectile: Node2D) -> void:
	if resolved:
		return
	arrivals += 1
	if arrivals >= expected_arrivals:
		resolve()


func resolve() -> void:
	if resolved:
		return
	resolved = true
	var main := get_main()
	if arrivals > 0 and main != null and bool(main.get("round_active")):
		trigger_explosion()
	queue_free()


func trigger_explosion() -> void:
	var explosion_radius := (
		base_radius + radius_per_arrival * float(arrivals - 1)
	)
	var explosion_damage := maxi(
		roundi(float(base_damage) * damage_per_arrival * float(arrivals)),
		1
	)
	if EXPLOSION_ZONE_SCENE != null and get_tree().current_scene != null:
		var explosion_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
		get_tree().current_scene.add_child(explosion_zone)
		explosion_zone.global_position = convergence_position
		explosion_zone.setup(explosion_radius)
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(mob):
			continue
		var distance_from_center: float = (
			mob.global_position.distance_to(convergence_position)
		)
		if distance_from_center > explosion_radius:
			continue
		var dealt_damage := GameStats.get_explosion_damage(
			explosion_damage,
			distance_from_center,
			explosion_radius
		)
		if mob.has_method("apply_damage_from_tower"):
			mob.apply_damage_from_tower(
				dealt_damage,
				&"explosive",
				false,
				attack_context.root_tower_type if attack_context != null else &"brainiac",
				attack_context
			)
		else:
			mob.apply_damage(
				dealt_damage,
				&"explosive",
				false,
				true,
				attack_context
			)


func is_valid_target(candidate: Variant) -> bool:
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or candidate.is_queued_for_deletion()
		or bool(candidate.get("finished"))
	):
		return false
	var traits: Variant = candidate.get("traits")
	if traits is Array and traits.has(&"hidden"):
		return can_hit_hidden
	return true


func get_main() -> Node:
	if main_ref == null:
		return null
	return main_ref.get_ref() as Node
