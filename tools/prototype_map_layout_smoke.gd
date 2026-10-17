extends SceneTree

const GeneratorScript = preload("res://prototype/prototype_map_layout_generator.gd")
const RouterScript = preload("res://prototype/grid_route_service.gd")
const GRID_SIZE := Vector2i(19, 10)
const STATIC_OBJECTS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(7, 4), Vector2i(11, 5),
	Vector2i(12, 5), Vector2i(15, 7), Vector2i(4, 7), Vector2i(17, 8),
]

var failure_count := 0


func _init() -> void:
	var generator: RefCounted = GeneratorScript.new()
	var signatures: Dictionary = {}
	var layouts_with_backward_legs := 0
	var layouts_without_backward_legs := 0
	for seed in range(1, 41):
		var layout: Dictionary = generator.generate(seed, GRID_SIZE, STATIC_OBJECTS)
		_assert(not layout.is_empty(), "seed %d produces a valid layout" % seed)
		if layout.is_empty():
			continue
		var repeated: Dictionary = generator.generate(seed, GRID_SIZE, STATIC_OBJECTS)
		_assert(_signature(layout) == _signature(repeated), "seed %d is reproducible" % seed)
		var entrance := Vector2i(layout["entrance"])
		var exit_cell := Vector2i(layout["exit_cell"])
		var waypoints: Array[Vector2i] = []
		waypoints.assign(layout["waypoints"])
		var route: Array[Vector2i] = []
		route.assign(layout["route"])
		_assert(entrance.x == 0, "entrance is in the first column")
		_assert(exit_cell.x == GRID_SIZE.x - 1, "exit is in the last column")
		_assert(waypoints.size() == 3, "layout contains three waypoints")
		_assert(_respects_backward_limit(entrance, waypoints), "no waypoint sits more than two columns behind the previous marker")
		if bool(layout["has_backward_leg"]):
			layouts_with_backward_legs += 1
		else:
			layouts_without_backward_legs += 1
		_assert(route.size() - 1 >= 36 and route.size() - 1 <= 48, "route length stays in the shorter fairness envelope")
		_assert(_has_unique_edges(route), "generated route never retraces an edge")
		var ordered_targets: Array[Vector2i] = waypoints.duplicate()
		ordered_targets.append(exit_cell)
		_assert(_appears_in_order(route, ordered_targets), "route visits randomized markers in order")
		_assert(_markers_are_unique_visits(route, entrance, ordered_targets), "route does not pass a checkpoint before its turn")
		_assert(_segments_are_balanced(route, ordered_targets), "each route leg stays between 6 and 20 tiles")
		signatures[_signature(layout)] = true
	_assert(signatures.size() >= 32, "different seeds produce meaningfully varied marker layouts")
	_assert(layouts_with_backward_legs > 0, "some generated maps retain short backward legs")
	_assert(layouts_without_backward_legs > 0, "backward legs are no longer mandatory")
	_finish("PROTOTYPE_MAP_LAYOUT_SMOKE_OK")


func _signature(layout: Dictionary) -> String:
	return "%s|%s|%s" % [layout["entrance"], layout["waypoints"], layout["exit_cell"]]


func _respects_backward_limit(entrance: Vector2i, waypoints: Array[Vector2i]) -> bool:
	var previous := entrance
	for waypoint in waypoints:
		if waypoint.x < previous.x - 2:
			return false
		previous = waypoint
	return true


func _has_unique_edges(route: Array[Vector2i]) -> bool:
	var router: RefCounted = RouterScript.new()
	var used: Dictionary = {}
	for index in range(1, route.size()):
		var edge = router.get_edge_key(route[index - 1], route[index])
		if used.has(edge):
			return false
		used[edge] = true
	return true


func _appears_in_order(route: Array[Vector2i], targets: Array[Vector2i]) -> bool:
	var route_index := 0
	for target in targets:
		while route_index < route.size() and route[route_index] != target:
			route_index += 1
		if route_index >= route.size():
			return false
		route_index += 1
	return true


func _markers_are_unique_visits(
	route: Array[Vector2i],
	entrance: Vector2i,
	targets: Array[Vector2i]
) -> bool:
	var markers: Array[Vector2i] = [entrance]
	markers.append_array(targets)
	for marker in markers:
		if route.count(marker) != 1:
			return false
	return true


func _segments_are_balanced(route: Array[Vector2i], targets: Array[Vector2i]) -> bool:
	var previous_index := 0
	for target in targets:
		var target_index := route.find(target, previous_index)
		if target_index < 0:
			return false
		var segment_steps := target_index - previous_index
		if segment_steps < 6 or segment_steps > 20:
			return false
		previous_index = target_index
	return true


func _assert(condition: bool, description: String) -> void:
	if not condition:
		push_error("Prototype map layout smoke failed: %s" % description)
		failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
