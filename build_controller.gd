class_name BuildController
extends RefCounted

const GameStats = preload("res://stat_database.gd")

const BUILD_CELL_SIZE := GameStats.BUILD_CELL_SIZE
const PLACEMENT_SNAP_SIZE := 16.0

var place_mode := false
var build_mode := false
var tower_to_place: Node2D
var manual_targeting_tower: Node2D
var pending_tower_type: StringName = &""
var pending_tower_cost := 0
var pending_tower_is_contraband := false

var occupied_build_cells: Dictionary = {}


func begin_pending_tower(
	tower_id: StringName,
	cost: int,
	is_contraband: bool
) -> void:
	pending_tower_type = tower_id
	pending_tower_cost = cost
	pending_tower_is_contraband = is_contraband


func begin_placement(tower: Node2D) -> void:
	tower_to_place = tower
	place_mode = true
	build_mode = true


func await_confirmation() -> void:
	place_mode = false


func clear_pending_placement() -> Node2D:
	var pending_tower := tower_to_place
	place_mode = false
	build_mode = false
	tower_to_place = null
	pending_tower_type = &""
	pending_tower_cost = 0
	pending_tower_is_contraband = false
	return pending_tower


func begin_manual_targeting(tower: Node2D) -> Node2D:
	var previous_tower := manual_targeting_tower
	manual_targeting_tower = tower
	return previous_tower


func finish_manual_targeting(tower: Node2D) -> void:
	if manual_targeting_tower == tower:
		manual_targeting_tower = null


func take_manual_targeting_tower() -> Node2D:
	var tower := manual_targeting_tower
	manual_targeting_tower = null
	return tower


func clear_invalid_manual_target() -> bool:
	if is_instance_valid(manual_targeting_tower):
		return false
	var had_target := manual_targeting_tower != null
	manual_targeting_tower = null
	return had_target


func world_to_build_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / PLACEMENT_SNAP_SIZE),
		floori(world_position.y / PLACEMENT_SNAP_SIZE)
	)


func get_tower_footprint(tower_id: StringName) -> Vector2i:
	return GameStats.get_tower(tower_id).get("footprint_cells", Vector2i.ONE)


func get_tower_build_position(world_position: Vector2, tower_id: StringName) -> Vector2:
	var footprint_size := Vector2(get_tower_footprint(tower_id)) * BUILD_CELL_SIZE
	var snap_step := Vector2.ONE * PLACEMENT_SNAP_SIZE
	var snapped_origin := (world_position - footprint_size * 0.5).snapped(snap_step)
	return snapped_origin + footprint_size * 0.5


func get_tower_build_cells(
	tower_position: Vector2,
	tower_id: StringName
) -> Array[Vector2i]:
	var footprint_size := Vector2(get_tower_footprint(tower_id)) * BUILD_CELL_SIZE
	var footprint_cells := Vector2i(
		roundi(footprint_size.x / PLACEMENT_SNAP_SIZE),
		roundi(footprint_size.y / PLACEMENT_SNAP_SIZE)
	)
	var origin_world := tower_position - footprint_size * 0.5
	var origin_cell := world_to_build_cell(origin_world + Vector2(0.01, 0.01))
	var cells: Array[Vector2i] = []
	for y_offset in footprint_cells.y:
		for x_offset in footprint_cells.x:
			cells.append(origin_cell + Vector2i(x_offset, y_offset))
	return cells


func get_build_cell_center(cell: Vector2i) -> Vector2:
	return (
		Vector2(cell) * PLACEMENT_SNAP_SIZE
		+ Vector2.ONE * PLACEMENT_SNAP_SIZE * 0.5
	)


func is_build_cell_in_bounds(cell: Vector2i, build_bounds: Rect2) -> bool:
	var cell_top_left := Vector2(cell) * PLACEMENT_SNAP_SIZE
	var cell_bottom_right := cell_top_left + Vector2.ONE * PLACEMENT_SNAP_SIZE
	return (
		cell_top_left.x >= build_bounds.position.x
		and cell_top_left.y >= build_bounds.position.y
		and cell_bottom_right.x <= build_bounds.end.x
		and cell_bottom_right.y <= build_bounds.end.y
	)


func can_place_tower_on_grid(
	tower_position: Vector2,
	tower_id: StringName,
	build_bounds: Rect2,
	is_cell_blocked_by_path: Callable
) -> bool:
	for cell in get_tower_build_cells(tower_position, tower_id):
		if not is_build_cell_in_bounds(cell, build_bounds):
			return false
		if is_cell_blocked_by_path.call(cell):
			return false
		if is_build_cell_occupied(cell):
			return false
	return true


func is_build_cell_occupied(cell: Vector2i) -> bool:
	if not occupied_build_cells.has(cell):
		return false
	var occupying_tower = occupied_build_cells[cell]
	if is_instance_valid(occupying_tower) and not occupying_tower.is_queued_for_deletion():
		return true
	occupied_build_cells.erase(cell)
	return false


func reserve_tower_build_cells(tower: Node2D) -> void:
	var cells := get_tower_build_cells(tower.position, tower.tower_id)
	for cell in cells:
		occupied_build_cells[cell] = tower
	tower.set_meta("build_cells", cells)


func release_tower_build_cells(tower: Node2D) -> void:
	var cells: Array = tower.get_meta("build_cells", [])
	for cell in cells:
		if occupied_build_cells.get(cell) == tower:
			occupied_build_cells.erase(cell)


func get_path_cell_positions_near(
	origin: Vector2,
	maximum_radius: float,
	build_bounds: Rect2,
	map: TowerDefenseMap
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if maximum_radius <= 0.0 or map == null:
		return positions
	var minimum_cell := world_to_build_cell(origin - Vector2.ONE * maximum_radius)
	var maximum_cell := world_to_build_cell(origin + Vector2.ONE * maximum_radius)
	var centerline_snap_distance := PLACEMENT_SNAP_SIZE * 0.75
	for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
		for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not is_build_cell_in_bounds(cell, build_bounds):
				continue
			var cell_center := get_build_cell_center(cell)
			if origin.distance_to(cell_center) > maximum_radius:
				continue
			if map.get_distance_to_nearest_path(cell_center) > centerline_snap_distance:
				continue
			positions.append(cell_center)
	return positions
