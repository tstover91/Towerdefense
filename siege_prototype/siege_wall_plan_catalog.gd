class_name SiegeWallPlanCatalog
extends RefCounted


static func get_opening_plans() -> Array[Dictionary]:
	return get_plan_choices(1, 25)


static func get_plan_choices(fortress_rank: int, available_walls: int) -> Array[Dictionary]:
	var preferences: Dictionary = {
		1: [&"wide_compartment", &"core_box", &"defense_pocket"],
		2: [&"sidecar_pocket", &"u_funnel", &"dogleg_channel"],
		3: [&"twin_compartments", &"sidecar_pocket", &"dogleg_channel"],
		4: [&"dead_zone_pair", &"twin_compartments", &"u_funnel"],
		5: [&"twin_compartments", &"dogleg_channel", &"sidecar_pocket"],
		6: [&"ring", &"grid", &"island_cluster"],
	}
	var result: Array[Dictionary] = []
	var preferred_ids: Array = preferences.get(clampi(fortress_rank, 1, 6), [])
	for plan_id in preferred_ids:
		_add_choice_if_available(result, get_plan(StringName(plan_id)), fortress_rank, available_walls)
	if result.size() < 3:
		for plan in get_all_plans():
			_add_choice_if_available(result, plan, fortress_rank, available_walls)
			if result.size() >= 3:
				break
	return result


static func get_all_plans() -> Array[Dictionary]:
	return [
		{
			"id": &"wide_compartment",
			"name": "WIDE COMPARTMENT",
			"min_rank": 1,
			"cells": _rectangle_perimeter(9, 5),
			"preferred_origin": Vector2i(18, 18),
		},
		{
			"id": &"core_box",
			"name": "CORE BOX",
			"min_rank": 1,
			"cells": _rectangle_perimeter(6, 6),
			"preferred_origin": Vector2i(23, 14),
		},
		{
			"id": &"defense_pocket",
			"name": "DEFENSE POCKET",
			"min_rank": 1,
			"cells": _rectangle_perimeter(5, 5),
			"preferred_origin": Vector2i(33, 19),
		},
		{
			"id": &"sidecar_pocket",
			"name": "SIDECAR POCKET",
			"min_rank": 2,
			"cells": _sidecar_pocket(),
			"preferred_origin": Vector2i(-1, -1),
		},
		{
			"id": &"u_funnel",
			"name": "U-FUNNEL",
			"min_rank": 2,
			"cells": _u_funnel(),
			"preferred_origin": Vector2i(18, 18),
		},
		{
			"id": &"dogleg_channel",
			"name": "DOGLEG CHANNEL",
			"min_rank": 2,
			"cells": _dogleg_channel(),
			"preferred_origin": Vector2i(20, 18),
		},
		{
			"id": &"twin_compartments",
			"name": "TWIN COMPARTMENTS",
			"min_rank": 3,
			"cells": _twin_compartments(),
			"preferred_origin": Vector2i(-1, -1),
		},
		{
			"id": &"dead_zone_pair",
			"name": "DEAD-ZONE PAIR",
			"min_rank": 4,
			"cells": _dead_zone_pair(),
			"preferred_origin": Vector2i(18, 18),
		},
		{
			"id": &"island_cluster",
			"name": "ISLAND CLUSTER",
			"min_rank": 6,
			"cells": _island_cluster(),
			"preferred_origin": Vector2i(18, 14),
		},
		{
			"id": &"ring",
			"name": "RING",
			"min_rank": 6,
			"cells": _ring(),
			"preferred_origin": Vector2i(27, 16),
		},
		{
			"id": &"grid",
			"name": "2×2 GRID",
			"min_rank": 6,
			"cells": _grid(),
			"preferred_origin": Vector2i(18, 16),
		},
	]


static func get_plan(plan_id: StringName) -> Dictionary:
	for plan in get_all_plans():
		if StringName(plan.get("id", &"")) == plan_id:
			return plan.duplicate(true)
	return {}


static func _add_choice_if_available(
	choices: Array[Dictionary],
	plan: Dictionary,
	fortress_rank: int,
	available_walls: int
) -> void:
	if plan.is_empty() or choices.size() >= 3:
		return
	if int(plan.get("min_rank", 1)) > fortress_rank:
		return
	var cells: Array = plan.get("cells", [])
	if cells.is_empty() or cells.size() > available_walls:
		return
	var plan_id := StringName(plan.get("id", &""))
	for choice in choices:
		if StringName(choice.get("id", &"")) == plan_id:
			return
	choices.append(plan.duplicate(true))


static func _rectangle_perimeter(width: int, height: int) -> Array[Vector2i]:
	return _rectangle_perimeter_at(Vector2i.ZERO, width, height)


static func _rectangle_perimeter_at(origin: Vector2i, width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in width:
		_append_unique(cells, origin + Vector2i(x, 0))
		_append_unique(cells, origin + Vector2i(x, height - 1))
	for y in range(1, height - 1):
		_append_unique(cells, origin + Vector2i(0, y))
		_append_unique(cells, origin + Vector2i(width - 1, y))
	return cells


static func _left_attachment(height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in height:
		cells.append(Vector2i(0, y))
	return cells


static func _sidecar_pocket() -> Array[Vector2i]:
	var cells := _rectangle_perimeter(5, 5)
	for required_cell in _left_attachment(5):
		cells.erase(required_cell)
	return cells


static func _u_funnel() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in 7:
		_append_unique(cells, Vector2i(x, 0))
		_append_unique(cells, Vector2i(x, 5))
	for y in range(1, 5):
		_append_unique(cells, Vector2i(6, y))
	return cells


static func _dogleg_channel() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in 7:
		_append_unique(cells, Vector2i(x, 0))
	for y in range(1, 5):
		_append_unique(cells, Vector2i(6, y))
	for x in 5:
		_append_unique(cells, Vector2i(x, 2))
	for y in range(3, 5):
		_append_unique(cells, Vector2i(4, y))
	return cells


static func _twin_compartments() -> Array[Vector2i]:
	var cells := _rectangle_perimeter(9, 5)
	for y in range(1, 4):
		_append_unique(cells, Vector2i(4, y))
	for required_cell in _left_attachment(5):
		cells.erase(required_cell)
	return cells


static func _dead_zone_pair() -> Array[Vector2i]:
	var cells := _rectangle_perimeter_at(Vector2i.ZERO, 5, 5)
	for cell in _rectangle_perimeter_at(Vector2i(7, 0), 5, 5):
		_append_unique(cells, cell)
	return cells


static func _island_cluster() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for origin in [Vector2i.ZERO, Vector2i(7, 0), Vector2i(3, 7)]:
		for cell in _rectangle_perimeter_at(origin, 5, 5):
			_append_unique(cells, cell)
	return cells


static func _ring() -> Array[Vector2i]:
	var cells := _rectangle_perimeter(9, 9)
	for cell in _rectangle_perimeter_at(Vector2i(2, 2), 5, 5):
		_append_unique(cells, cell)
	return cells


static func _grid() -> Array[Vector2i]:
	var cells := _rectangle_perimeter(9, 9)
	for offset in range(1, 8):
		_append_unique(cells, Vector2i(4, offset))
		_append_unique(cells, Vector2i(offset, 4))
	return cells


static func _append_unique(cells: Array[Vector2i], cell: Vector2i) -> void:
	if not cells.has(cell):
		cells.append(cell)
