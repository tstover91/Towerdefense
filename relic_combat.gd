class_name RelicCombat
extends RefCounted


static func prepare_explosion_context(
	context: AttackContext,
	scene_tree: SceneTree,
	center: Vector2,
	radius: float,
	excluded_target: Node = null
) -> AttackContext:
	if context == null:
		return null
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
	return context


static func is_valid_explosion_target(
	candidate: Variant,
	context: AttackContext
) -> bool:
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or candidate.is_queued_for_deletion()
		or bool(candidate.get("finished"))
	):
		return false
	var traits: Variant = candidate.get("traits")
	if traits is Array and traits.has(&"hidden"):
		return (
			can_explosion_hit_hidden(context)
			or (
				candidate.has_method("is_revealed_for_all")
				and candidate.is_revealed_for_all()
			)
		)
	return true


static func can_explosion_hit_hidden(context: AttackContext) -> bool:
	return (
		context != null
		and (
			bool(context.metadata.get("source_can_reveal", false))
			or int(context.metadata.get("charred_clothes", 0)) > 0
		)
	)
