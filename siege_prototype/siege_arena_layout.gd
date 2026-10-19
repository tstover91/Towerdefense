class_name SiegeArenaLayout
extends RefCounted

const GRID_SIZE := Vector2i(28, 16)
const DEPLOYMENT_COLUMNS := 1
const BUILD_BUFFER_COLUMNS := 1

const STATIC_TERRAIN: Array[Vector2i] = [
	Vector2i(19, 0),
	Vector2i(19, 1),
	Vector2i(19, 14),
	Vector2i(19, 15),
]

const INITIAL_BLUEPRINT: Array[Dictionary] = [
	{"id": &"command_core", "kind": &"command_core", "cell": Vector2i(24, 7), "footprint": Vector2i(2, 2)},
	{"id": &"cannon_1", "kind": &"cannon", "cell": Vector2i(21, 4), "footprint": Vector2i.ONE},
	{"id": &"cannon_2", "kind": &"cannon", "cell": Vector2i(21, 11), "footprint": Vector2i.ONE},
	{"id": &"cannon_3", "kind": &"cannon", "cell": Vector2i(26, 7), "footprint": Vector2i.ONE},
	{"id": &"archer_tower_1", "kind": &"archer_tower", "cell": Vector2i(23, 3), "footprint": Vector2i.ONE},
	{"id": &"archer_tower_2", "kind": &"archer_tower", "cell": Vector2i(23, 12), "footprint": Vector2i.ONE},
	{"id": &"archer_tower_3", "kind": &"archer_tower", "cell": Vector2i(26, 10), "footprint": Vector2i.ONE},
	{"id": &"mortar_1", "kind": &"mortar", "cell": Vector2i(21, 7), "footprint": Vector2i.ONE},
	{"id": &"mortar_2", "kind": &"mortar", "cell": Vector2i(21, 9), "footprint": Vector2i.ONE},
	{"id": &"air_defense_1", "kind": &"air_defense", "cell": Vector2i(24, 4), "footprint": Vector2i.ONE},
	{"id": &"air_defense_2", "kind": &"air_defense", "cell": Vector2i(24, 11), "footprint": Vector2i.ONE},
	{"id": &"wizard_tower_1", "kind": &"wizard_tower", "cell": Vector2i(23, 6), "footprint": Vector2i.ONE},
	{"id": &"wizard_tower_2", "kind": &"wizard_tower", "cell": Vector2i(23, 9), "footprint": Vector2i.ONE},
	{"id": &"air_sweeper_1", "kind": &"air_sweeper", "cell": Vector2i(26, 5), "footprint": Vector2i.ONE},
	{"id": &"wall_1", "kind": &"wall", "cell": Vector2i(19, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_2", "kind": &"wall", "cell": Vector2i(20, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_3", "kind": &"wall", "cell": Vector2i(21, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_4", "kind": &"wall", "cell": Vector2i(22, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_5", "kind": &"wall", "cell": Vector2i(23, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_6", "kind": &"wall", "cell": Vector2i(24, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_7", "kind": &"wall", "cell": Vector2i(25, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_8", "kind": &"wall", "cell": Vector2i(26, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_9", "kind": &"wall", "cell": Vector2i(27, 2), "footprint": Vector2i.ONE},
	{"id": &"wall_10", "kind": &"wall", "cell": Vector2i(19, 13), "footprint": Vector2i.ONE},
	{"id": &"wall_11", "kind": &"wall", "cell": Vector2i(20, 13), "footprint": Vector2i.ONE},
	{"id": &"wall_12", "kind": &"wall", "cell": Vector2i(21, 13), "footprint": Vector2i.ONE},
	{"id": &"wall_13", "kind": &"wall", "cell": Vector2i(22, 13), "footprint": Vector2i.ONE},
	{"id": &"wall_14", "kind": &"wall", "cell": Vector2i(23, 13), "footprint": Vector2i.ONE},
	{"id": &"wall_15", "kind": &"wall", "cell": Vector2i(24, 13), "footprint": Vector2i.ONE},
	{"id": &"wall_16", "kind": &"wall", "cell": Vector2i(25, 13), "footprint": Vector2i.ONE},
	{"id": &"wall_17", "kind": &"wall", "cell": Vector2i(26, 13), "footprint": Vector2i.ONE},
	{"id": &"wall_18", "kind": &"wall", "cell": Vector2i(27, 13), "footprint": Vector2i.ONE},
	{"id": &"wall_19", "kind": &"wall", "cell": Vector2i(19, 3), "footprint": Vector2i.ONE},
	{"id": &"wall_20", "kind": &"wall", "cell": Vector2i(19, 4), "footprint": Vector2i.ONE},
	{"id": &"wall_21", "kind": &"wall", "cell": Vector2i(19, 5), "footprint": Vector2i.ONE},
	{"id": &"wall_22", "kind": &"wall", "cell": Vector2i(19, 6), "footprint": Vector2i.ONE},
	{"id": &"wall_23", "kind": &"wall", "cell": Vector2i(19, 7), "footprint": Vector2i.ONE},
	{"id": &"wall_24", "kind": &"wall", "cell": Vector2i(19, 8), "footprint": Vector2i.ONE},
	{"id": &"wall_25", "kind": &"wall", "cell": Vector2i(19, 9), "footprint": Vector2i.ONE},
	{"id": &"wall_26", "kind": &"wall", "cell": Vector2i(19, 10), "footprint": Vector2i.ONE},
	{"id": &"wall_27", "kind": &"wall", "cell": Vector2i(19, 11), "footprint": Vector2i.ONE},
	{"id": &"wall_28", "kind": &"wall", "cell": Vector2i(19, 12), "footprint": Vector2i.ONE},
	{"id": &"wall_29", "kind": &"wall", "cell": Vector2i(27, 3), "footprint": Vector2i.ONE},
	{"id": &"wall_30", "kind": &"wall", "cell": Vector2i(27, 4), "footprint": Vector2i.ONE},
	{"id": &"wall_31", "kind": &"wall", "cell": Vector2i(27, 5), "footprint": Vector2i.ONE},
	{"id": &"wall_32", "kind": &"wall", "cell": Vector2i(27, 6), "footprint": Vector2i.ONE},
	{"id": &"wall_33", "kind": &"wall", "cell": Vector2i(27, 7), "footprint": Vector2i.ONE},
	{"id": &"wall_34", "kind": &"wall", "cell": Vector2i(27, 8), "footprint": Vector2i.ONE},
	{"id": &"wall_35", "kind": &"wall", "cell": Vector2i(27, 9), "footprint": Vector2i.ONE},
	{"id": &"wall_36", "kind": &"wall", "cell": Vector2i(27, 10), "footprint": Vector2i.ONE},
	{"id": &"wall_37", "kind": &"wall", "cell": Vector2i(27, 11), "footprint": Vector2i.ONE},
	{"id": &"wall_38", "kind": &"wall", "cell": Vector2i(27, 12), "footprint": Vector2i.ONE},
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
