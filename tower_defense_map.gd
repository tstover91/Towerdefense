class_name TowerDefenseMap
extends Node2D

@export var map_id: StringName = &""
@export var display_name := "Map"
@export var native_build_bounds := Rect2(0.0, 0.0, 960.0, 648.0)
@export var path_no_build_radius := 30.0

@onready var paths_root: Node = $Paths

var runtime_build_bounds := Rect2()


func _ready() -> void:
	assert(not map_id.is_empty(), "TowerDefenseMap requires a map_id")
	assert(not get_enemy_paths().is_empty(), "%s requires at least one Path2D" % map_id)
	for path in get_enemy_paths():
		assert(path.curve != null, "Map path %s requires a Curve2D" % path.name)
	if runtime_build_bounds.size.is_zero_approx():
		runtime_build_bounds = native_build_bounds


func configure_runtime_build_bounds(available_bounds: Rect2) -> void:
	runtime_build_bounds = native_build_bounds.intersection(available_bounds)


func get_build_bounds() -> Rect2:
	return native_build_bounds if runtime_build_bounds.size.is_zero_approx() else runtime_build_bounds


func get_enemy_paths() -> Array[Path2D]:
	var paths: Array[Path2D] = []
	var root := paths_root
	if root == null:
		root = get_node_or_null("Paths")
	if root == null:
		return paths
	for child in root.get_children():
		if child is Path2D:
			paths.append(child as Path2D)
	return paths


func get_enemy_path(path_id: StringName = &"") -> Path2D:
	var paths := get_enemy_paths()
	if paths.is_empty():
		return null
	if path_id.is_empty():
		return paths[0]
	for path in paths:
		if StringName(path.name) == path_id:
			return path
	return null


func get_path_id(path: Path2D) -> StringName:
	var root := paths_root
	if root == null:
		root = get_node_or_null("Paths")
	if path == null or path.get_parent() != root:
		return &""
	return StringName(path.name)


func get_distance_to_nearest_path(world_position: Vector2) -> float:
	var nearest_distance := INF
	for path in get_enemy_paths():
		if path.curve == null:
			continue
		var closest_local := path.curve.get_closest_point(path.to_local(world_position))
		var closest_global := path.to_global(closest_local)
		nearest_distance = minf(nearest_distance, world_position.distance_to(closest_global))
	return nearest_distance


func is_point_blocked_by_path(world_position: Vector2) -> bool:
	return get_distance_to_nearest_path(world_position) <= path_no_build_radius


func contains_world_position(world_position: Vector2) -> bool:
	var bounds := get_build_bounds()
	return (
		world_position.x >= bounds.position.x
		and world_position.y >= bounds.position.y
		and world_position.x <= bounds.end.x
		and world_position.y <= bounds.end.y
	)
