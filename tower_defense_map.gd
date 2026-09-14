class_name TowerDefenseMap
extends Node2D

@export var map_id: StringName = &""
@export var display_name := "Map"
@export var native_build_bounds := Rect2(0.0, 0.0, 960.0, 648.0)
@export var path_no_build_radius := 24.0
@export var expands_horizontally := true

@onready var paths_root: Node = $Paths
@onready var build_mask: TileMapLayer = get_node_or_null("BuildMask")
@onready var background: Sprite2D = get_node_or_null("Background")

var runtime_build_bounds := Rect2()
var background_extension: Sprite2D
var native_path_curves: Dictionary = {}


func _ready() -> void:
	assert(not map_id.is_empty(), "TowerDefenseMap requires a map_id")
	assert(not get_enemy_paths().is_empty(), "%s requires at least one Path2D" % map_id)
	for path in get_enemy_paths():
		assert(path.curve != null, "Map path %s requires a Curve2D" % path.name)
		native_path_curves[path.get_instance_id()] = path.curve.duplicate(true)
	if runtime_build_bounds.size.is_zero_approx():
		runtime_build_bounds = native_build_bounds
	if build_mask != null:
		build_mask.hide()


func configure_runtime_build_bounds(available_bounds: Rect2) -> void:
	var available_end := available_bounds.end
	var native_end := native_build_bounds.end
	var runtime_end := Vector2(
		available_end.x if expands_horizontally else minf(available_end.x, native_end.x),
		minf(available_end.y, native_end.y)
	)
	runtime_build_bounds = Rect2(
		native_build_bounds.position,
		Vector2(
			maxf(runtime_end.x - native_build_bounds.position.x, 0.0),
			maxf(runtime_end.y - native_build_bounds.position.y, 0.0)
		)
	)
	_update_background_extension()
	_update_edge_paths()


func _update_background_extension() -> void:
	if background == null or background.texture == null:
		return
	var extra_width := maxf(
		runtime_build_bounds.end.x - native_build_bounds.end.x, 0.0
	)
	if extra_width <= 0.0:
		if is_instance_valid(background_extension):
			background_extension.hide()
		return
	if not is_instance_valid(background_extension):
		background_extension = Sprite2D.new()
		background_extension.name = "RuntimeBackgroundExtension"
		background_extension.centered = false
		background_extension.z_index = background.z_index
		var edge_texture := AtlasTexture.new()
		edge_texture.atlas = background.texture
		var source_size := background.texture.get_size()
		var strip_width := minf(32.0, source_size.x)
		edge_texture.region = Rect2(
			source_size.x - strip_width,
			0.0,
			strip_width,
			source_size.y
		)
		background_extension.texture = edge_texture
		add_child(background_extension)
	var extension_texture_width := background_extension.texture.get_width()
	background_extension.position = Vector2(native_build_bounds.end.x, 0.0)
	background_extension.scale = Vector2(
		extra_width / maxf(extension_texture_width, 1.0),
		background.scale.y
	)
	background_extension.show()


func _update_edge_paths() -> void:
	for path in get_enemy_paths():
		var native_curve := native_path_curves.get(path.get_instance_id()) as Curve2D
		if native_curve == null:
			continue
		var runtime_curve := native_curve.duplicate(true) as Curve2D
		var last_index := runtime_curve.point_count - 1
		if last_index < 0:
			continue
		var right_edge := native_build_bounds.end.x
		var new_right_edge := runtime_build_bounds.end.x
		if new_right_edge <= right_edge:
			path.curve = runtime_curve
			continue
		var first_point := runtime_curve.get_point_position(0)
		if is_equal_approx(first_point.x, right_edge):
			first_point.x = new_right_edge
			runtime_curve.set_point_position(0, first_point)
		var last_point := runtime_curve.get_point_position(last_index)
		if is_equal_approx(last_point.x, right_edge) or last_point.x >= right_edge - 4.0:
			last_point.x = new_right_edge
			runtime_curve.set_point_position(last_index, last_point)
		path.curve = runtime_curve


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


func is_point_blocked_by_build_mask(world_position: Vector2) -> bool:
	if build_mask == null or build_mask.tile_set == null:
		return false
	var mask_cell := build_mask.local_to_map(build_mask.to_local(world_position))
	return build_mask.get_cell_source_id(mask_cell) >= 0


func contains_world_position(world_position: Vector2) -> bool:
	var bounds := get_build_bounds()
	return (
		world_position.x >= bounds.position.x
		and world_position.y >= bounds.position.y
		and world_position.x <= bounds.end.x
		and world_position.y <= bounds.end.y
	)
