class_name ProceduralBattlefield
extends "res://tower_defense_map.gd"

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")
const FlowField = preload("res://procedural_map/terrain_flow_field.gd")
const SeedSelector = preload("res://procedural_map/terrain_seed_selector.gd")
const GenerationProfile = preload(
	"res://procedural_map/terrain_generation_profile.gd"
)
const DEFAULT_GENERATION_PROFILE = preload(
	"res://procedural_map/farm_generation_profile.tres"
)

const DEFAULT_SEED := 481516
const CORNER_RADIUS := Terrain.TILE_SIZE * 0.24
const CURVE_HANDLE_RATIO := 0.55228475
const ROUTE_VARIANTS := {
	&"main": 0,
	&"upper": -1,
	&"lower": 1,
}
const SPAWN_LANE_UNLOCKS: Array[int] = [1, 3, 6, 10, 16]
const ROUTE_PREVIEW_COLOR := Color(0.93, 0.89, 0.69, 0.20)
const ROUTE_PREVIEW_OVERLAP_COLOR := Color(1.0, 0.83, 0.35, 0.64)
const ACTIVE_ENTRY_COLOR := Color(0.46, 0.96, 0.70, 0.95)
const UPCOMING_ENTRY_COLOR := Color(1.0, 0.72, 0.25, 0.95)

@export var generation_seed := 0
@export var generation_profile: Resource = DEFAULT_GENERATION_PROFILE

var generator := Generator.new()
var flow_field := FlowField.new()
var flow_fields: Dictionary = {}
var path_route_configs: Dictionary = {}
var terrain_textures: Dictionary = {}
var tower_origins_by_instance: Dictionary = {}
var road_cells: Dictionary = {}
var spawn_rows: Array[int] = []
var active_generation_seed := 0
var generation_candidate_results: Array[Dictionary] = []
var preview_round := 1
var route_preview_visible := true


func _ready() -> void:
	generator.configure(generation_profile)
	native_build_bounds = Rect2(
		Vector2.ZERO,
		Vector2(generator.grid_size * Terrain.TILE_SIZE)
	)
	spawn_rows = _create_spawn_rows()
	_load_terrain_textures()
	_create_spawn_paths()
	super._ready()
	active_generation_seed = _select_generation_seed()
	generator.generate(active_generation_seed)
	_build_primary_road_network()
	_rebuild_weighted_routes()
	queue_redraw()


func _draw() -> void:
	var tile_size := Vector2.ONE * Terrain.TILE_SIZE
	for y in generator.grid_size.y:
		for x in generator.grid_size.x:
			var cell := Vector2i(x, y)
			var terrain_type := _get_displayed_terrain(cell)
			var texture := terrain_textures[terrain_type] as Texture2D
			draw_texture_rect(
				texture,
				Rect2(Vector2(cell * Terrain.TILE_SIZE), tile_size),
				false
			)
	if route_preview_visible:
		_draw_route_forecast()
		_draw_entry_markers()


func set_round_preview(round_number: int, visible: bool) -> void:
	preview_round = maxi(round_number, 1)
	route_preview_visible = visible
	queue_redraw()


func get_spawn_paths_for_round(round_number: int) -> Array[Path2D]:
	var active_rows := get_active_spawn_rows(round_number)
	var result: Array[Path2D] = []
	for path in get_enemy_paths():
		var config: Dictionary = path_route_configs.get(path.get_instance_id(), {})
		if active_rows.has(int(config.get("row", -1))):
			result.append(path)
	return result


func get_active_spawn_rows(round_number: int) -> Array[int]:
	var count := 1
	for unlock_round in SPAWN_LANE_UNLOCKS:
		if round_number >= unlock_round:
			count += 1
	count = clampi(count - 1, 1, spawn_rows.size())
	var activation_order := _get_spawn_row_activation_order()
	var active: Array[int] = []
	for index in count:
		active.append(int(activation_order[index]))
	active.sort()
	return active


func get_next_spawn_row_unlock(round_number: int) -> Dictionary:
	var active_count := get_active_spawn_rows(round_number).size()
	var activation_order := _get_spawn_row_activation_order()
	if active_count >= activation_order.size():
		return {}
	return {
		"row": int(activation_order[active_count]),
		"round": SPAWN_LANE_UNLOCKS[active_count],
	}


func _get_spawn_row_activation_order() -> Array[int]:
	if spawn_rows.is_empty():
		return []
	var order: Array[int] = []
	var center := floori(float(spawn_rows.size()) / 2.0)
	order.append(spawn_rows[center])
	for distance in range(1, center + 1):
		if center - distance >= 0:
			order.append(spawn_rows[center - distance])
		if center + distance < spawn_rows.size():
			order.append(spawn_rows[center + distance])
	return order


