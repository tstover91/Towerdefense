extends SceneTree

const GridRouterScript = preload("res://prototype/grid_route_service.gd")
const RouteFollowerScript = preload("res://prototype/grid_route_follower.gd")
const TEST_CELL_SIZE := 32.0

var failure_count := 0


func _init() -> void:
	var router: RefCounted = GridRouterScript.new()
	var grid_size := Vector2i(10, 7)
	var entrance := Vector2i(0, 3)
	var waypoints: Array[Vector2i] = [Vector2i(3, 1), Vector2i(6, 5)]
	var exit_cell := Vector2i(9, 3)
	router.configure(grid_size, entrance, waypoints, exit_cell)

	var initial_route: Array[Vector2i] = router.find_complete_route(entrance)
	_assert(not initial_route.is_empty(), "initial route exists")
	var expected_markers: Array[Vector2i] = []
	expected_markers.append_array(waypoints)
	expected_markers.append(exit_cell)
	_assert(_appears_in_order(initial_route, expected_markers), "route visits every marker in order")

	var first_open_route_cell: Vector2i = initial_route[1]
	_assert(router.can_add_dynamic_block(first_open_route_cell), "route can move around one tower")
	router.add_dynamic_block(first_open_route_cell)
	var changed_route: Array[Vector2i] = router.find_complete_route(entrance)
	_assert(not changed_route.is_empty(), "route remains open after legal placement")
	_assert(not changed_route.has(first_open_route_cell), "new route avoids placed tower")
	_assert(_has_unique_edges(router, changed_route), "every accepted route uses each edge once")

	router.clear_dynamic_blocks()
	for y in grid_size.y:
		if y == 3:
			continue
		var wall_cell := Vector2i(5, y)
		_assert(router.can_add_dynamic_block(wall_cell), "partial wall remains legal")
		router.add_dynamic_block(wall_cell)
	_assert(not router.can_add_dynamic_block(Vector2i(5, 3)), "last route gap cannot be blocked")

	var active_state: Array[Dictionary] = [{
		"cell": Vector2i(4, 3),
		"next_checkpoint_index": 1,
	}]
	_assert(not router.can_add_dynamic_block(Vector2i(4, 3), active_state), "cannot place on an active unit route anchor")
	router.remove_dynamic_block(Vector2i(5, 2))
	_assert(router.can_add_dynamic_block(Vector2i(5, 3), active_state), "opening another gap permits placement")

	_test_live_reroute(grid_size, entrance, waypoints, exit_cell)
	_test_active_enemy_rejoins_shared_route(grid_size, entrance, waypoints, exit_cell)
	_test_retracing_is_rejected()
	_test_perpendicular_crossing_is_allowed()
	_test_frame_independent_movement()
	_test_layout_remap()

	_finish("PROTOTYPE_GRID_ROUTING_SMOKE_OK")


func _test_active_enemy_rejoins_shared_route(
	grid_size: Vector2i,
	entrance: Vector2i,
	waypoints: Array[Vector2i],
	exit_cell: Vector2i
) -> void:
	var router: RefCounted = GridRouterScript.new()
	router.configure(grid_size, entrance, waypoints, exit_cell)
	var original_route: Array[Vector2i] = router.find_complete_route(entrance)
	var block_cell := original_route[3]
	var candidate_blocks: Dictionary = {block_cell: true}
	var new_main_route: Array[Vector2i] = router.find_complete_route(
		entrance,
		0,
		candidate_blocks
	)
	_assert(not new_main_route.is_empty(), "shared-route test has a valid changed main route")
	var enemy_anchor := original_route[2]
	var used_edges: Dictionary = {}
	used_edges[router.get_edge_key(original_route[0], original_route[1])] = true
	used_edges[router.get_edge_key(original_route[1], enemy_anchor)] = true
	var enemy_route: Array[Vector2i] = router.find_route_to_main(
		enemy_anchor,
		0,
		new_main_route,
		candidate_blocks,
		used_edges
	)
	_assert(not enemy_route.is_empty(), "active enemy receives a connector after the maze changes")
	_assert(_shares_suffix(enemy_route, new_main_route), "active enemy connector merges into the shared main route")
	_assert(_appears_in_order(enemy_route, [waypoints[0], waypoints[1], exit_cell]), "connector preserves every remaining waypoint")
	_assert(_has_unique_edges(router, enemy_route), "connector route does not retrace itself")
	for index in range(1, enemy_route.size()):
		_assert(not used_edges.has(router.get_edge_key(enemy_route[index - 1], enemy_route[index])), "connector does not reuse an edge already travelled")


func _test_retracing_is_rejected() -> void:
	var router: RefCounted = GridRouterScript.new()
	var waypoints: Array[Vector2i] = [Vector2i(4, 0)]
	router.configure(
		Vector2i(5, 1),
		Vector2i(0, 0),
		waypoints,
		Vector2i(0, 0)
	)
	_assert(
		router.find_complete_route(Vector2i(0, 0)).is_empty(),
		"a later waypoint segment cannot retrace an earlier route edge"
	)


