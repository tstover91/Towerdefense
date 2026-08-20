extends Node

const BuildControllerScript = preload("res://build_controller.gd")


class FakeTower:
	extends Node2D
	var tower_id: StringName = &"invader"
	var manual_target_cancelled := false

	func cancel_manual_targeting() -> void:
		manual_target_cancelled = true


func _ready() -> void:
	var controller = BuildControllerScript.new()

	controller.begin_pending_tower(&"invader", 225, true)
	assert(controller.pending_tower_type == &"invader")
	assert(controller.pending_tower_cost == 225)
	assert(controller.pending_tower_is_contraband)

	var tower := FakeTower.new()
	add_child(tower)
	controller.begin_placement(tower)
	assert(controller.place_mode and controller.build_mode)
	assert(controller.tower_to_place == tower)
	controller.await_confirmation()
	assert(not controller.place_mode and controller.build_mode)

	var snapped_position: Vector2 = controller.get_tower_build_position(
		Vector2(75.0, 91.0),
		&"invader"
	)
	assert(snapped_position == Vector2(80.0, 96.0))
	var cells: Array[Vector2i] = controller.get_tower_build_cells(
		snapped_position,
		&"invader"
	)
	assert(cells.size() == 16)
	assert(cells.front() == Vector2i(3, 4))
	assert(cells.back() == Vector2i(6, 7))
	assert(controller.is_build_cell_in_bounds(
		Vector2i(3, 4),
		Rect2(Vector2.ZERO, Vector2(160.0, 160.0))
	))
	assert(not controller.is_build_cell_in_bounds(
		Vector2i(10, 4),
		Rect2(Vector2.ZERO, Vector2(160.0, 160.0))
	))
	assert(controller.can_place_tower_on_grid(
		snapped_position,
		&"invader",
		Rect2(Vector2.ZERO, Vector2(160.0, 160.0)),
		func(_cell: Vector2i) -> bool: return false
	))
	assert(not controller.can_place_tower_on_grid(
		snapped_position,
		&"invader",
		Rect2(Vector2.ZERO, Vector2(160.0, 160.0)),
		func(cell: Vector2i) -> bool: return cell == Vector2i(4, 5)
	))

	tower.position = snapped_position
	controller.reserve_tower_build_cells(tower)
	for cell in cells:
		assert(controller.is_build_cell_occupied(cell))
	controller.release_tower_build_cells(tower)
	for cell in cells:
		assert(not controller.is_build_cell_occupied(cell))

	var first_target := FakeTower.new()
	var second_target := FakeTower.new()
	add_child(first_target)
	add_child(second_target)
	assert(controller.begin_manual_targeting(first_target) == null)
	assert(controller.begin_manual_targeting(second_target) == first_target)
	assert(controller.take_manual_targeting_tower() == second_target)
	assert(controller.manual_targeting_tower == null)

	assert(controller.clear_pending_placement() == tower)
	assert(not controller.place_mode and not controller.build_mode)
	assert(controller.pending_tower_type.is_empty())
	assert(controller.pending_tower_cost == 0)
	assert(not controller.pending_tower_is_contraband)

	print("Build controller smoke test passed: state, snapping, bounds, occupancy, and targeting.")
	get_tree().quit(0)
