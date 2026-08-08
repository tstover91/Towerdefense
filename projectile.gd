class_name TowerProjectile
extends Node2D

var target: Node2D
var destination := Vector2.ZERO
var speed := 600.0
var damage := 0
var damage_type: StringName = &""
var splash_radius := 0.0


func setup(
	target_node: Node2D,
	move_speed: float,
	attack_damage: int,
	attack_type: StringName,
	attack_splash_radius := 0.0
) -> void:
	target = target_node
	destination = target.global_position
	speed = maxf(move_speed, 1.0)
	damage = attack_damage
	damage_type = attack_type
	splash_radius = attack_splash_radius
	rotation = (destination - global_position).angle()


func _physics_process(delta: float) -> void:
	if is_valid_target(target):
		destination = target.global_position

	var offset := destination - global_position
	var travel_distance := speed * delta

	if offset.length() <= travel_distance:
		global_position = destination
		resolve_impact()
		queue_free()
		return

	rotation = offset.angle()
	global_position += offset.normalized() * travel_distance


func resolve_impact() -> void:
	if splash_radius > 0.0:
		for mob in get_tree().get_nodes_in_group("mobs"):
			if (
				is_valid_target(mob)
				and mob.global_position.distance_to(global_position) <= splash_radius
			):
				mob.apply_damage(damage, damage_type)
	elif is_valid_target(target):
		target.apply_damage(damage, damage_type)


func is_valid_target(candidate: Node) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)
