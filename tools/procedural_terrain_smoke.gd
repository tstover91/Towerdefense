extends Node

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")
const FlowField = preload("res://procedural_map/terrain_flow_field.gd")
const SeedSelector = preload("res://procedural_map/terrain_seed_selector.gd")
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
	assert(not bool(Terrain.get_data(Terrain.TerrainType.ROAD)["buildable"]))
	assert(first.get_field_ratio() >= first.profile.minimum_field_ratio)
	assert(_largest_region_size(first, Terrain.TerrainType.FOREST) >= 12)
	assert(_largest_region_size(first, Terrain.TerrainType.MUD) >= 8)
	_assert_blob_borders(first)
	for sample_seed in range(20, 30):
		first.generate(sample_seed)
		assert(first.get_field_ratio() >= first.profile.minimum_field_ratio)
	first.generate(12345)
	for y in range(first.profile.safe_top_rows, first.grid_size.y - first.profile.safe_bottom_rows):
		for x in Generator.EDGE_CLEARANCE_COLUMNS:
			assert(first.get_terrain(Vector2i(x, y)) == Terrain.TerrainType.FIELD)
	for y in first.profile.safe_top_rows:
		for x in first.grid_size.x:
			assert(first.get_terrain(Vector2i(x, y)) == Terrain.TerrainType.FOREST)
	for y_offset in first.profile.safe_bottom_rows:
		for x in first.grid_size.x:
			assert(
				first.get_terrain(Vector2i(x, first.grid_size.y - 1 - y_offset))
				== Terrain.TerrainType.FOREST
			)
	_assert_generated_routes_bend(first)
	_test_weighted_routes()
	_test_route_variants_split()
	_test_turn_costs_and_curve_smoothing()
	_test_seed_selector()
	_test_playable_map()
	_test_road_generation_safeguards()
	print("Procedural terrain smoke test passed: terrain-generated roads, locked routing, smooth curves, and playable map integration.")
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
	flow.rebuild(all_field, Generator.GRID_SIZE, [], Rect2i(), [], [5])
	var short_crossing := flow.trace_route(Vector2i(0, 5))
	assert(short_crossing.has(single_forest_cell))
	all_field[single_forest_cell.y * Generator.GRID_SIZE.x + single_forest_cell.x] = (
		Terrain.TerrainType.FIELD
	)

	for y in range(4, 7):
		for x in range(8, 12):
			all_field[y * Generator.GRID_SIZE.x + x] = Terrain.TerrainType.FOREST
	flow.rebuild(all_field, Generator.GRID_SIZE, [], Rect2i(), [], [5])
	var forest_detour := flow.trace_route(Vector2i(0, 5))
	assert(not forest_detour.is_empty())
	for cell in forest_detour:
		assert(
			all_field[cell.y * Generator.GRID_SIZE.x + cell.x]
			!= Terrain.TerrainType.FOREST
		)
	for y in range(4, 7):
		for x in range(8, 12):
			all_field[y * Generator.GRID_SIZE.x + x] = Terrain.TerrainType.FIELD

	var tower_wall: Array[Vector2i] = []
	for y in Generator.GRID_SIZE.y:
		tower_wall.append(Vector2i(8, y))
	flow.rebuild(all_field, Generator.GRID_SIZE, tower_wall)
	var forced_route := flow.trace_route(Vector2i(0, 5))
	assert(not forced_route.is_empty())
	assert(forced_route.any(func(cell: Vector2i) -> bool: return flow.is_tower_cell(cell)))


