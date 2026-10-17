class_name PrototypeMapLayoutGenerator
extends RefCounted

const GridRouterScript = preload("res://prototype/grid_route_service.gd")
const QualityEvaluatorScript = preload("res://prototype/prototype_map_quality_evaluator.gd")
const WAYPOINT_COUNT := 3
const MAX_CANDIDATES := 64
const MIN_ROUTE_STEPS := 36
const MAX_ROUTE_STEPS := 48
const MAX_BACKWARD_COLUMNS := 2
const MIN_ENDPOINT_DISTANCE := 10
const MIN_MARKER_DISTANCE := 4
const MIN_SEGMENT_STEPS := 6
const MAX_SEGMENT_STEPS := 20


func generate(seed: int, grid_size: Vector2i, static_objects: Array[Vector2i]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var target_steps := rng.randi_range(39, 45)
	var quality_evaluator: RefCounted = QualityEvaluatorScript.new()
	var best_layout: Dictionary = {}
	var best_score := -INF
	for _candidate_index in MAX_CANDIDATES:
		var entrance := Vector2i(0, rng.randi_range(1, grid_size.y - 2))
		var exit_cell := Vector2i(grid_size.x - 1, rng.randi_range(1, grid_size.y - 2))
		if entrance == exit_cell or _manhattan(entrance, exit_cell) < MIN_ENDPOINT_DISTANCE:
			continue
		if static_objects.has(entrance) or static_objects.has(exit_cell):
			continue
		var waypoints := _random_waypoints(rng, grid_size, static_objects, entrance, exit_cell)
		if waypoints.size() != WAYPOINT_COUNT or not _respects_backward_limit(entrance, waypoints):
			continue
		var router: RefCounted = GridRouterScript.new()
		router.configure(grid_size, entrance, waypoints, exit_cell, static_objects)
		var route: Array[Vector2i] = router.find_complete_route(entrance)
		var route_steps := route.size() - 1
		if route.is_empty() or route_steps < MIN_ROUTE_STEPS or route_steps > MAX_ROUTE_STEPS:
			continue
		if not _segments_are_balanced(route, waypoints, exit_cell):
			continue
		if not _route_visits_markers_once(route, entrance, waypoints, exit_cell):
			continue
		var quality: Dictionary = quality_evaluator.evaluate(
			grid_size, route, entrance, waypoints, exit_cell, static_objects
		)
		if not quality_evaluator.is_acceptable(quality):
			continue
		var score := -absf(float(route_steps - target_steps))
		# Prefer markers that use both dimensions without forcing every map into
		# the same left-to-right shape.
		var marker_bounds := _marker_bounds(entrance, waypoints, exit_cell)
		score += float(marker_bounds.size.x + marker_bounds.size.y) * 0.12
		score += float(quality["turns"]) * 0.10
		score -= float(quality["close_revisits"]) * 0.025
		score -= float(quality["best_coverage_ratio"]) * 2.0
		if score > best_score:
			best_score = score
			best_layout = {
				"seed": seed,
				"entrance": entrance,
				"waypoints": waypoints,
				"exit_cell": exit_cell,
				"route": route,
				"route_steps": route_steps,
				"has_backward_leg": _has_backward_leg(entrance, waypoints),
				"quality": quality,
			}
	return best_layout


func _random_waypoints(
	rng: RandomNumberGenerator,
	grid_size: Vector2i,
	static_objects: Array[Vector2i],
	entrance: Vector2i,
	exit_cell: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var attempts := 0
	while result.size() < WAYPOINT_COUNT and attempts < 80:
		attempts += 1
		var cell := Vector2i(
			rng.randi_range(1, grid_size.x - 2),
			rng.randi_range(1, grid_size.y - 2)
		)
		if static_objects.has(cell) or result.has(cell):
			continue
		var previous := entrance if result.is_empty() else result[-1]
		if cell.x < previous.x - MAX_BACKWARD_COLUMNS:
			continue
		var all_markers: Array[Vector2i] = [entrance, exit_cell]
		all_markers.append_array(result)
		var too_close := false
		for marker in all_markers:
			if _manhattan(cell, marker) < MIN_MARKER_DISTANCE:
				too_close = true
				break
		if too_close:
			continue
		if result.is_empty():
			if _manhattan(entrance, cell) < MIN_SEGMENT_STEPS:
				continue
		elif _manhattan(result[-1], cell) < MIN_SEGMENT_STEPS:
			continue
		result.append(cell)
	if result.size() == WAYPOINT_COUNT and _manhattan(result[-1], exit_cell) < MIN_SEGMENT_STEPS:
		result.clear()
	return result


func _respects_backward_limit(entrance: Vector2i, waypoints: Array[Vector2i]) -> bool:
	var previous := entrance
	for waypoint in waypoints:
		if waypoint.x < previous.x - MAX_BACKWARD_COLUMNS:
			return false
		previous = waypoint
	return true


func _has_backward_leg(entrance: Vector2i, waypoints: Array[Vector2i]) -> bool:
	var previous := entrance
	for waypoint in waypoints:
		if waypoint.x < previous.x:
			return true
		previous = waypoint
	return false


func _segments_are_balanced(
	route: Array[Vector2i],
	waypoints: Array[Vector2i],
	exit_cell: Vector2i
) -> bool:
	var targets: Array[Vector2i] = waypoints.duplicate()
	targets.append(exit_cell)
	var previous_index := 0
	for target in targets:
		var found_index := -1
		for route_index in range(previous_index, route.size()):
			if route[route_index] == target:
				found_index = route_index
				break
		var segment_steps := found_index - previous_index
		if found_index < 0 or segment_steps < MIN_SEGMENT_STEPS or segment_steps > MAX_SEGMENT_STEPS:
			return false
		previous_index = found_index
	return true


func _route_visits_markers_once(
	route: Array[Vector2i],
	entrance: Vector2i,
	waypoints: Array[Vector2i],
	exit_cell: Vector2i
) -> bool:
	var markers: Array[Vector2i] = [entrance]
	markers.append_array(waypoints)
	markers.append(exit_cell)
	for marker in markers:
		var visits := 0
		for cell in route:
			if cell == marker:
				visits += 1
		if visits != 1:
			return false
	return true


func _marker_bounds(entrance: Vector2i, waypoints: Array[Vector2i], exit_cell: Vector2i) -> Rect2i:
	var minimum := entrance.min(exit_cell)
	var maximum := entrance.max(exit_cell)
	for waypoint in waypoints:
		minimum = minimum.min(waypoint)
		maximum = maximum.max(waypoint)
	return Rect2i(minimum, maximum - minimum)


func _manhattan(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)