func _draw_route_forecast() -> void:
	if not flow_fields.has(&"main"):
		return
	var segment_counts: Dictionary = {}
	for spawn_row in get_active_spawn_rows(preview_round):
		for variant_id in ROUTE_VARIANTS:
			var variant_flow := flow_fields[variant_id] as TerrainFlowField
			var route := variant_flow.trace_route(Vector2i(0, spawn_row))
			for index in range(1, route.size()):
				var first: Vector2i = route[index - 1]
				var second: Vector2i = route[index]
				var ordered := _get_ordered_segment(first, second)
				var key := "%d,%d:%d,%d" % [
					ordered[0].x, ordered[0].y, ordered[1].x, ordered[1].y
				]
				if not segment_counts.has(key):
					segment_counts[key] = {"cells": ordered, "count": 0}
				segment_counts[key]["count"] = (
					int(segment_counts[key]["count"]) + 1
				)
	for key in segment_counts:
		var segment: Dictionary = segment_counts[key]
		var cells: Array = segment["cells"]
		var count := int(segment["count"])
		var color := (
			ROUTE_PREVIEW_OVERLAP_COLOR
			if count > 1
			else ROUTE_PREVIEW_COLOR
		)
		color.a = minf(color.a + 0.10 * float(count - 1), 0.82)
		draw_line(
			_cell_center(cells[0]),
			_cell_center(cells[1]),
			color,
			8.0 + 2.0 * float(count - 1),
			true
		)


func _draw_entry_markers() -> void:
	for row in get_active_spawn_rows(preview_round):
		_draw_entry_marker(row, ACTIVE_ENTRY_COLOR, "ENTRY")
	var upcoming := get_next_spawn_row_unlock(preview_round)
	if not upcoming.is_empty():
		_draw_entry_marker(
			int(upcoming["row"]),
			UPCOMING_ENTRY_COLOR,
			"ROUND %d" % int(upcoming["round"])
		)


func _draw_entry_marker(row: int, color: Color, label: String) -> void:
	var center := Vector2(Terrain.TILE_SIZE * 0.5, _cell_center_y(row))
	var radius := Terrain.TILE_SIZE * 0.30
	draw_circle(center, radius, Color(0.08, 0.04, 0.09, 0.88))
	draw_arc(center, radius, 0.0, TAU, 24, color, 3.0, true)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(radius + 5.0, 4.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		11,
		color
	)


func _get_ordered_segment(first: Vector2i, second: Vector2i) -> Array:
	if first.x < second.x or (first.x == second.x and first.y <= second.y):
		return [first, second]
	return [second, first]


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * Terrain.TILE_SIZE) + Vector2.ONE * Terrain.TILE_SIZE * 0.5


func configure_runtime_build_bounds(available_bounds: Rect2) -> void:
	runtime_build_bounds = native_build_bounds.intersection(available_bounds)


func is_point_blocked_by_path(_world_position: Vector2) -> bool:
	var cell := Vector2i(floor(_world_position / float(Terrain.TILE_SIZE)))
	return road_cells.has(cell)


func is_point_blocked_by_build_mask(world_position: Vector2) -> bool:
	var cell := Vector2i(floor(world_position / float(Terrain.TILE_SIZE)))
	if (
		not generator.contains(cell)
		or not _get_navigation_bounds().has_point(cell)
		or _is_in_protected_right_corner(cell)
	):
		return true
	var terrain_data := Terrain.get_data(_get_displayed_terrain(cell))
	return not bool(terrain_data["buildable"])


func register_tower_route_weight(tower: Node2D) -> void:
	if not is_instance_valid(tower):
		return
	var origin := _get_tower_navigation_origin(tower.position)
	tower_origins_by_instance[tower.get_instance_id()] = origin


func unregister_tower_route_weight(tower: Node2D) -> void:
	if tower == null:
		return
	tower_origins_by_instance.erase(tower.get_instance_id())


func get_terrain_type_at_world_position(world_position: Vector2) -> int:
	var cell := Vector2i(floor(world_position / float(Terrain.TILE_SIZE)))
	return _get_displayed_terrain(cell)


func get_terrain_speed_multiplier(world_position: Vector2) -> float:
	var terrain_type := get_terrain_type_at_world_position(world_position)
	return float(Terrain.get_data(terrain_type)["speed_multiplier"])


