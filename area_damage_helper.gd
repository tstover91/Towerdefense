class_name AreaDamageHelper
extends RefCounted

const SPATIAL_CELL_SIZE := 128.0
const LARGE_TARGET_PADDING := 48.0

static var _cached_tree_id := 0
static var _cached_physics_frame := -1
static var _cached_target_count := -1
static var _cached_targets: Array = []
static var _cached_spatial_buckets: Dictionary = {}


static func get_all_targets(scene_tree: SceneTree) -> Array:
	_refresh_target_cache(scene_tree)
	return _cached_targets


static func get_targets_near(
	scene_tree: SceneTree,
	center: Vector2,
	radius: float
) -> Array:
	_refresh_target_cache(scene_tree)
	var result: Array = []
	var padded_radius := maxf(radius, 0.0) + LARGE_TARGET_PADDING
	var minimum_cell := _get_spatial_cell(center - Vector2.ONE * padded_radius)
	var maximum_cell := _get_spatial_cell(center + Vector2.ONE * padded_radius)
	for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
		for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
			var bucket: Array = _cached_spatial_buckets.get(
				Vector2i(cell_x, cell_y), []
			)
			result.append_array(bucket)
	return result


static func _refresh_target_cache(scene_tree: SceneTree) -> void:
	var physics_frame := Engine.get_physics_frames()
	var target_count := scene_tree.get_node_count_in_group("mobs")
	if (
		_cached_tree_id == scene_tree.get_instance_id()
		and _cached_physics_frame == physics_frame
		and _cached_target_count == target_count
	):
		return
	_cached_tree_id = scene_tree.get_instance_id()
	_cached_physics_frame = physics_frame
	_cached_target_count = target_count
	_cached_targets = scene_tree.get_nodes_in_group("mobs")
	_cached_spatial_buckets.clear()
	for candidate in _cached_targets:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var cell := _get_spatial_cell(candidate.global_position)
		if not _cached_spatial_buckets.has(cell):
			_cached_spatial_buckets[cell] = []
		_cached_spatial_buckets[cell].append(candidate)


static func _get_spatial_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / SPATIAL_CELL_SIZE),
		floori(world_position.y / SPATIAL_CELL_SIZE)
	)


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
	for mob in get_targets_near(scene_tree, center, radius):
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
