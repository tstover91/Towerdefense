class_name TerrainFlowField
extends RefCounted

const Terrain = preload("res://procedural_map/terrain_catalog.gd")

const TOWER_FOOTPRINT_CELLS := Vector2i(2, 2)
const TOWER_ROUTE_COST := 10.0
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

var grid_size := Vector2i.ZERO
var terrain_cells: Array[int] = []
var tower_cells: Dictionary = {}
var integrated_costs: PackedFloat32Array = PackedFloat32Array()
var next_cells: Array[Vector2i] = []


func rebuild(
	new_terrain_cells: Array[int],
	new_grid_size: Vector2i,
	tower_origins: Array[Vector2i]
) -> void:
	grid_size = new_grid_size
	terrain_cells = new_terrain_cells.duplicate()
	_build_tower_cell_lookup(tower_origins)

	var cell_count := grid_size.x * grid_size.y
	integrated_costs.resize(cell_count)
	integrated_costs.fill(INF)
	next_cells.resize(cell_count)
	next_cells.fill(Vector2i(-1, -1))

	var open_cells: Array[Vector2i] = []
	for y in grid_size.y:
		var exit_cell := Vector2i(grid_size.x - 1, y)
		integrated_costs[_index(exit_cell)] = 0.0
		open_cells.append(exit_cell)

	while not open_cells.is_empty():
		var cheapest_index := _find_cheapest_open_index(open_cells)
		var current: Vector2i = open_cells.pop_at(cheapest_index)
		var current_cost := integrated_costs[_index(current)]
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not contains(neighbor):
				continue
			var candidate_cost := current_cost + get_traversal_cost(current)
			var neighbor_index := _index(neighbor)
			if candidate_cost + 0.0001 >= integrated_costs[neighbor_index]:
				continue
			integrated_costs[neighbor_index] = candidate_cost
			next_cells[neighbor_index] = current
			if not open_cells.has(neighbor):
				open_cells.append(neighbor)


func contains(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)


func get_next_cell(cell: Vector2i) -> Vector2i:
	if not contains(cell):
		return Vector2i(-1, -1)
	return next_cells[_index(cell)]


func get_integrated_cost(cell: Vector2i) -> float:
	if not contains(cell):
		return INF
	return integrated_costs[_index(cell)]


func get_traversal_cost(cell: Vector2i) -> float:
	if not contains(cell):
		return INF
	var terrain_type := terrain_cells[_index(cell)]
	var base_cost := float(Terrain.get_data(terrain_type)["route_cost"])
	return base_cost + (TOWER_ROUTE_COST if tower_cells.has(cell) else 0.0)


func is_tower_cell(cell: Vector2i) -> bool:
	return tower_cells.has(cell)


func trace_route(start: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	if not contains(start):
		return route
	var current := start
	var visited: Dictionary = {}
	for _step in range(grid_size.x * grid_size.y + 1):
		route.append(current)
		if current.x == grid_size.x - 1:
			return route
		if visited.has(current):
			return []
		visited[current] = true
		current = get_next_cell(current)
		if not contains(current):
			return []
	return []


func _build_tower_cell_lookup(tower_origins: Array[Vector2i]) -> void:
	tower_cells.clear()
	for origin in tower_origins:
		for y_offset in TOWER_FOOTPRINT_CELLS.y:
			for x_offset in TOWER_FOOTPRINT_CELLS.x:
				var cell := origin + Vector2i(x_offset, y_offset)
				if contains(cell):
					tower_cells[cell] = true


func _find_cheapest_open_index(open_cells: Array[Vector2i]) -> int:
	var cheapest_index := 0
	var cheapest_cost := integrated_costs[_index(open_cells[0])]
	for index in range(1, open_cells.size()):
		var candidate_cost := integrated_costs[_index(open_cells[index])]
		if candidate_cost < cheapest_cost:
			cheapest_cost = candidate_cost
			cheapest_index = index
	return cheapest_index


func _index(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x
