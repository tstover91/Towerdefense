class_name TerrainSeedSelector
extends RefCounted

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")
const FlowField = preload("res://procedural_map/terrain_flow_field.gd")

const DEFAULT_CANDIDATE_COUNT := 8
const MINIMUM_NEAR_ROUTE_BUILDABLE_RATIO := 0.38
const MINIMUM_EARLY_LANE_VARIETY := 2.0

var candidate_results: Array[Dictionary] = []


func select_best_seed(
	base_seed: int,
	profile: Resource,
	spawn_rows: Array[int],
	navigation_bounds: Rect2i,
	blocked_cells: Array[Vector2i],
	exit_rows: Array[int],
	candidate_count := DEFAULT_CANDIDATE_COUNT
) -> Dictionary:
	candidate_results.clear()
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = base_seed
	for candidate_index in maxi(candidate_count, 1):
		var candidate_seed := (
			base_seed if candidate_index == 0 else seed_rng.randi()
		)
		var generator := Generator.new(profile)
		generator.generate(candidate_seed)
		var result := _score_candidate(
			candidate_seed,
			generator,
			spawn_rows,
			navigation_bounds,
			blocked_cells,
			exit_rows
		)
		candidate_results.append(result)

	var best_valid: Dictionary = {}
	var best_fallback: Dictionary = {}
	for result in candidate_results:
		if best_fallback.is_empty() or float(result["score"]) > float(best_fallback["score"]):
			best_fallback = result
		if (
			bool(result["valid"])
			and (best_valid.is_empty() or float(result["score"]) > float(best_valid["score"]))
		):
			best_valid = result
	return best_valid if not best_valid.is_empty() else best_fallback


func _score_candidate(
	seed_value: int,
	generator: ProceduralTerrainGenerator,
	spawn_rows: Array[int],
	navigation_bounds: Rect2i,
	blocked_cells: Array[Vector2i],
	exit_rows: Array[int]
) -> Dictionary:
	var flow := FlowField.new()
	flow.rebuild(
		generator.cells,
		generator.grid_size,
		[],
		navigation_bounds,
		blocked_cells,
		exit_rows
	)
	var routes: Array[Array] = []
	var total_length := 0.0
	var total_turns := 0
	var all_routes_valid := true
	for spawn_row in spawn_rows:
		var route := flow.trace_route(Vector2i(0, spawn_row))
		if route.is_empty():
			all_routes_valid = false
			continue
		routes.append(route)
		total_length += float(route.size())
		total_turns += _count_turns(route)

	var route_count := routes.size()
	var average_length := (
		total_length / float(route_count) if route_count > 0 else 0.0
	)
	var average_turns := (
		float(total_turns) / float(route_count) if route_count > 0 else 0.0
	)
	var early_lane_variety := _get_early_lane_variety(
		routes,
		generator.grid_size.x
	)
	var near_route_buildable_ratio := _get_near_route_buildable_ratio(
		generator,
		routes,
		navigation_bounds,
		blocked_cells
	)
	var field_ratio := generator.get_field_ratio()
	var terrain_balance := 1.0 - absf(
		field_ratio - maxf(float(generator.profile.minimum_field_ratio), 0.62)
	)
	var ideal_length := float(generator.grid_size.x) * 1.22
	var length_score := 1.0 - minf(
		absf(average_length - ideal_length) / ideal_length,
		1.0
	)
	var turn_score := 1.0 - minf(absf(average_turns - 4.0) / 7.0, 1.0)
	var variety_score := clampf(
		(early_lane_variety - 1.0) / maxf(float(spawn_rows.size() - 1), 1.0),
		0.0,
		1.0
	)
	var obstruction_penalty := _get_central_obstruction_ratio(generator)
	var score := (
		length_score * 24.0
		+ turn_score * 16.0
		+ variety_score * 22.0
		+ near_route_buildable_ratio * 26.0
		+ terrain_balance * 12.0
		- obstruction_penalty * 18.0
	)
	var valid := (
		all_routes_valid
		and route_count == spawn_rows.size()
		and field_ratio >= float(generator.profile.minimum_field_ratio)
		and near_route_buildable_ratio >= MINIMUM_NEAR_ROUTE_BUILDABLE_RATIO
		and early_lane_variety >= MINIMUM_EARLY_LANE_VARIETY
		and average_length >= float(generator.grid_size.x)
	)
	return {
		"seed": seed_value,
		"score": score,
		"valid": valid,
		"average_route_length": average_length,
		"average_turns": average_turns,
		"early_lane_variety": early_lane_variety,
		"near_route_buildable_ratio": near_route_buildable_ratio,
		"field_ratio": field_ratio,
		"central_obstruction_ratio": obstruction_penalty,
	}


func _count_turns(route: Array) -> int:
	var turns := 0
	var previous_direction := Vector2i.ZERO
	for index in range(1, route.size()):
		var direction: Vector2i = route[index] - route[index - 1]
		if previous_direction != Vector2i.ZERO and direction != previous_direction:
			turns += 1
		previous_direction = direction
	return turns


func _get_early_lane_variety(routes: Array[Array], width: int) -> float:
	if routes.is_empty():
		return 0.0
	var sample_end := maxi(1, floori(float(width) * 0.55))
	var total_unique_rows := 0.0
	var sampled_columns := 0
	for x in range(0, sample_end, 2):
		var rows: Dictionary = {}
		for route in routes:
			for cell in route:
				if cell.x == x:
					rows[cell.y] = true
					break
		if not rows.is_empty():
			total_unique_rows += float(rows.size())
			sampled_columns += 1
	return total_unique_rows / float(maxi(sampled_columns, 1))


func _get_near_route_buildable_ratio(
	generator: ProceduralTerrainGenerator,
	routes: Array[Array],
	navigation_bounds: Rect2i,
	blocked_cells: Array[Vector2i]
) -> float:
	var blocked_lookup: Dictionary = {}
	for cell in blocked_cells:
		blocked_lookup[cell] = true
	var nearby: Dictionary = {}
	for route in routes:
		for route_cell in route:
			for y_offset in range(-3, 4):
				for x_offset in range(-3, 4):
					if absi(x_offset) + absi(y_offset) > 3:
						continue
					var cell: Vector2i = route_cell + Vector2i(x_offset, y_offset)
					if navigation_bounds.has_point(cell) and not blocked_lookup.has(cell):
						nearby[cell] = true
	if nearby.is_empty():
		return 0.0
	var buildable_count := 0
	for cell in nearby:
		if bool(Terrain.get_data(generator.get_terrain(cell))["buildable"]):
			buildable_count += 1
	return float(buildable_count) / float(nearby.size())


func _get_central_obstruction_ratio(generator: ProceduralTerrainGenerator) -> float:
	var owner_counts: Dictionary = {}
	var central_cell_count := 0
	var start_x := floori(float(generator.grid_size.x) * 0.25)
	var end_x := ceili(float(generator.grid_size.x) * 0.75)
	for y in range(generator.profile.safe_top_rows, generator.grid_size.y - generator.profile.safe_bottom_rows):
		for x in range(start_x, end_x):
			central_cell_count += 1
			var owner := generator.blob_owners[y * generator.grid_size.x + x]
			if owner >= 0:
				owner_counts[owner] = int(owner_counts.get(owner, 0)) + 1
	var largest := 0
	for count in owner_counts.values():
		largest = maxi(largest, int(count))
	return float(largest) / float(maxi(central_cell_count, 1))
