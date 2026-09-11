extends Node

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")
const FlowField = preload("res://procedural_map/terrain_flow_field.gd")


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
	_test_weighted_routes()
	print("Procedural terrain smoke test passed: generation, weighted routing, and passable 64x64 tower footprints.")
	get_tree().quit(0)


func _test_weighted_routes() -> void:
	var all_field: Array[int] = []
	all_field.resize(Generator.GRID_SIZE.x * Generator.GRID_SIZE.y)
	all_field.fill(Terrain.TerrainType.FIELD)
	var flow := FlowField.new()
	flow.rebuild(all_field, Generator.GRID_SIZE, [])
	var straight_route := flow.trace_route(Vector2i(0, 8))
	assert(not straight_route.is_empty())
	assert(straight_route.all(func(cell: Vector2i) -> bool: return cell.y == 8))

	var tower_origin := Vector2i(12, 8)
	flow.rebuild(all_field, Generator.GRID_SIZE, [tower_origin])
	var diverted_route := flow.trace_route(Vector2i(0, 8))
	assert(not diverted_route.is_empty())
	assert(not diverted_route.has(tower_origin))
	assert(flow.get_traversal_cost(tower_origin) == 11.0)

	var tower_wall: Array[Vector2i] = []
	for y in range(0, Generator.GRID_SIZE.y, 2):
		tower_wall.append(Vector2i(12, y))
	flow.rebuild(all_field, Generator.GRID_SIZE, tower_wall)
	var forced_route := flow.trace_route(Vector2i(0, 8))
	assert(not forced_route.is_empty())
	assert(forced_route.any(func(cell: Vector2i) -> bool: return flow.is_tower_cell(cell)))