func _assert_generated_routes_bend(generator: ProceduralTerrainGenerator) -> void:
	var flow := FlowField.new()
	var navigation_bounds := Rect2i(
		Vector2i(0, generator.profile.safe_top_rows),
		Vector2i(
			generator.grid_size.x,
			generator.grid_size.y
				- generator.profile.safe_top_rows
				- generator.profile.safe_bottom_rows
		)
	)
	var blocked: Array[Vector2i] = []
	for y in range(generator.profile.safe_top_rows, generator.profile.protected_right_top_rows):
		for x_offset in generator.profile.protected_right_columns:
			blocked.append(Vector2i(generator.grid_size.x - 1 - x_offset, y))
	for y in range(generator.grid_size.y - generator.profile.protected_right_bottom_rows, generator.grid_size.y - generator.profile.safe_bottom_rows):
		for x_offset in generator.profile.protected_right_columns:
			blocked.append(Vector2i(generator.grid_size.x - 1 - x_offset, y))
	var exits: Array[int] = []
	for y in range(generator.profile.exit_top_margin_rows, generator.grid_size.y - generator.profile.exit_bottom_margin_rows):
		exits.append(y)
	flow.rebuild(generator.cells, generator.grid_size, [], navigation_bounds, blocked, exits)
	var bent_route_count := 0
	assert(flow.trace_route(Vector2i(0, 0)).is_empty())
	for spawn_row in [3, 7, 10, 14, 17]:
		var route := flow.trace_route(Vector2i(0, spawn_row))
		assert(not route.is_empty())
		_assert_route_is_cardinal(route)
		if route.any(
			func(cell: Vector2i) -> bool: return cell.y != spawn_row
		):
			bent_route_count += 1
	assert(bent_route_count >= 3)


func _test_route_variants_split() -> void:
	var cells: Array[int] = []
	cells.resize(Generator.GRID_SIZE.x * Generator.GRID_SIZE.y)
	cells.fill(Terrain.TerrainType.FIELD)
	for y in range(8, 13):
		for x in range(12, 19):
			cells[y * Generator.GRID_SIZE.x + x] = Terrain.TerrainType.MUD
	var upper := FlowField.new()
	var lower := FlowField.new()
	upper.rebuild(cells, Generator.GRID_SIZE, [], Rect2i(), [], [10], -1)
	lower.rebuild(cells, Generator.GRID_SIZE, [], Rect2i(), [], [10], 1)
	var upper_route := upper.trace_route(Vector2i(0, 10))
	var lower_route := lower.trace_route(Vector2i(0, 10))
	assert(not upper_route.is_empty() and not lower_route.is_empty())
	assert(upper_route != lower_route)
	assert(upper_route.any(func(cell: Vector2i) -> bool: return cell.y < 8))
	assert(lower_route.any(func(cell: Vector2i) -> bool: return cell.y > 12))


func _test_turn_costs_and_curve_smoothing() -> void:
	var all_field: Array[int] = []
	all_field.resize(Generator.GRID_SIZE.x * Generator.GRID_SIZE.y)
	all_field.fill(Terrain.TerrainType.FIELD)
	var flow := FlowField.new()
	flow.rebuild(all_field, Generator.GRID_SIZE, [])
	var route := flow.trace_route(Vector2i(0, 4))
	assert(route.all(func(cell: Vector2i) -> bool: return cell.y == 4))

	var map := PROCEDURAL_MAP.instantiate() as ProceduralBattlefield
	map.generation_seed = 12345
	add_child(map)
	assert(map.active_generation_seed == 12345)
	var corner_points: Array[Vector2] = [
		Vector2(0, 32), Vector2(32, 32), Vector2(32, 96), Vector2(96, 96)
	]
	var curve := map._create_smoothed_curve(corner_points)
	assert(curve.point_count > 4)
	assert(curve.get_baked_length() > 0.0)
	map.queue_free()


