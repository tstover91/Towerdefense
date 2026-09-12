class_name TerrainFlowField
extends RefCounted

const Terrain = preload("res://procedural_map/terrain_catalog.gd")

const TOWER_FOOTPRINT_CELLS := Vector2i(2, 2)
const TOWER_ROUTE_COST := 10.0
const TURN_COST := 0.22
const U_TURN_COST := 0.65
const HARDER_TERRAIN_ENTRY_COST := 0.20
const TERRAIN_CLUSTER_COST := 0.08
const ROUTE_VARIANT_BIAS_COST := 0.045
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
const NO_DIRECTION := 4
const DIRECTION_STATE_COUNT := 5

var grid_size := Vector2i.ZERO
var terrain_cells: Array[int] = []
var tower_cells: Dictionary = {}
var integrated_costs: PackedFloat32Array = PackedFloat32Array()
var next_cells: Array[Vector2i] = []
var directional_costs: PackedFloat32Array = PackedFloat32Array()
var next_directions: PackedInt32Array = PackedInt32Array()
var navigation_bounds := Rect2i()
var blocked_navigation_cells: Dictionary = {}
var exit_cells: Dictionary = {}
var route_vertical_bias := 0


func rebuild(
	new_terrain_cells: Array[int],
	new_grid_size: Vector2i,
	tower_origins: Array[Vector2i],
	new_navigation_bounds := Rect2i(),
	new_blocked_navigation_cells: Array[Vector2i] = [],
	exit_rows: Array[int] = [],
	vertical_bias := 0
) -> void:
	grid_size = new_grid_size
	route_vertical_bias = clampi(vertical_bias, -1, 1)
	navigation_bounds = new_navigation_bounds
	if navigation_bounds.size == Vector2i.ZERO:
		navigation_bounds = Rect2i(Vector2i.ZERO, grid_size)
	blocked_navigation_cells.clear()
	for blocked_cell in new_blocked_navigation_cells:
		blocked_navigation_cells[blocked_cell] = true
	terrain_cells = new_terrain_cells.duplicate()
	_build_tower_cell_lookup(tower_origins)

	var cell_count := grid_size.x * grid_size.y
	directional_costs.resize(cell_count * DIRECTION_STATE_COUNT)
	directional_costs.fill(INF)
	next_directions.resize(cell_count * DIRECTION_STATE_COUNT)
	next_directions.fill(-1)

	var open_states: Array[int] = []
	var active_exit_rows := exit_rows
	if active_exit_rows.is_empty():
		for y in range(navigation_bounds.position.y, navigation_bounds.end.y):
			active_exit_rows.append(y)
	exit_cells.clear()
	for y in active_exit_rows:
		var exit_cell := Vector2i(grid_size.x - 1, y)
		if not is_navigable(exit_cell):
			continue
		exit_cells[exit_cell] = true
		for previous_direction in DIRECTION_STATE_COUNT:
			var exit_state := _state_index(exit_cell, previous_direction)
			directional_costs[exit_state] = 0.0
			open_states.append(exit_state)

	while not open_states.is_empty():
		var cheapest_index := _find_cheapest_open_state_index(open_states)
		var current_state: int = open_states.pop_at(cheapest_index)
		var current_cell := _cell_from_state(current_state)
		var arrival_direction := current_state % DIRECTION_STATE_COUNT
		if arrival_direction == NO_DIRECTION:
			continue
		var predecessor := current_cell - CARDINAL_DIRECTIONS[arrival_direction]
		if not is_navigable(predecessor):
			continue
		for predecessor_direction in DIRECTION_STATE_COUNT:
			var predecessor_state := _state_index(predecessor, predecessor_direction)
			var candidate_cost := (
				directional_costs[current_state]
				+ _get_step_cost(
					predecessor,
					current_cell,
					predecessor_direction,
					arrival_direction
				)
			)
			if candidate_cost + 0.0001 >= directional_costs[predecessor_state]:
				continue
			directional_costs[predecessor_state] = candidate_cost
			next_directions[predecessor_state] = arrival_direction
			if not open_states.has(predecessor_state):
				open_states.append(predecessor_state)

	# Preserve directionless accessors used by the preview and diagnostics.
	integrated_costs.resize(cell_count)
	next_cells.resize(cell_count)
	next_cells.fill(Vector2i(-1, -1))
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			var cell_index := _index(cell)
			var state := _state_index(cell, NO_DIRECTION)
			integrated_costs[cell_index] = directional_costs[state]
			var direction := next_directions[state]
			if direction >= 0:
				next_cells[cell_index] = cell + CARDINAL_DIRECTIONS[direction]