func _test_perpendicular_crossing_is_allowed() -> void:
	var router: RefCounted = GridRouterScript.new()
	var waypoints: Array[Vector2i] = [Vector2i(4, 2), Vector2i(2, 0)]
	router.configure(
		Vector2i(5, 5),
		Vector2i(0, 2),
		waypoints,
		Vector2i(2, 4)
	)
	var route: Array[Vector2i] = router.find_complete_route(Vector2i(0, 2))
	_assert(not route.is_empty(), "a route may cross a previously visited tile")
	var crossing_visits := 0
	for cell in route:
		if cell == Vector2i(2, 2):
			crossing_visits += 1
	_assert(crossing_visits == 2, "the crossing tile is visited in both directions")
	var used_edges: Dictionary = {}
	var unique_edges := true
	for index in range(1, route.size()):
		var edge = router.get_edge_key(route[index - 1], route[index])
		if used_edges.has(edge):
			unique_edges = false
		used_edges[edge] = true
	_assert(unique_edges, "a crossing uses four distinct edges instead of retracing")


func _test_live_reroute(
	grid_size: Vector2i,
	entrance: Vector2i,
	waypoints: Array[Vector2i],
	exit_cell: Vector2i
) -> void:
	var live_router: RefCounted = GridRouterScript.new()
	live_router.configure(grid_size, entrance, waypoints, exit_cell)
	var follower: Node2D = RouteFollowerScript.new()
	get_root().add_child(follower)
	follower.configure(
		live_router,
		Callable(self, "_cell_center"),
		Callable(self, "_world_to_cell"),
		TEST_CELL_SIZE * 2.0
	)
	_assert(follower.begin(), "live route follower starts")
	follower._process(0.01)
	follower._process(0.20)
	var state_before: Dictionary = follower.get_route_state()
	var route_before: Array[Vector2i] = live_router.find_complete_route(
		Vector2i(state_before["cell"]),
		int(state_before["next_checkpoint_index"])
	)
	var active_states: Array[Dictionary] = [state_before]
	var reroute_block := Vector2i(-1, -1)
	for index in range(2, route_before.size()):
		var candidate: Vector2i = route_before[index]
		if live_router.can_add_dynamic_block(candidate, active_states):
			reroute_block = candidate
			break
	_assert(reroute_block.x >= 0, "found a legal route-changing placement")
	live_router.add_dynamic_block(reroute_block)
	var position_before_reroute := follower.position
	_assert(follower.reroute(), "moving unit receives a replacement route")
	_assert(
		follower.position.is_equal_approx(position_before_reroute),
		"rerouting preserves the moving unit's world position"
	)
	follower._process(0.10)
	_assert(
		follower.position.distance_to(position_before_reroute)
		<= TEST_CELL_SIZE * 2.0 * 0.10 + 0.01,
		"moving unit advances normally instead of teleporting"
	)
	follower.queue_free()


func _test_frame_independent_movement() -> void:
	var router: RefCounted = GridRouterScript.new()
	var no_waypoints: Array[Vector2i] = []
	router.configure(Vector2i(10, 1), Vector2i(0, 0), no_waypoints, Vector2i(9, 0))
	var follower: Node2D = RouteFollowerScript.new()
	get_root().add_child(follower)
	follower.configure(
		router,
		Callable(self, "_cell_center"),
		Callable(self, "_world_to_cell"),
		TEST_CELL_SIZE * 2.0
	)
	_assert(follower.begin(), "linear follower starts")
	var starting_position := follower.position
	follower._process(1.0)
	_assert(
		is_equal_approx(follower.position.x - starting_position.x, TEST_CELL_SIZE * 2.0),
		"one large frame consumes its full movement distance across multiple cells"
	)
	follower.queue_free()


func _test_layout_remap() -> void:
	var router: RefCounted = GridRouterScript.new()
	var no_waypoints: Array[Vector2i] = []
	router.configure(Vector2i(10, 1), Vector2i(0, 0), no_waypoints, Vector2i(9, 0))
	var follower: Node2D = RouteFollowerScript.new()
	get_root().add_child(follower)
	follower.configure(
		router,
		Callable(self, "_cell_center"),
		Callable(self, "_world_to_cell"),
		TEST_CELL_SIZE
	)
	_assert(follower.begin(), "layout follower starts")
	follower._process(0.5)
	var grid_position_before := follower.position / TEST_CELL_SIZE
	var new_origin := Vector2(40.0, 20.0)
	var new_cell_size := TEST_CELL_SIZE * 1.5
	follower.remap_layout(Vector2.ZERO, TEST_CELL_SIZE, new_origin, new_cell_size)
	var grid_position_after := (follower.position - new_origin) / new_cell_size
	_assert(
		grid_position_after.is_equal_approx(grid_position_before),
		"viewport resizing preserves fractional route position"
	)
	follower.queue_free()


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * TEST_CELL_SIZE


func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floor(world_position / TEST_CELL_SIZE))


func _appears_in_order(route: Array[Vector2i], targets: Array[Vector2i]) -> bool:
	var route_index := 0
	for target in targets:
		while route_index < route.size() and route[route_index] != target:
			route_index += 1
		if route_index >= route.size():
			return false
		route_index += 1
	return true


func _has_unique_edges(router: RefCounted, route: Array[Vector2i]) -> bool:
	var used_edges: Dictionary = {}
	for index in range(1, route.size()):
		var edge = router.get_edge_key(route[index - 1], route[index])
		if used_edges.has(edge):
			return false
		used_edges[edge] = true
	return true


func _shares_suffix(route: Array[Vector2i], main_route: Array[Vector2i]) -> bool:
	for route_index in route.size():
		for main_index in main_route.size():
			if route[route_index] != main_route[main_index]:
				continue
			var route_suffix: Array[Vector2i] = []
			var main_suffix: Array[Vector2i] = []
			route_suffix.assign(route.slice(route_index))
			main_suffix.assign(main_route.slice(main_index))
			if route_suffix == main_suffix:
				return true
	return false


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Prototype routing smoke failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
