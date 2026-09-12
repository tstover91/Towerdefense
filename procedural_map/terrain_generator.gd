class_name ProceduralTerrainGenerator
extends RefCounted

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const GenerationProfile = preload(
	"res://procedural_map/terrain_generation_profile.gd"
)
const DEFAULT_PROFILE = preload(
	"res://procedural_map/farm_generation_profile.tres"
)

const GRID_SIZE := Vector2i(36, 20)
const EDGE_CLEARANCE_COLUMNS := 1

var cells: Array[int] = []
var map_seed := 1
var profile: Resource
var grid_size := GRID_SIZE
var non_field_cell_count := 0
var maximum_non_field_cells := 0
var blob_owners: PackedInt32Array = PackedInt32Array()
var next_blob_id := 0


func _init(generation_profile: Resource = null) -> void:
	configure(generation_profile if generation_profile != null else DEFAULT_PROFILE)


func configure(generation_profile: Resource) -> void:
	profile = generation_profile
	grid_size = profile.grid_size


func generate(seed_value: int) -> Array[int]:
	map_seed = seed_value
	cells.resize(grid_size.x * grid_size.y)
	cells.fill(Terrain.TerrainType.FIELD)
	blob_owners.resize(cells.size())
	blob_owners.fill(-1)
	next_blob_id = 0
	non_field_cell_count = 0
	maximum_non_field_cells = floori(
		float(cells.size()) * (1.0 - profile.minimum_field_ratio)
	)
	_paint_protected_forest()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for _blob_index in profile.forest_blob_count:
		_grow_blob(
			rng,
			Terrain.TerrainType.FOREST,
			rng.randi_range(
				profile.forest_blob_min_size,
				profile.forest_blob_max_size
			),
			profile.forest_compactness
		)
	for _blob_index in profile.mud_blob_count:
		_grow_blob(
			rng,
			Terrain.TerrainType.MUD,
			rng.randi_range(
				profile.mud_blob_min_size,
				profile.mud_blob_max_size
			),
			profile.mud_compactness
		)
	for band_index in profile.soft_band_count:
		_paint_meandering_band(
			rng,
			(
				Terrain.TerrainType.FOREST
					if band_index % 2 == 0
					else Terrain.TerrainType.MUD
			)
		)
	return cells.duplicate()


func get_terrain(cell: Vector2i) -> int:
	if not contains(cell):
		return Terrain.TerrainType.FIELD
	return cells[_index(cell)]


func contains(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)


func count_terrain(terrain_type: int) -> int:
	return cells.count(terrain_type)


func get_field_ratio() -> float:
	if cells.is_empty():
		return 1.0
	return float(count_terrain(Terrain.TerrainType.FIELD)) / float(cells.size())


func _grow_blob(
	rng: RandomNumberGenerator,
	terrain_type: int,
	target_cells: int,
	compactness: float
) -> void:
	var blob_id := next_blob_id
	next_blob_id += 1
	var center := _find_blob_start(rng, blob_id)
	if center.x < 0:
		return
	var frontier: Array[Vector2i] = [center]
	var claimed: Array[Vector2i] = []
	var queued := {center: true}

	while (
		not frontier.is_empty()
		and claimed.size() < target_cells
		and non_field_cell_count < maximum_non_field_cells
	):
		var frontier_index := (
			0
				if rng.randf() < compactness
				else rng.randi_range(0, frontier.size() - 1)
		)
		var current: Vector2i = frontier.pop_at(frontier_index)
		if not _can_paint(current, blob_id):
			continue
		_paint_cell(current, terrain_type, blob_id)
		claimed.append(current)

		var directions: Array[Vector2i] = [
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.UP,
			Vector2i.DOWN,
		]
		_shuffle_directions(directions, rng)
		for direction in directions:
			var neighbor: Vector2i = current + direction
			if _can_paint(neighbor, blob_id) and not queued.has(neighbor):
				queued[neighbor] = true
				frontier.append(neighbor)


