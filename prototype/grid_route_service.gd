class_name PrototypeGridRouter
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]
const START_DIRECTION := 4
const TURN_COST := 0.08
const REVERSE_COST := 0.16

var grid_size := Vector2i.ZERO
var entrance := Vector2i.ZERO
var waypoints: Array[Vector2i] = []
var exit_cell := Vector2i.ZERO
var static_blocks: Dictionary = {}
var dynamic_blocks: Dictionary = {}


func configure(
	new_grid_size: Vector2i,
	new_entrance: Vector2i,
	new_waypoints: Array[Vector2i],
	new_exit: Vector2i,
	new_static_blocks: Array[Vector2i] = []
) -> void:
	grid_size = new_grid_size
	entrance = new_entrance
	waypoints.assign(new_waypoints)
	exit_cell = new_exit
	static_blocks.clear()
	for cell in new_static_blocks:
		if is_inside_grid(cell) and not is_route_marker(cell):
			static_blocks[cell] = true
	dynamic_blocks.clear()


func get_route_markers() -> Array[Vector2i]:
	var markers: Array[Vector2i] = [entrance]
	markers.append_array(waypoints)
	markers.append(exit_cell)
	return markers


func get_remaining_checkpoints(next_checkpoint_index: int) -> Array[Vector2i]:
	var checkpoints: Array[Vector2i] = []
	checkpoints.append_array(waypoints)
	checkpoints.append(exit_cell)
	var first_index := clampi(next_checkpoint_index, 0, checkpoints.size())
	return checkpoints.slice(first_index)


func get_checkpoint(checkpoint_index: int) -> Vector2i:
	if checkpoint_index >= 0 and checkpoint_index < waypoints.size():
		return waypoints[checkpoint_index]
	return exit_cell


func get_checkpoint_count() -> int:
	return waypoints.size() + 1


func is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)


func is_route_marker(cell: Vector2i) -> bool:
	return cell == entrance or cell == exit_cell or waypoints.has(cell)


func is_blocked(cell: Vector2i, blocks_override: Dictionary = {}) -> bool:
	if static_blocks.has(cell):
		return true
	var active_dynamic_blocks := (
		blocks_override if not blocks_override.is_empty() else dynamic_blocks
	)
	return active_dynamic_blocks.has(cell)


func add_dynamic_block(cell: Vector2i) -> void:
	if is_inside_grid(cell) and not is_route_marker(cell) and not static_blocks.has(cell):
		dynamic_blocks[cell] = true


func remove_dynamic_block(cell: Vector2i) -> void:
	dynamic_blocks.erase(cell)


func clear_dynamic_blocks() -> void:
	dynamic_blocks.clear()


func can_add_dynamic_block(
	cell: Vector2i,
	active_route_states: Array[Dictionary] = []
) -> bool:
	if (
		not is_inside_grid(cell)
		or is_route_marker(cell)
		or static_blocks.has(cell)
		or dynamic_blocks.has(cell)
	):
		return false
	for route_state in active_route_states:
		var occupied_cells: Array = route_state.get("occupied_cells", [])
		if occupied_cells.is_empty():
			occupied_cells = [route_state.get("cell", Vector2i(-1, -1))]
		for occupied_cell in occupied_cells:
			if Vector2i(occupied_cell) == cell:
				return false
	var candidate_blocks := dynamic_blocks.duplicate()
	candidate_blocks[cell] = true
	if find_complete_route(entrance, 0, candidate_blocks).is_empty():
		return false
	for route_state in active_route_states:
		var route_cell := Vector2i(route_state.get("cell", entrance))
		var next_checkpoint_index := int(route_state.get("next_checkpoint_index", 0))
		if find_complete_route(
			route_cell,
			next_checkpoint_index,
			candidate_blocks
		).is_empty():
			return false
	return true


func find_complete_route(
	start: Vector2i,
	next_checkpoint_index: int = 0,
	blocks_override: Dictionary = {}
) -> Array[Vector2i]:
	if not is_inside_grid(start):
		return []
	var active_blocks := (
		blocks_override if not blocks_override.is_empty() else dynamic_blocks
	)
	if static_blocks.has(start) or active_blocks.has(start):
		return []
	var complete_route: Array[Vector2i] = []
	var cursor := start
	for target in get_remaining_checkpoints(next_checkpoint_index):
		var segment := _find_path(cursor, target, active_blocks)
		if segment.is_empty():
			return []
		if not complete_route.is_empty():
			segment.pop_front()
		complete_route.append_array(segment)
		cursor = target
	return complete_route


func _find_path(
	start: Vector2i,
	goal: Vector2i,
	active_dynamic_blocks: Dictionary
) -> Array[Vector2i]:
	if start == goal:
		return [start]
	var start_state := Vector3i(start.x, start.y, START_DIRECTION)
	var open_states: Array[Vector3i] = [start_state]
	var open_lookup: Dictionary = {start_state: true}
	var came_from: Dictionary = {}
	var route_cost: Dictionary = {start_state: 0.0}
	var closed: Dictionary = {}
	var goal_state := Vector3i(-1, -1, -1)

	while not open_states.is_empty():
		var best_open_index := 0
		var best_score := INF
		for index in open_states.size():
			var candidate_state := open_states[index]
			var candidate_cell := Vector2i(candidate_state.x, candidate_state.y)
			var score := float(route_cost[candidate_state]) + _manhattan(candidate_cell, goal)
			if score < best_score:
				best_score = score
				best_open_index = index
		var current_state: Vector3i = open_states.pop_at(best_open_index)
		open_lookup.erase(current_state)
		if closed.has(current_state):
			continue
		closed[current_state] = true
		var current_cell := Vector2i(current_state.x, current_state.y)
		if current_cell == goal:
			goal_state = current_state
			break

		for direction_index in DIRECTIONS.size():
			var next_cell := current_cell + DIRECTIONS[direction_index]
			if (
				not is_inside_grid(next_cell)
				or static_blocks.has(next_cell)
				or active_dynamic_blocks.has(next_cell)
			):
				continue
			var next_state := Vector3i(next_cell.x, next_cell.y, direction_index)
			var step_cost := 1.0
			if current_state.z != START_DIRECTION and current_state.z != direction_index:
				step_cost += TURN_COST
				if (current_state.z + 2) % DIRECTIONS.size() == direction_index:
					step_cost += REVERSE_COST
			var proposed_cost := float(route_cost[current_state]) + step_cost
			if proposed_cost + 0.0001 >= float(route_cost.get(next_state, INF)):
				continue
			came_from[next_state] = current_state
			route_cost[next_state] = proposed_cost
			if closed.has(next_state):
				closed.erase(next_state)
			if not open_lookup.has(next_state):
				open_states.append(next_state)
				open_lookup[next_state] = true

	if goal_state.z < 0:
		return []
	var reversed_route: Array[Vector2i] = []
	var cursor_state := goal_state
	while true:
		var route_cell := Vector2i(cursor_state.x, cursor_state.y)
		if reversed_route.is_empty() or reversed_route[-1] != route_cell:
			reversed_route.append(route_cell)
		if cursor_state == start_state:
			break
		if not came_from.has(cursor_state):
			return []
		cursor_state = came_from[cursor_state]
	reversed_route.reverse()
	return reversed_route


func _manhattan(first: Vector2i, second: Vector2i) -> float:
	return float(absi(first.x - second.x) + absi(first.y - second.y))
