class_name SiegeArenaLayout
extends RefCounted

const GRID_SIZE := Vector2i(14, 10)
const DEPLOYMENT_COLUMNS := 1
const BUILD_BUFFER_COLUMNS := 1

const STATIC_TERRAIN: Array[Vector2i] = [
	Vector2i(5, 0),
	Vector2i(6, 0),
	Vector2i(5, 9),
	Vector2i(6, 9),
]

const INITIAL_BLUEPRINT: Array[Dictionary] = [
	{"id": &"command_core", "kind": &"command_core", "cell": Vector2i(11, 4), "footprint": Vector2i(2, 2)},
	{"id": &"north_cannon", "kind": &"cannon", "cell": Vector2i(9, 2), "footprint": Vector2i.ONE},
	{"id": &"south_cannon", "kind": &"cannon", "cell": Vector2i(9, 7), "footprint": Vector2i.ONE},
	{"id": &"wall_1", "kind": &"wall", "cell": Vector2i(7, 1), "footprint": Vector2i.ONE},
	{"id": &"wall_2", "kind": &"wall", "cell": Vector2i(7, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_3", "kind": &"wall", "cell": Vector2i(7, 3), "footprint": Vector2i.ONE},
	{"id": &"wall_4", "kind": &"wall", "cell": Vector2i(7, 4), "footprint": Vector2i.ONE},
	{"id": &"wall_5", "kind": &"wall", "cell": Vector2i(7, 5), "footprint": Vector2i.ONE},
	{"id": &"wall_6", "kind": &"wall", "cell": Vector2i(7, 6), "footprint": Vector2i.ONE},
	{"id": &"wall_7", "kind": &"wall", "cell": Vector2i(7, 7), "footprint": Vector2i.ONE},
	{"id": &"wall_8", "kind": &"wall", "cell": Vector2i(7, 8), "footprint": Vector2i.ONE},
]


func get_initial_blueprint() -> Array[Dictionary]:
	return INITIAL_BLUEPRINT.duplicate(true)


func get_deployment_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in DEPLOYMENT_COLUMNS:
		for y in GRID_SIZE.y:
			result.append(Vector2i(x, y))
	return result


func get_structure_cells(structure: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := Vector2i(structure.get("cell", Vector2i(-1, -1)))
	var footprint := Vector2i(structure.get("footprint", Vector2i.ONE))
	for x in footprint.x:
		for y in footprint.y:
			result.append(origin + Vector2i(x, y))
	return result


func is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


func is_deployment_cell(cell: Vector2i) -> bool:
	return is_inside_grid(cell) and cell.x < DEPLOYMENT_COLUMNS


func is_buildable_cell(cell: Vector2i) -> bool:
	return (
		is_inside_grid(cell)
		and cell.x >= DEPLOYMENT_COLUMNS + BUILD_BUFFER_COLUMNS
		and not STATIC_TERRAIN.has(cell)
	)


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var occupied: Dictionary = {}
	var ids: Dictionary = {}
	for structure in INITIAL_BLUEPRINT:
		var structure_id := StringName(structure.get("id", &""))
		if structure_id == &"" or ids.has(structure_id):
			errors.append("Every initial structure needs a unique non-empty id.")
		ids[structure_id] = true
		for cell in get_structure_cells(structure):
			if not is_buildable_cell(cell):
				errors.append("Structure %s occupies non-buildable cell %s." % [structure_id, cell])
			if occupied.has(cell):
				errors.append("Structures %s and %s overlap at %s." % [occupied[cell], structure_id, cell])
			occupied[cell] = structure_id
	return errors