func _test_playable_map() -> void:
	var map := PROCEDURAL_MAP.instantiate() as ProceduralBattlefield
	map.generation_seed = 12345
	add_child(map)
	assert(map.active_generation_seed == 12345)
	assert(map.map_id == &"procedural_test")
	assert(map.get_build_bounds() == Rect2(0.0, 0.0, 1152.0, 640.0))
	assert(
		map.get_enemy_paths().size()
		== map.spawn_rows.size() * map.ROUTE_VARIANTS.size()
	)
	assert(map.spawn_rows == [8, 12])
	assert(map.get_active_spawn_rows(1) == [12])
	assert(map.get_active_spawn_rows(4) == [12])
	assert(map.get_active_spawn_rows(5) == [8, 12])
	assert(map.get_active_spawn_rows(16) == [8, 12])
	assert(map.get_spawn_paths_for_round(1).size() == map.ROUTE_VARIANTS.size())
	assert(map.get_spawn_paths_for_round(5).size() == 2 * map.ROUTE_VARIANTS.size())
	assert(map.get_next_spawn_row_unlock(1) == {"row": 8, "round": 5})
	assert(map.get_next_spawn_row_unlock(5).is_empty())
	map.set_round_preview(3, true)
	assert(map.preview_round == 3 and not map.route_preview_visible)
	for spawn_row in map.get_active_spawn_rows(5):
		var variant_routes: Dictionary = {}
		for variant_id in map.ROUTE_VARIANTS:
			var route: Array[Vector2i] = map.flow_fields[variant_id].trace_route(
				Vector2i(0, spawn_row)
			)
			variant_routes[str(route)] = true
		assert(variant_routes.size() >= 1)
	assert(map.is_point_blocked_by_build_mask(Vector2(32.0, 32.0)))
	assert(map.is_point_blocked_by_build_mask(Vector2(1136.0, 112.0)))
	assert(not map.road_cells.is_empty())
	assert(map.primary_road_route.any(
		func(cell: Vector2i) -> bool:
			return cell.y != map.primary_road_route[0].y
	))
	var has_westward_section := false
	for route_index in range(1, map.primary_road_route.size()):
		if map.primary_road_route[route_index].x < map.primary_road_route[route_index - 1].x:
			has_westward_section = true
			break
	assert(has_westward_section)
	for y in range(map.generator.grid_size.y - 2):
		for x in range(map.generator.grid_size.x - 2):
			var cell := Vector2i(x, y)
			if _is_full_road_square(map.road_cells, cell):
				assert(not _is_full_road_square(map.road_cells, cell + Vector2i.RIGHT))
				assert(not _is_full_road_square(map.road_cells, cell + Vector2i.DOWN))
	var left_edge_road_rows: Array[int] = []
	for row in range(map.generator.grid_size.y):
		if map.road_cells.has(Vector2i(0, row)):
			left_edge_road_rows.append(row)
	assert(left_edge_road_rows == map.spawn_rows)
	for spawn_row in map.spawn_rows:
		var road_route: Array[Vector2i] = map.road_routes_by_spawn[spawn_row]
		assert(not road_route.is_empty())
		for road_cell in road_route:
			assert(map.road_cells.has(road_cell))
	for path in map.get_enemy_paths():
		assert(path.curve != null and path.curve.point_count >= 2)

	var center_route: Array[Vector2i] = map.road_routes_by_spawn[12]
	var route_cell := center_route[center_route.size() / 2]
	var road_center := map._cell_center(route_cell)
	assert(map.is_point_blocked_by_path(road_center))
	assert(map.is_point_blocked_by_build_mask(road_center))
	var route_before_tower := center_route.duplicate()
	var tower := Node2D.new()
	tower.position = (
		Vector2(route_cell * Terrain.TILE_SIZE)
		+ Vector2.ONE * Terrain.TILE_SIZE
	)
	map.add_child(tower)
	map.register_tower_route_weight(tower)
	var tower_origin := map.tower_origins_by_instance[tower.get_instance_id()] as Vector2i
	assert(not map.flow_field.is_tower_cell(tower_origin))
	assert(map.road_routes_by_spawn[12] == route_before_tower)
	map.unregister_tower_route_weight(tower)
	assert(not map.flow_field.is_tower_cell(tower_origin))
	map.queue_free()


func _is_full_road_square(road_cells: Dictionary, origin: Vector2i) -> bool:
	for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		if not road_cells.has(origin + offset):
			return false
	return true


