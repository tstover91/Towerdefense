class_name SiegeGridRouter
extends RefCounted

const SQRT_TWO := 1.41421356237
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]


static func find_path(
	start: Vector2i,
	goals: Array[Vector2i],
	blocked_cells: Array[Vector2i],
	grid_size: Vector2i
) -> Array[Vector2i]:
	var route := find_weighted_path(start, goals, blocked_cells, {}, grid_size)
	if route.is_empty():
		return []
	var result: Array[Vector2i] = []
	result.assign(route.get("path", []))
	return result


static func find_weighted_path(
	start: Vector2i,
	goals: Array[Vector2i],
	hard_blocked_cells: Array[Vector2i],
	wall_costs: Dictionary,
	grid_size: Vector2i
) -> Dictionary:
	if not _inside(start, grid_size) or goals.is_empty():
		return {}
	var hard_blocked: Dictionary = {}
	for cell in hard_blocked_cells:
		hard_blocked[cell] = true
	hard_blocked.erase(start)
	var goal_lookup: Dictionary = {}
	for goal in goals:
		# A wall cell may itself be the closest valid attack position around a
		# tightly enclosed building. Let the weighted route reach that cell so
		# the attacker can breach it, then replan after the wall is destroyed.
		if _inside(goal, grid_size) and not hard_blocked.has(goal):
			goal_lookup[goal] = true
	if goal_lookup.is_empty():
		return {}

	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0.0}
	var priority: Dictionary = {start: _heuristic(start, goals)}
	var found := Vector2i(-1, -1)
	while not frontier.is_empty():
		var current_index := _lowest_priority_index(frontier, priority)
		var current: Vector2i = frontier.pop_at(current_index)
		if goal_lookup.has(current):
			found = current
			break
		for direction in ALL_DIRECTIONS:
			var next := current + direction
			if not _inside(next, grid_size) or hard_blocked.has(next):
				continue
			if direction.x != 0 and direction.y != 0 and not _diagonal_is_clear(current, direction, hard_blocked, wall_costs):
				continue
			var step_cost := SQRT_TWO if direction.x != 0 and direction.y != 0 else 1.0
			step_cost += float(wall_costs.get(next, 0.0))
			var next_cost := float(cost_so_far[current]) + step_cost
			if cost_so_far.has(next) and next_cost >= float(cost_so_far[next]):
				continue
			cost_so_far[next] = next_cost
			came_from[next] = current
			priority[next] = next_cost + _heuristic(next, goals)
			if not frontier.has(next):
				frontier.append(next)
	if found.x < 0:
		return {}

	var path: Array[Vector2i] = [found]
	var cursor := found
	while cursor != start:
		cursor = Vector2i(came_from[cursor])
		path.push_front(cursor)
	var crossed_walls: Array[Vector2i] = []
	for cell in path:
		if wall_costs.has(cell) and not crossed_walls.has(cell):
			crossed_walls.append(cell)
	return {
		"path": path,
		"cost": float(cost_so_far[found]),
		"crossed_walls": crossed_walls,
	}


static func get_adjacent_cells(occupied_cells: Array[Vector2i], grid_size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for occupied in occupied_cells:
		for direction in ALL_DIRECTIONS:
			var candidate := occupied + direction
			if _inside(candidate, grid_size) and not occupied_cells.has(candidate) and not result.has(candidate):
				result.append(candidate)
	return result


static func euclidean_to_cells(cell: Vector2i, cells: Array[Vector2i]) -> float:
	var best := INF
	for target_cell in cells:
		best = minf(best, Vector2(cell).distance_to(Vector2(target_cell)))
	return best


static func manhattan_to_cells(cell: Vector2i, cells: Array[Vector2i]) -> int:
	var best := 1_000_000
	for target_cell in cells:
		best = mini(best, absi(cell.x - target_cell.x) + absi(cell.y - target_cell.y))
	return best


static func _lowest_priority_index(frontier: Array[Vector2i], priority: Dictionary) -> int:
	var best_index := 0
	var best_priority := INF
	for index in frontier.size():
		var candidate_priority := float(priority.get(frontier[index], INF))
		if candidate_priority < best_priority:
			best_priority = candidate_priority
			best_index = index
	return best_index


static func _heuristic(cell: Vector2i, goals: Array[Vector2i]) -> float:
	return euclidean_to_cells(cell, goals)


static func _diagonal_is_clear(
	current: Vector2i,
	direction: Vector2i,
	hard_blocked: Dictionary,
	wall_costs: Dictionary
) -> bool:
	var horizontal := current + Vector2i(direction.x, 0)
	var vertical := current + Vector2i(0, direction.y)
	return (
		not hard_blocked.has(horizontal)
		and not hard_blocked.has(vertical)
		and not wall_costs.has(horizontal)
		and not wall_costs.has(vertical)
	)


static func _inside(cell: Vector2i, grid_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y
