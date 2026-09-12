class_name ProceduralBattlefield
extends "res://tower_defense_map.gd"

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")
const FlowField = preload("res://procedural_map/terrain_flow_field.gd")
const SeedSelector = preload("res://procedural_map/terrain_seed_selector.gd")
const GenerationProfile = preload(
	"res://procedural_map/terrain_generation_profile.gd"
)
const DEFAULT_GENERATION_PROFILE = preload(
	"res://procedural_map/farm_generation_profile.tres"
)

const DEFAULT_SEED := 481516
const CORNER_RADIUS := Terrain.TILE_SIZE * 0.24
const CURVE_HANDLE_RATIO := 0.55228475
const ROUTE_VARIANTS := {
	&"main": 0,
	&"upper": -1,
	&"lower": 1,
}

@export var generation_seed := 0
@export var generation_profile: Resource = DEFAULT_GENERATION_PROFILE

var generator := Generator.new()
var flow_field := FlowField.new()
var flow_fields: Dictionary = {}
var path_route_configs: Dictionary = {}
var terrain_textures: Dictionary = {}
var tower_origins_by_instance: Dictionary = {}
var spawn_rows: Array[int] = []
var active_generation_seed := 0
var generation_candidate_results: Array[Dictionary] = []


func _ready() -> void:
	generator.configure(generation_profile)
	native_build_bounds = Rect2(
		Vector2.ZERO,
		Vector2(generator.grid_size * Terrain.TILE_SIZE)
	)
	spawn_rows = _create_spawn_rows()
	_load_terrain_textures()
	_create_spawn_paths()
	super._ready()
	active_generation_seed = _select_generation_seed()
	generator.generate(active_generation_seed)
	_rebuild_weighted_routes()
	queue_redraw()


func _draw() -> void:
	var tile_size := Vector2.ONE * Terrain.TILE_SIZE
	for y in generator.grid_size.y:
		for x in generator.grid_size.x:
			var cell := Vector2i(x, y)
			var terrain_type := generator.get_terrain(cell)
			var texture := terrain_textures[terrain_type] as Texture2D
			draw_texture_rect(
				texture,
				Rect2(Vector2(cell * Terrain.TILE_SIZE), tile_size),
				false
			)


func configure_runtime_build_bounds(available_bounds: Rect2) -> void:
	runtime_build_bounds = native_build_bounds.intersection(available_bounds)


func is_point_blocked_by_path(_world_position: Vector2) -> bool:
	return false


func is_point_blocked_by_build_mask(world_position: Vector2) -> bool:
	var cell := Vector2i(floor(world_position / float(Terrain.TILE_SIZE)))
	if (
		not generator.contains(cell)
		or not _get_navigation_bounds().has_point(cell)
		or _is_in_protected_right_corner(cell)
	):
		return true
	var terrain_data := Terrain.get_data(generator.get_terrain(cell))
	return not bool(terrain_data["buildable"])


func register_tower_route_weight(tower: Node2D) -> void:
	if not is_instance_valid(tower):
		return
	var origin := _get_tower_navigation_origin(tower.position)
	tower_origins_by_instance[tower.get_instance_id()] = origin
	_rebuild_weighted_routes()


func unregister_tower_route_weight(tower: Node2D) -> void:
	if tower == null:
		return
	tower_origins_by_instance.erase(tower.get_instance_id())
	_rebuild_weighted_routes()


func get_terrain_type_at_world_position(world_position: Vector2) -> int:
	var cell := Vector2i(floor(world_position / float(Terrain.TILE_SIZE)))
	return generator.get_terrain(cell)


func get_terrain_speed_multiplier(world_position: Vector2) -> float:
	var terrain_type := get_terrain_type_at_world_position(world_position)
	return float(Terrain.get_data(terrain_type)["speed_multiplier"])