func _paint_protected_forest() -> void:
	for y in profile.safe_top_rows:
		for x in grid_size.x:
			_paint_cell(Vector2i(x, y), Terrain.TerrainType.FOREST, -2)
	for y_offset in profile.safe_bottom_rows:
		var y: int = grid_size.y - 1 - y_offset
		for x in grid_size.x:
			_paint_cell(Vector2i(x, y), Terrain.TerrainType.FOREST, -2)
	for y in profile.protected_right_top_rows:
		for x_offset in profile.protected_right_columns:
			_paint_cell(
				Vector2i(grid_size.x - 1 - x_offset, y),
				Terrain.TerrainType.FOREST,
				-2
			)
	for y_offset in profile.protected_right_bottom_rows:
		var y: int = grid_size.y - 1 - y_offset
		for x_offset in profile.protected_right_columns:
			_paint_cell(
				Vector2i(grid_size.x - 1 - x_offset, y),
				Terrain.TerrainType.FOREST,
				-2
			)


func _paint_meandering_band(
	rng: RandomNumberGenerator,
	terrain_type: int
) -> void:
	var band_x := rng.randi_range(4, grid_size.x - 6)
	var gap_center := rng.randi_range(1, grid_size.y - 2)
	var gap_half_height := rng.randi_range(0, 1)
	for y in grid_size.y:
		if absi(y - gap_center) <= gap_half_height:
			continue
		if y > 0 and y % 2 == 0:
			band_x = clampi(band_x + rng.randi_range(-1, 1), 2, grid_size.x - 4)
		for x_offset in 2:
			if non_field_cell_count >= maximum_non_field_cells:
				return
			var cell := Vector2i(band_x + x_offset, y)
			if _can_paint(cell, next_blob_id):
				_paint_cell(cell, terrain_type, next_blob_id)
	next_blob_id += 1


func _paint_cell(cell: Vector2i, terrain_type: int, blob_id: int) -> void:
	var index := _index(cell)
	if cells[index] == Terrain.TerrainType.FIELD:
		non_field_cell_count += 1
	cells[index] = terrain_type
	blob_owners[index] = blob_id


func _can_paint(cell: Vector2i, blob_id: int) -> bool:
	if (
		not contains(cell)
		or cell.x < profile.edge_clearance_columns
		or cell.x >= grid_size.x - profile.edge_clearance_columns
		or cell.y < profile.safe_top_rows
		or cell.y >= grid_size.y - profile.safe_bottom_rows
	):
		return false
	var owner := blob_owners[_index(cell)]
	if owner != -1 and owner != blob_id:
		return false
	var border: int = profile.field_border_between_blobs
	for y_offset in range(-border, border + 1):
		for x_offset in range(-border, border + 1):
			var nearby := cell + Vector2i(x_offset, y_offset)
			if not contains(nearby):
				continue
			var nearby_owner := blob_owners[_index(nearby)]
			# Negative owners are fixed map boundaries. Blobs may meet those
			# boundaries, but still keep field between separate generated blobs.
			if nearby_owner >= 0 and nearby_owner != blob_id:
				return false
	return true


func _find_blob_start(rng: RandomNumberGenerator, blob_id: int) -> Vector2i:
	for _attempt in 100:
		var candidate := Vector2i(
			rng.randi_range(
				profile.edge_clearance_columns,
				grid_size.x - profile.edge_clearance_columns - 1
			),
			rng.randi_range(
				profile.safe_top_rows,
				grid_size.y - profile.safe_bottom_rows - 1
			)
		)
		if _can_paint(candidate, blob_id):
			return candidate
	for y in range(profile.safe_top_rows, grid_size.y - profile.safe_bottom_rows):
		for x in range(
			profile.edge_clearance_columns,
			grid_size.x - profile.edge_clearance_columns
		):
			var candidate := Vector2i(x, y)
			if _can_paint(candidate, blob_id):
				return candidate
	return Vector2i(-1, -1)


func _index(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x


func _shuffle_directions(
	directions: Array[Vector2i],
	rng: RandomNumberGenerator
) -> void:
	for index in range(directions.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := directions[index]
		directions[index] = directions[swap_index]
		directions[swap_index] = held
