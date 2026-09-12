class_name ProceduralBattlefield
extends "res://tower_defense_map.gd"

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")
const FlowField = preload("res://procedural_map/terrain_flow_field.gd")

const DEFAULT_SEED := 481516
const SPAWN_ROWS: Array[int] = [1, 3, 5, 7, 8]

@export var generation_seed := DEFAULT_SEED

var generator := Generator.new()
var flow_field := FlowField.new()
var terrain_textures: Dictionary = {}
var tower_origins_by_instance: Dictionary = {}


func _ready() -> void:
	_load_terrain_textures()
	_create_spawn_paths()
	super._ready()
	generator.generate(generation_seed)
	_rebuild_weighted_routes()
	queue_redraw()


func _draw() -> void:
	var tile_size := Vector2.ONE * Terrain.TILE_SIZE
	for y in Generator.GRID_SIZE.y:
		for x in Generator.GRID_SIZE.x:
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
	if not generator.contains(cell):
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
	for row in SPAWN_ROWS:
		var path := Path2D.new()
		path.name = "row_%02d" % row
		path.curve = Curve2D.new()
		paths_root.add_child(path)


func _rebuild_weighted_routes() -> void:
	var tower_origins: Array[Vector2i] = []
	for origin in tower_origins_by_instance.values():
		tower_origins.append(origin as Vector2i)
	flow_field.rebuild(generator.cells, Generator.GRID_SIZE, tower_origins)

	var paths := get_enemy_paths()
	for path_index in mini(paths.size(), SPAWN_ROWS.size()):
		_update_path_curve(paths[path_index], SPAWN_ROWS[path_index])


func _update_path_curve(path: Path2D, spawn_row: int) -> void:
	var follower_positions: Dictionary = {}
	for child in path.get_children():
		if child is PathFollow2D:
			follower_positions[child] = (child as PathFollow2D).global_position

	var route := flow_field.trace_route(Vector2i(0, spawn_row))
	assert(not route.is_empty(), "Procedural battlefield requires a route to the exit")
	var new_curve := Curve2D.new()
	new_curve.add_point(Vector2(-Terrain.TILE_SIZE, _cell_center_y(spawn_row)))
	for cell in route:
		new_curve.add_point(
			Vector2(cell * Terrain.TILE_SIZE)
			+ Vector2.ONE * Terrain.TILE_SIZE * 0.5
		)
	new_curve.add_point(Vector2(
		Generator.GRID_SIZE.x * Terrain.TILE_SIZE + Terrain.TILE_SIZE,
		_cell_center_y(route[-1].y)
	))
	path.curve = new_curve

	for follower in follower_positions:
		var path_follow := follower as PathFollow2D
		var old_global_position: Vector2 = follower_positions[follower]
		path_follow.progress = new_curve.get_closest_offset(
			path.to_local(old_global_position)
		)


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
