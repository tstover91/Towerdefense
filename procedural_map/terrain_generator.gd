class_name ProceduralTerrainGenerator
extends RefCounted

const Terrain = preload("res://procedural_map/terrain_catalog.gd")

const GRID_SIZE := Vector2i(18, 10)
const FOREST_BLOB_COUNT := 3
const MUD_BLOB_COUNT := 2
const SOFT_BARRIER_COUNT := 2
const EDGE_CLEARANCE_COLUMNS := 1

var cells: Array[int] = []
var map_seed := 1


func generate(seed_value: int) -> Array[int]:
	map_seed = seed_value
	cells.resize(GRID_SIZE.x * GRID_SIZE.y)
	cells.fill(Terrain.TerrainType.FIELD)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for _blob_index in FOREST_BLOB_COUNT:
		_grow_blob(
			rng,
			Terrain.TerrainType.FOREST,
			rng.randi_range(8, 15),
			0.72
		)
	for _blob_index in MUD_BLOB_COUNT:
		_grow_blob(
			rng,
			Terrain.TerrainType.MUD,
			rng.randi_range(6, 11),
			0.58
		)
	for barrier_index in SOFT_BARRIER_COUNT:
		_paint_meandering_band(
			rng,
			(
				Terrain.TerrainType.FOREST
				if barrier_index == 0
				else Terrain.TerrainType.MUD
			)
		)
	_clear_entry_and_exit()
	return cells.duplicate()


func get_terrain(cell: Vector2i) -> int:
	if not contains(cell):
		return Terrain.TerrainType.FIELD
	return cells[_index(cell)]


func contains(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < GRID_SIZE.x
		and cell.y < GRID_SIZE.y
	)


func count_terrain(terrain_type: int) -> int:
	return cells.count(terrain_type)


func _grow_blob(
	rng: RandomNumberGenerator,
	terrain_type: int,
	target_cells: int,
	compactness: float
) -> void:
	var center := Vector2i(
		rng.randi_range(EDGE_CLEARANCE_COLUMNS, GRID_SIZE.x - EDGE_CLEARANCE_COLUMNS - 1),
		rng.randi_range(1, GRID_SIZE.y - 2)
	)
	var frontier: Array[Vector2i] = [center]
	var claimed: Array[Vector2i] = []
	var claimed_lookup := {center: true}

	while not frontier.is_empty() and claimed.size() < target_cells:
		var frontier_index := (
			frontier.size() - 1
			if rng.randf() < compactness
			else rng.randi_range(0, frontier.size() - 1)
		)
		var current: Vector2i = frontier.pop_at(frontier_index)
		if not _can_paint(current):
			continue
		cells[_index(current)] = terrain_type
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
			if _can_paint(neighbor) and not claimed_lookup.has(neighbor):
				claimed_lookup[neighbor] = true
				frontier.append(neighbor)


func _clear_entry_and_exit() -> void:
	for y in GRID_SIZE.y:
		for x in EDGE_CLEARANCE_COLUMNS:
			cells[_index(Vector2i(x, y))] = Terrain.TerrainType.FIELD
			cells[_index(Vector2i(GRID_SIZE.x - 1 - x, y))] = (
				Terrain.TerrainType.FIELD
			)


func _paint_meandering_band(
	rng: RandomNumberGenerator,
	terrain_type: int
) -> void:
	var band_x := rng.randi_range(4, GRID_SIZE.x - 6)
	var gap_center := rng.randi_range(1, GRID_SIZE.y - 2)
	var gap_half_height := rng.randi_range(0, 1)
	for y in GRID_SIZE.y:
		if absi(y - gap_center) <= gap_half_height:
			continue
		if y > 0 and y % 2 == 0:
			band_x = clampi(
				band_x + rng.randi_range(-1, 1),
				2,
				GRID_SIZE.x - 4
			)
		for x_offset in 2:
			var cell := Vector2i(band_x + x_offset, y)
			if _can_paint(cell):
				cells[_index(cell)] = terrain_type


func _can_paint(cell: Vector2i) -> bool:
	return (
		contains(cell)
		and cell.x >= EDGE_CLEARANCE_COLUMNS
		and cell.x < GRID_SIZE.x - EDGE_CLEARANCE_COLUMNS
	)


func _index(cell: Vector2i) -> int:
	return cell.y * GRID_SIZE.x + cell.x


func _shuffle_directions(
	directions: Array[Vector2i],
	rng: RandomNumberGenerator
) -> void:
	for index in range(directions.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := directions[index]
		directions[index] = directions[swap_index]
		directions[swap_index] = held
