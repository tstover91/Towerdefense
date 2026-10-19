class_name SiegeGridRouter
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]


static func find_path(
	start: Vector2i,
	goals: Array[Vector2i],
	blocked_cells: Array[Vector2i],
	grid_size: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _inside(start, grid_size) or goals.is_empty():
		return result
	var blocked: Dictionary = {}
	for cell in blocked_cells:
		blocked[cell] = true
	blocked.erase(start)
	var goal_lookup: Dictionary = {}
	for goal in goals:
		if _inside(goal, grid_size) and not blocked.has(goal):
			goal_lookup[goal] = true
	if goal_lookup.is_empty():
		return result

	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var found := Vector2i(-1, -1)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if goal_lookup.has(current):
			found = current
			break
		for direction in CARDINAL_DIRECTIONS:
			var next := current + direction
			if not _inside(next, grid_size) or blocked.has(next) or came_from.has(next):
				continue
			came_from[next] = current
			frontier.append(next)
	if found.x < 0:
		return result

	var cursor := found
	result.push_front(cursor)
	while cursor != start:
		cursor = Vector2i(came_from[cursor])
		result.push_front(cursor)
	return result


static func get_adjacent_cells(occupied_cells: Array[Vector2i], grid_size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for occupied in occupied_cells:
		for direction in CARDINAL_DIRECTIONS:
			var candidate := occupied + direction
			if _inside(candidate, grid_size) and not occupied_cells.has(candidate) and not result.has(candidate):
				result.append(candidate)
	return result


static func manhattan_to_cells(cell: Vector2i, cells: Array[Vector2i]) -> int:
	var best := 1_000_000
	for target_cell in cells:
		best = mini(best, absi(cell.x - target_cell.x) + absi(cell.y - target_cell.y))
	return best


static func _inside(cell: Vector2i, grid_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y