func _create_spawn_paths() -> void:
	flow_fields.clear()
	path_route_configs.clear()
	for variant_id in ROUTE_VARIANTS:
		var variant_flow := FlowField.new()
		flow_fields[variant_id] = variant_flow
		if variant_id == &"main":
			flow_field = variant_flow
	var combination_count := spawn_rows.size() * ROUTE_VARIANTS.size()
	var variant_ids: Array = ROUTE_VARIANTS.keys()
	for combination_index in combination_count:
		var row: int = spawn_rows[combination_index % spawn_rows.size()]
		var variant_id: StringName = variant_ids[combination_index % variant_ids.size()]
		var path := Path2D.new()
		path.name = "row_%02d_%s" % [row, variant_id]
		path.curve = Curve2D.new()
		paths_root.add_child(path)
		path_route_configs[path.get_instance_id()] = {
			"row": row,
			"variant": variant_id,
		}


func _rebuild_weighted_routes() -> void:
	var tower_origins: Array[Vector2i] = []
	for origin in tower_origins_by_instance.values():
		tower_origins.append(origin as Vector2i)
	for variant_id in ROUTE_VARIANTS:
		var variant_flow := flow_fields[variant_id] as TerrainFlowField
		variant_flow.rebuild(
			generator.cells,
			generator.grid_size,
			tower_origins,
			_get_navigation_bounds(),
			_get_blocked_navigation_cells(),
			_get_exit_rows(),
			int(ROUTE_VARIANTS[variant_id])
		)

	var paths := get_enemy_paths()
	for path in paths:
		var config := path_route_configs[path.get_instance_id()] as Dictionary
		_update_path_curve(
			path,
			int(config["row"]),
			flow_fields[config["variant"]] as TerrainFlowField
		)


func _update_path_curve(
	path: Path2D,
	spawn_row: int,
	route_flow: TerrainFlowField
) -> void:
	var follower_states: Dictionary = {}
	for child in path.get_children():
		if child is PathFollow2D:
			var path_follow := child as PathFollow2D
			var route_anchor := path_follow.global_position
			var tracked_children: Dictionary = {}
			for follower_child in path_follow.get_children():
				if follower_child is Node2D:
					var tracked_child := follower_child as Node2D
					tracked_children[tracked_child] = tracked_child.global_position
					if tracked_children.size() == 1:
						route_anchor = tracked_child.global_position
			follower_states[path_follow] = {
				"route_anchor": route_anchor,
				"children": tracked_children,
			}

	var route := route_flow.trace_route(Vector2i(0, spawn_row))
	assert(not route.is_empty(), "Procedural battlefield requires a route to the exit")
	var route_points: Array[Vector2] = [
		Vector2(-Terrain.TILE_SIZE, _cell_center_y(spawn_row))
	]
	for cell in route:
		route_points.append(
			Vector2(cell * Terrain.TILE_SIZE)
			+ Vector2.ONE * Terrain.TILE_SIZE * 0.5
		)
	route_points.append(Vector2(
		generator.grid_size.x * Terrain.TILE_SIZE + Terrain.TILE_SIZE,
		_cell_center_y(route[-1].y)
	))
	var new_curve := _create_smoothed_curve(route_points)
	path.curve = new_curve

	for follower in follower_states:
		var path_follow := follower as PathFollow2D
		var state := follower_states[follower] as Dictionary
		var old_global_position := state["route_anchor"] as Vector2
		path_follow.progress = new_curve.get_closest_offset(
			path.to_local(old_global_position)
		)
		var tracked_children := state["children"] as Dictionary
		for tracked_child in tracked_children:
			if not is_instance_valid(tracked_child):
				continue
			var previous_child_position := tracked_children[tracked_child] as Vector2
			if tracked_child.has_method("blend_from_reroute"):
				tracked_child.call("blend_from_reroute", previous_child_position)