func _create_spawn_paths() -> void:
	flow_fields.clear()
	path_route_configs.clear()
	for variant_id in ROUTE_VARIANTS:
		var variant_flow := FlowField.new()
		flow_fields[variant_id] = variant_flow
		if variant_id == &"main":
			flow_field = variant_flow
	var combination_count := spawn_rows.size() * ROUTE_VARIANTS.size()
	var variant_ids: Array = ROUTE_VARIANTS.keys()
	for combination_index in combination_count:
		var row: int = spawn_rows[combination_index % spawn_rows.size()]
		var variant_id: StringName = variant_ids[combination_index % variant_ids.size()]
		var path := Path2D.new()
		path.name = "row_%02d_%s" % [row, variant_id]
		path.curve = Curve2D.new()
		paths_root.add_child(path)
		path_route_configs[path.get_instance_id()] = {
			"row": row,
			"variant": variant_id,
		}


func _rebuild_weighted_routes() -> void:
	var blocked_cells := _get_non_road_navigation_cells()
	for variant_id in ROUTE_VARIANTS:
		var variant_flow := flow_fields[variant_id] as TerrainFlowField
		variant_flow.rebuild(
			_get_terrain_cells_with_roads(),
			generator.grid_size,
			[],
			_get_navigation_bounds(),
			blocked_cells,
			_get_exit_rows(),
			int(ROUTE_VARIANTS[variant_id])
		)

	var paths := get_enemy_paths()
	for path in paths:
		var config := path_route_configs[path.get_instance_id()] as Dictionary
		_update_path_curve(
			path,
			int(config["row"]),
			flow_fields[config["variant"]] as TerrainFlowField
		)
	queue_redraw()


func _build_primary_road_network() -> void:
	road_cells.clear()
	var terrain_flow := FlowField.new()
	terrain_flow.rebuild(
		generator.cells,
		generator.grid_size,
		[],
		_get_navigation_bounds(),
		_get_blocked_navigation_cells(),
		_get_exit_rows()
	)
	for spawn_row in spawn_rows:
		var route := terrain_flow.trace_route(Vector2i(0, spawn_row))
		assert(not route.is_empty(), "Procedural battlefield requires a road to every entrance")
		for cell in route:
			road_cells[cell] = true


func _get_displayed_terrain(cell: Vector2i) -> int:
	if road_cells.has(cell):
		return Terrain.TerrainType.ROAD
	return generator.get_terrain(cell)


func _get_terrain_cells_with_roads() -> Array[int]:
	var result := generator.cells.duplicate()
	for cell_variant in road_cells:
		var cell := cell_variant as Vector2i
		result[cell.y * generator.grid_size.x + cell.x] = Terrain.TerrainType.ROAD
	return result


func _get_non_road_navigation_cells() -> Array[Vector2i]:
	var blocked := _get_blocked_navigation_cells()
	var navigation_bounds := _get_navigation_bounds()
	for y in range(navigation_bounds.position.y, navigation_bounds.end.y):
		for x in range(navigation_bounds.position.x, navigation_bounds.end.x):
			var cell := Vector2i(x, y)
			if not road_cells.has(cell):
				blocked.append(cell)
	return blocked


func _update_path_curve(
	path: Path2D,
	spawn_row: int,
	route_flow: TerrainFlowField
) -> void:
	var follower_states: Dictionary = {}
	for child in path.get_children():
		if child is PathFollow2D:
			var path_follow := child as PathFollow2D
			var route_anchor := path_follow.global_position
			var tracked_children: Dictionary = {}
			for follower_child in path_follow.get_children():
				if follower_child is Node2D:
					var tracked_child := follower_child as Node2D
					tracked_children[tracked_child] = tracked_child.global_position
					if tracked_children.size() == 1:
						route_anchor = tracked_child.global_position
			follower_states[path_follow] = {
				"route_anchor": route_anchor,
				"children": tracked_children,
			}

	var route := route_flow.trace_route(Vector2i(0, spawn_row))
	assert(not route.is_empty(), "Procedural battlefield requires a route to the exit")
	var route_points: Array[Vector2] = [
		Vector2(-Terrain.TILE_SIZE, _cell_center_y(spawn_row))
	]
	for cell in route:
		route_points.append(
			Vector2(cell * Terrain.TILE_SIZE)
			+ Vector2.ONE * Terrain.TILE_SIZE * 0.5
		)
	route_points.append(Vector2(
		generator.grid_size.x * Terrain.TILE_SIZE + Terrain.TILE_SIZE,
		_cell_center_y(route[-1].y)
	))
	var new_curve := _create_smoothed_curve(route_points)
	path.curve = new_curve

	for follower in follower_states:
		var path_follow := follower as PathFollow2D
		var state := follower_states[follower] as Dictionary
		var old_global_position := state["route_anchor"] as Vector2
		path_follow.progress = new_curve.get_closest_offset(
			path.to_local(old_global_position)
		)
		var tracked_children := state["children"] as Dictionary
		for tracked_child in tracked_children:
			if not is_instance_valid(tracked_child):
				continue
			var previous_child_position := tracked_children[tracked_child] as Vector2
			if tracked_child.has_method("blend_from_reroute"):
				tracked_child.call("blend_from_reroute", previous_child_position)