func _test_road_generation_safeguards() -> void:
	for test_seed in [101, 202, 303, 404]:
		var map := PROCEDURAL_MAP.instantiate() as ProceduralBattlefield
		map.generation_seed = test_seed
		add_child(map)
		assert(map.spawn_rows.size() == 2)
		assert(map._route_has_required_clearance(map.primary_road_route))
		var primary_lookup: Dictionary = {}
		for cell in map.primary_road_route:
			primary_lookup[cell] = true
		var secondary_route: Array[Vector2i] = map.road_routes_by_spawn[map.spawn_rows[0]]
		var first_shared_x := map.generator.grid_size.x
		var visited: Dictionary = {}
		for cell in secondary_route:
			assert(not visited.has(cell))
			visited[cell] = true
			if primary_lookup.has(cell):
				first_shared_x = cell.x
				break
		assert(first_shared_x >= ceili(
			float(map.generator.grid_size.x)
				* map.MINIMUM_ENTRANCE_SEPARATION_RATIO
		) - 1)
		map.queue_free()


func _test_seed_selector() -> void:
	var generator := Generator.new()
	var navigation_bounds := Rect2i(
		Vector2i(0, generator.profile.safe_top_rows),
		Vector2i(
			generator.grid_size.x,
			generator.grid_size.y
				- generator.profile.safe_top_rows
				- generator.profile.safe_bottom_rows
		)
	)
	var exits: Array[int] = []
	for y in range(
		generator.profile.exit_top_margin_rows,
		generator.grid_size.y - generator.profile.exit_bottom_margin_rows
	):
		exits.append(y)
	var selector := SeedSelector.new()
	var selection := selector.select_best_seed(
		98765,
		generator.profile,
		[3, 7, 10, 14, 17],
		navigation_bounds,
		[],
		exits,
		8
	)
	assert(selector.candidate_results.size() == 8)
	assert(not selection.is_empty())
	assert(selector.candidate_results.any(
		func(result: Dictionary) -> bool:
			return int(result["seed"]) == int(selection["seed"])
	))
	for result in selector.candidate_results:
		if bool(result["valid"]):
			assert(float(selection["score"]) >= float(result["score"]))


func _assert_route_is_cardinal(route: Array[Vector2i]) -> void:
	for index in range(1, route.size()):
		var step := route[index] - route[index - 1]
		assert(abs(step.x) + abs(step.y) == 1)


func _largest_region_size(
	generator: ProceduralTerrainGenerator,
	terrain_type: int
) -> int:
	var largest := 0
	var visited: Dictionary = {}
	for y in generator.grid_size.y:
		for x in generator.grid_size.x:
			var start := Vector2i(x, y)
			if visited.has(start) or generator.get_terrain(start) != terrain_type:
				continue
			var region_size := 0
			var open_cells: Array[Vector2i] = [start]
			visited[start] = true
			while not open_cells.is_empty():
				var current: Vector2i = open_cells.pop_back()
				region_size += 1
				for direction in FlowField.CARDINAL_DIRECTIONS:
					var neighbor := current + direction
					if (
						generator.contains(neighbor)
						and not visited.has(neighbor)
						and generator.get_terrain(neighbor) == terrain_type
					):
						visited[neighbor] = true
						open_cells.append(neighbor)
			largest = maxi(largest, region_size)
	return largest


func _assert_blob_borders(generator: ProceduralTerrainGenerator) -> void:
	for y in generator.grid_size.y:
		for x in generator.grid_size.x:
			var cell := Vector2i(x, y)
			var owner := generator.blob_owners[y * generator.grid_size.x + x]
			if owner < 0:
				continue
			for y_offset in range(-1, 2):
				for x_offset in range(-1, 2):
					var nearby := cell + Vector2i(x_offset, y_offset)
					if not generator.contains(nearby):
						continue
					var nearby_owner := generator.blob_owners[
						nearby.y * generator.grid_size.x + nearby.x
					]
					assert(nearby_owner < 0 or nearby_owner == owner)
