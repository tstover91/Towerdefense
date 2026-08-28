class_name AreaDamageHelper
extends RefCounted


static func prepare_explosion_context(
	context: AttackContext,
	scene_tree: SceneTree,
	center: Vector2,
	radius: float,
	excluded_target: Node = null
) -> AttackContext:
	if context == null:
		context = AttackContext.legacy(&"", &"explosion")
	var target_count := 0
	for mob in scene_tree.get_nodes_in_group("mobs"):
		if mob == excluded_target:
			continue
		if not is_valid_explosion_target(mob, context):
			continue
		if center.distance_to(mob.global_position) <= radius:
			target_count += 1
	context.metadata["explosion_target_count"] = target_count
	context.metadata["explosion_center"] = center
	context.metadata["explosion_radius"] = radius
	# Hidden prevents direct targeting, but independent area damage can still
	# catch a Hidden enemy.
	context.metadata["area_damage"] = true
	return context


static func is_valid_explosion_target(
	candidate: Variant,
	_context: AttackContext
) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not bool(candidate.get("finished"))
	)