func _create_smoothed_curve(points: Array[Vector2]) -> Curve2D:
	var curve := Curve2D.new()
	if points.size() <= 2:
		for point in points:
			curve.add_point(point)
		return curve

	curve.add_point(points[0])
	for index in range(1, points.size() - 1):
		var previous := points[index - 1]
		var current := points[index]
		var following := points[index + 1]
		var incoming := (current - previous).normalized()
		var outgoing := (following - current).normalized()
		if incoming.is_equal_approx(outgoing):
			continue
		var radius: float = minf(
			CORNER_RADIUS,
			minf(current.distance_to(previous), current.distance_to(following)) * 0.35
		)
		var before := current - incoming * radius
		var after := current + outgoing * radius
		curve.add_point(
			before,
			Vector2.ZERO,
			incoming * radius * CURVE_HANDLE_RATIO
		)
		curve.add_point(
			after,
			-outgoing * radius * CURVE_HANDLE_RATIO,
			Vector2.ZERO
		)
	curve.add_point(points[-1])
	return curve


func _load_terrain_textures() -> void:
	for terrain_type in Terrain.TERRAIN_DATA:
		var image := Image.load_from_file(
			ProjectSettings.globalize_path(Terrain.get_texture_path(terrain_type))
		)
		assert(not image.is_empty(), "Unable to load procedural terrain texture")
		terrain_textures[terrain_type] = ImageTexture.create_from_image(image)


func _get_tower_navigation_origin(tower_position: Vector2) -> Vector2i:
	var footprint_size := Vector2(
		FlowField.TOWER_FOOTPRINT_CELLS * Terrain.TILE_SIZE
	)
	return Vector2i(floor(
		(tower_position - footprint_size * 0.5)
		/ float(Terrain.TILE_SIZE)
	))


func _cell_center_y(row: int) -> float:
	return float(row * Terrain.TILE_SIZE) + Terrain.TILE_SIZE * 0.5


func _select_generation_seed() -> int:
	if generation_seed != 0:
		return generation_seed
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var selector := SeedSelector.new()
	var selection := selector.select_best_seed(
		rng.randi(),
		generation_profile,
		spawn_rows,
		_get_navigation_bounds(),
		_get_blocked_navigation_cells(),
		_get_exit_rows(),
		generation_profile.candidate_seed_count
	)
	generation_candidate_results = selector.candidate_results.duplicate(true)
	return int(selection["seed"])


func _create_spawn_rows() -> Array[int]:
	var rows: Array[int] = []
	var first_row: int = generation_profile.safe_top_rows
	var last_row: int = (
		generator.grid_size.y - generation_profile.safe_bottom_rows - 1
	)
	for lane_index in 5:
		var lane_ratio := float(lane_index) / 4.0
		rows.append(roundi(lerpf(float(first_row), float(last_row), lane_ratio)))
	return rows


func _get_navigation_bounds() -> Rect2i:
	return Rect2i(
		Vector2i(0, generation_profile.safe_top_rows),
		Vector2i(
			generator.grid_size.x,
			generator.grid_size.y
				- generation_profile.safe_top_rows
				- generation_profile.safe_bottom_rows
		)
	)


func _get_blocked_navigation_cells() -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for y in range(
		generation_profile.safe_top_rows,
		generation_profile.protected_right_top_rows
	):
		for x_offset in generation_profile.protected_right_columns:
			blocked.append(Vector2i(generator.grid_size.x - 1 - x_offset, y))
	for y in range(
		generator.grid_size.y - generation_profile.protected_right_bottom_rows,
		generator.grid_size.y - generation_profile.safe_bottom_rows
	):
		for x_offset in generation_profile.protected_right_columns:
			blocked.append(Vector2i(generator.grid_size.x - 1 - x_offset, y))
	return blocked


func _get_exit_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in range(
		generation_profile.exit_top_margin_rows,
		generator.grid_size.y - generation_profile.exit_bottom_margin_rows
	):
		rows.append(y)
	return rows


func _is_in_protected_right_corner(cell: Vector2i) -> bool:
	if cell.x < generator.grid_size.x - generation_profile.protected_right_columns:
		return false
	return (
		cell.y < generation_profile.protected_right_top_rows
		or cell.y
			>= generator.grid_size.y
				- generation_profile.protected_right_bottom_rows
	)
