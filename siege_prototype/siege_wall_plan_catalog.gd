class_name SiegeWallPlanCatalog
extends RefCounted


static func get_opening_plans() -> Array[Dictionary]:
	return [
		{
			"id": &"split_compartments",
			"name": "SPLIT COMPARTMENTS",
			"description": "Two 3×3 defense pockets sharing an internal breach wall.",
			"cells": _split_compartments(),
			"preferred_origin": Vector2i(18, 18),
		},
		{
			"id": &"offset_compartment",
			"name": "OFFSET COMPARTMENT",
			"description": "One closed defense pocket with an offset routing wing.",
			"cells": _offset_compartment(),
			"preferred_origin": Vector2i(23, 14),
		},
		{
			"id": &"core_and_screen",
			"name": "CORE AND SCREEN",
			"description": "A 4×4 Core pocket protected by a separate approach screen.",
			"cells": _core_and_screen(),
			"preferred_origin": Vector2i(33, 19),
		},
	]


static func get_plan(plan_id: StringName) -> Dictionary:
	for plan in get_opening_plans():
		if StringName(plan.get("id", &"")) == plan_id:
			return plan.duplicate(true)
	return {}


static func _split_compartments() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in 9:
		if x != 0:
			cells.append(Vector2i(x, 0))
		if x != 8:
			cells.append(Vector2i(x, 4))
	for y in range(1, 4):
		cells.append(Vector2i(0, y))
		cells.append(Vector2i(4, y))
		cells.append(Vector2i(8, y))
	return cells


static func _offset_compartment() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in 5:
		cells.append(Vector2i(x, 0))
		cells.append(Vector2i(x, 4))
	for y in range(1, 4):
		cells.append(Vector2i(0, y))
		cells.append(Vector2i(4, y))
	for x in range(5, 9):
		cells.append(Vector2i(x, 2))
	for y in range(3, 5):
		cells.append(Vector2i(8, y))
	return cells


static func _core_and_screen() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(2, 8):
		cells.append(Vector2i(x, 0))
		cells.append(Vector2i(x, 5))
	for y in range(1, 5):
		cells.append(Vector2i(2, y))
		cells.append(Vector2i(7, y))
	for y in range(1, 5):
		cells.append(Vector2i(0, y))
	return cells
