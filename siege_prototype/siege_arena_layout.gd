class_name SiegeArenaLayout
extends RefCounted

const BUILD_AREA_SIZE := Vector2i(44, 44)
const DEPLOYMENT_COLUMNS := 1
const BUILD_BUFFER_COLUMNS := 2
const BUILD_START_X := DEPLOYMENT_COLUMNS + BUILD_BUFFER_COLUMNS
const GRID_SIZE := Vector2i(BUILD_START_X + BUILD_AREA_SIZE.x, BUILD_AREA_SIZE.y)
const WALL_COUNT := 68

const STATIC_TERRAIN: Array[Vector2i] = []

const INITIAL_STRUCTURES: Array[Dictionary] = [
	{"id": &"command_core", "kind": &"command_core", "cell": Vector2i(36, 19), "footprint": Vector2i(4, 4)},
	{"id": &"cannon_1", "kind": &"cannon", "cell": Vector2i(26, 15), "footprint": Vector2i(3, 3)},
	{"id": &"cannon_2", "kind": &"cannon", "cell": Vector2i(26, 24), "footprint": Vector2i(3, 3)},
	{"id": &"cannon_3", "kind": &"cannon", "cell": Vector2i(26, 19), "footprint": Vector2i(3, 3)},
	{"id": &"archer_tower_1", "kind": &"archer_tower", "cell": Vector2i(30, 15), "footprint": Vector2i(3, 3)},
	{"id": &"archer_tower_2", "kind": &"archer_tower", "cell": Vector2i(30, 24), "footprint": Vector2i(3, 3)},
	{"id": &"archer_tower_3", "kind": &"archer_tower", "cell": Vector2i(30, 19), "footprint": Vector2i(3, 3)},
	{"id": &"mortar_1", "kind": &"mortar", "cell": Vector2i(34, 15), "footprint": Vector2i(3, 3)},
	{"id": &"mortar_2", "kind": &"mortar", "cell": Vector2i(34, 24), "footprint": Vector2i(3, 3)},
	{"id": &"air_defense_1", "kind": &"air_defense", "cell": Vector2i(38, 15), "footprint": Vector2i(3, 3)},
	{"id": &"air_defense_2", "kind": &"air_defense", "cell": Vector2i(38, 24), "footprint": Vector2i(3, 3)},
	{"id": &"wizard_tower_1", "kind": &"wizard_tower", "cell": Vector2i(42, 15), "footprint": Vector2i(3, 3)},
	{"id": &"wizard_tower_2", "kind": &"wizard_tower", "cell": Vector2i(42, 24), "footprint": Vector2i(3, 3)},
	{"id": &"air_sweeper_1", "kind": &"air_sweeper", "cell": Vector2i(42, 20), "footprint": Vector2i(2, 2)},
]


func get_initial_blueprint() -> Array[Dictionary]:
	var result: Array[Dictionary] = INITIAL_STRUCTURES.duplicate(true)
	var wall_index := 1
	for x in range(25, 46):
		result.append(_wall_entry(wall_index, Vector2i(x, 14)))
		wall_index += 1
	for x in range(25, 46):
		result.append(_wall_entry(wall_index, Vector2i(x, 28)))
		wall_index += 1
	for y in range(15, 28):
		result.append(_wall_entry(wall_index, Vector2i(25, y)))
		wall_index += 1
	for y in range(15, 28):
		result.append(_wall_entry(wall_index, Vector2i(45, y)))
		wall_index += 1
	return result


func get_run_initial_blueprint() -> Array[Dictionary]:
	return [
		{"id": &"command_core", "kind": &"command_core", "level": 1, "cell": Vector2i(36, 20), "footprint": Vector2i(4, 4)},
		{"id": &"cannon_1", "kind": &"cannon", "level": 1, "cell": Vector2i(29, 20), "footprint": Vector2i(3, 3)},
	]


func _wall_entry(index: int, cell: Vector2i) -> Dictionary:
	return {"id": StringName("wall_%d" % index), "kind": &"wall", "cell": cell, "footprint": Vector2i.ONE}


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
		and cell.x >= BUILD_START_X
		and not STATIC_TERRAIN.has(cell)
	)


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var occupied: Dictionary = {}
	var ids: Dictionary = {}
	for structure in get_initial_blueprint():
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