func contains(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)


func is_navigable(cell: Vector2i) -> bool:
	return (
		contains(cell)
		and navigation_bounds.has_point(cell)
		and not blocked_navigation_cells.has(cell)
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
	if not is_navigable(start):
		return route
	var current := start
	var previous_direction := NO_DIRECTION
	var visited: Dictionary = {}
	for _step in range(grid_size.x * grid_size.y * DIRECTION_STATE_COUNT + 1):
		route.append(current)
		if exit_cells.has(current):
			return route
		var state := _state_index(current, previous_direction)
		if visited.has(state):
			return []
		visited[state] = true
		var direction := next_directions[state]
		if direction < 0:
			return []
		current += CARDINAL_DIRECTIONS[direction]
		previous_direction = direction
		if not is_navigable(current):
			return []
	return []


func _get_step_cost(
	from_cell: Vector2i,
	to_cell: Vector2i,
	previous_direction: int,
	move_direction: int
) -> float:
	var cost := (
		get_traversal_cost(to_cell)
		+ _get_cluster_cost(to_cell)
		+ _get_route_variant_bias_cost(to_cell)
	)
	if previous_direction != NO_DIRECTION and previous_direction != move_direction:
		cost += TURN_COST
		if CARDINAL_DIRECTIONS[previous_direction] == -CARDINAL_DIRECTIONS[move_direction]:
			cost += U_TURN_COST
	var from_cost := get_traversal_cost(from_cell)
	var to_cost := get_traversal_cost(to_cell)
	if to_cost > from_cost:
		cost += (to_cost - from_cost) * HARDER_TERRAIN_ENTRY_COST
	return cost


func _get_route_variant_bias_cost(cell: Vector2i) -> float:
	if route_vertical_bias == 0 or grid_size.y <= 1:
		return 0.0
	var vertical_ratio := float(cell.y) / float(grid_size.y - 1)
	return ROUTE_VARIANT_BIAS_COST * (
		vertical_ratio if route_vertical_bias < 0 else 1.0 - vertical_ratio
	)


func _get_cluster_cost(cell: Vector2i) -> float:
	var own_cost := get_traversal_cost(cell)
	if own_cost <= 1.0 or is_tower_cell(cell):
		return 0.0
	var matching_neighbors := 0
	var terrain_type := terrain_cells[_index(cell)]
	for direction in CARDINAL_DIRECTIONS:
		var neighbor := cell + direction
		if contains(neighbor) and terrain_cells[_index(neighbor)] == terrain_type:
			matching_neighbors += 1
	return (own_cost - 1.0) * float(matching_neighbors) * TERRAIN_CLUSTER_COST


func _build_tower_cell_lookup(tower_origins: Array[Vector2i]) -> void:
	tower_cells.clear()
	for origin in tower_origins:
		for y_offset in TOWER_FOOTPRINT_CELLS.y:
			for x_offset in TOWER_FOOTPRINT_CELLS.x:
				var cell := origin + Vector2i(x_offset, y_offset)
				if contains(cell):
					tower_cells[cell] = true


func _find_cheapest_open_state_index(open_states: Array[int]) -> int:
	var cheapest_index := 0
	var cheapest_cost := directional_costs[open_states[0]]
	for index in range(1, open_states.size()):
		var candidate_cost := directional_costs[open_states[index]]
		if candidate_cost < cheapest_cost:
			cheapest_cost = candidate_cost
			cheapest_index = index
	return cheapest_index


func _state_index(cell: Vector2i, previous_direction: int) -> int:
	return _index(cell) * DIRECTION_STATE_COUNT + previous_direction


func _cell_from_state(state: int) -> Vector2i:
	var cell_index := state / DIRECTION_STATE_COUNT
	return Vector2i(cell_index % grid_size.x, cell_index / grid_size.x)


func _index(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x
