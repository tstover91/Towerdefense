extends Node

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")
const FlowField = preload("res://procedural_map/terrain_flow_field.gd")
const PROCEDURAL_MAP = preload(
	"res://procedural_map/procedural_battlefield.tscn"
)


func _ready() -> void:
	var first := Generator.new()
	var second := Generator.new()
	var first_cells: Array[int] = first.generate(12345)
	var second_cells: Array[int] = second.generate(12345)
	assert(first_cells == second_cells)
	assert(first_cells.size() == Generator.GRID_SIZE.x * Generator.GRID_SIZE.y)
	assert(first.count_terrain(Terrain.TerrainType.FIELD) > 0)
	assert(first.count_terrain(Terrain.TerrainType.FOREST) > 0)
	assert(first.count_terrain(Terrain.TerrainType.MUD) > 0)
	for y in Generator.GRID_SIZE.y:
		for x in Generator.EDGE_CLEARANCE_COLUMNS:
			assert(first.get_terrain(Vector2i(x, y)) == Terrain.TerrainType.FIELD)
			assert(first.get_terrain(Vector2i(Generator.GRID_SIZE.x - 1 - x, y)) == Terrain.TerrainType.FIELD)
	_assert_generated_routes_bend(first)
	_test_weighted_routes()
	_test_playable_map()
	print("Procedural terrain smoke test passed: generation, routing, passable tower weights, and playable map integration.")
	get_tree().quit(0)


func _test_weighted_routes() -> void:
	var all_field: Array[int] = []
	all_field.resize(Generator.GRID_SIZE.x * Generator.GRID_SIZE.y)
	all_field.fill(Terrain.TerrainType.FIELD)
	var flow := FlowField.new()
	flow.rebuild(all_field, Generator.GRID_SIZE, [])
	var straight_route := flow.trace_route(Vector2i(0, 5))
	assert(not straight_route.is_empty())
	assert(straight_route.all(func(cell: Vector2i) -> bool: return cell.y == 5))

	var tower_origin := Vector2i(8, 5)
	flow.rebuild(all_field, Generator.GRID_SIZE, [tower_origin])
	var diverted_route := flow.trace_route(Vector2i(0, 5))
	assert(not diverted_route.is_empty())
	assert(not diverted_route.has(tower_origin))
	assert(flow.get_traversal_cost(tower_origin) == 11.0)

	var single_forest_cell := Vector2i(8, 5)
	all_field[single_forest_cell.y * Generator.GRID_SIZE.x + single_forest_cell.x] = (
		Terrain.TerrainType.FOREST
	)
	flow.rebuild(all_field, Generator.GRID_SIZE, [])
	var short_crossing := flow.trace_route(Vector2i(0, 5))
	assert(short_crossing.has(single_forest_cell))
	all_field[single_forest_cell.y * Generator.GRID_SIZE.x + single_forest_cell.x] = (
		Terrain.TerrainType.FIELD
	)

	var tower_wall: Array[Vector2i] = []
	for y in Generator.GRID_SIZE.y:
		tower_wall.append(Vector2i(8, y))
	flow.rebuild(all_field, Generator.GRID_SIZE, tower_wall)
	var forced_route := flow.trace_route(Vector2i(0, 5))
	assert(not forced_route.is_empty())
	assert(forced_route.any(func(cell: Vector2i) -> bool: return flow.is_tower_cell(cell)))


func _assert_generated_routes_bend(generator: ProceduralTerrainGenerator) -> void:
	var flow := FlowField.new()
	flow.rebuild(generator.cells, Generator.GRID_SIZE, [])
	var bent_route_count := 0
	for spawn_row in [1, 3, 5, 7, 8]:
		var route := flow.trace_route(Vector2i(0, spawn_row))
		assert(not route.is_empty())
		if route.any(
			func(cell: Vector2i) -> bool: return cell.y != spawn_row
		):
			bent_route_count += 1
	assert(bent_route_count >= 3)


func _test_playable_map() -> void:
	var map := PROCEDURAL_MAP.instantiate() as ProceduralBattlefield
	add_child(map)
	assert(map.map_id == &"procedural_test")
	assert(map.get_build_bounds() == Rect2(0.0, 0.0, 1152.0, 640.0))
	assert(map.get_enemy_paths().size() == map.SPAWN_ROWS.size())
	for path in map.get_enemy_paths():
		assert(path.curve != null and path.curve.point_count > 2)

	var center_route := map.flow_field.trace_route(Vector2i(0, 5))
	var route_cell := center_route[center_route.size() / 2]
	var tower := Node2D.new()
	tower.position = (
		Vector2(route_cell * Terrain.TILE_SIZE)
		+ Vector2.ONE * Terrain.TILE_SIZE
	)
	map.add_child(tower)
	map.register_tower_route_weight(tower)
	var tower_origin := map.tower_origins_by_instance[tower.get_instance_id()] as Vector2i
	assert(map.flow_field.is_tower_cell(tower_origin))
	map.unregister_tower_route_weight(tower)
	assert(not map.flow_field.is_tower_cell(tower_origin))
	map.queue_free()