func _create_smoothed_curve(points: Array[Vector2]) -> Curve2D:
	var curve := Curve2D.new()
	if points.size() <= 2:
		for point in points:
			curve.add_point(point)
		return curve

	curve.add_point(points[0])
	for index in range(1, points.size() - 1):
		var previous := points[index - 1]
		var current := points[index]
		var following := points[index + 1]
		var incoming := (current - previous).normalized()
		var outgoing := (following - current).normalized()
		if incoming.is_equal_approx(outgoing):
			continue
		var radius: float = minf(
			CORNER_RADIUS,
			minf(current.distance_to(previous), current.distance_to(following)) * 0.35
		)
		var before := current - incoming * radius
		var after := current + outgoing * radius
		curve.add_point(
			before,
			Vector2.ZERO,
			incoming * radius * CURVE_HANDLE_RATIO
		)
		curve.add_point(
			after,
			-outgoing * radius * CURVE_HANDLE_RATIO,
			Vector2.ZERO
		)
	curve.add_point(points[-1])
	return curve


func _load_terrain_textures() -> void:
	for terrain_type in Terrain.TERRAIN_DATA:
		var image := Image.load_from_file(
			ProjectSettings.globalize_path(Terrain.get_texture_path(terrain_type))
		)
		assert(not image.is_empty(), "Unable to load procedural terrain texture")
		terrain_textures[terrain_type] = ImageTexture.create_from_image(image)


func _get_tower_navigation_origin(tower_position: Vector2) -> Vector2i:
	var footprint_size := Vector2(
		FlowField.TOWER_FOOTPRINT_CELLS * Terrain.TILE_SIZE
	)
	return Vector2i(floor(
		(tower_position - footprint_size * 0.5)
		/ float(Terrain.TILE_SIZE)
	))


func _cell_center_y(row: int) -> float:
	return float(row * Terrain.TILE_SIZE) + Terrain.TILE_SIZE * 0.5


func _select_generation_seed() -> int:
	if generation_seed != 0:
		return generation_seed
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var selector := SeedSelector.new()
	var selection := selector.select_best_seed(
		rng.randi(),
		generation_profile,
		spawn_rows,
		_get_navigation_bounds(),
		_get_blocked_navigation_cells(),
		_get_exit_rows(),
		generation_profile.candidate_seed_count
	)
	generation_candidate_results = selector.candidate_results.duplicate(true)
	return int(selection["seed"])


func _create_spawn_rows() -> Array[int]:
	var rows: Array[int] = []
	var first_row: int = generation_profile.safe_top_rows
	var last_row: int = (
		generator.grid_size.y - generation_profile.safe_bottom_rows - 1
	)
	for lane_index in 5:
		var lane_ratio := float(lane_index) / 4.0
		rows.append(roundi(lerpf(float(first_row), float(last_row), lane_ratio)))
	return rows


func _get_navigation_bounds() -> Rect2i:
	return Rect2i(
		Vector2i(0, generation_profile.safe_top_rows),
		Vector2i(
			generator.grid_size.x,
			generator.grid_size.y
				- generation_profile.safe_top_rows
				- generation_profile.safe_bottom_rows
		)
	)


func _get_blocked_navigation_cells() -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for y in range(
		generation_profile.safe_top_rows,
		generation_profile.protected_right_top_rows
	):
		for x_offset in generation_profile.protected_right_columns:
			blocked.append(Vector2i(generator.grid_size.x - 1 - x_offset, y))
	for y in range(
		generator.grid_size.y - generation_profile.protected_right_bottom_rows,
		generator.grid_size.y - generation_profile.safe_bottom_rows
	):
		for x_offset in generation_profile.protected_right_columns:
			blocked.append(Vector2i(generator.grid_size.x - 1 - x_offset, y))
	return blocked


func _get_exit_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in range(
		generation_profile.exit_top_margin_rows,
		generator.grid_size.y - generation_profile.exit_bottom_margin_rows
	):
		rows.append(y)
	return rows


func _is_in_protected_right_corner(cell: Vector2i) -> bool:
	if cell.x < generator.grid_size.x - generation_profile.protected_right_columns:
		return false
	return (
		cell.y < generation_profile.protected_right_top_rows
		or cell.y
			>= generator.grid_size.y
				- generation_profile.protected_right_bottom_rows
	)
