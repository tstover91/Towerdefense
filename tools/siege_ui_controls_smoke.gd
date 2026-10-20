extends SceneTree

const BoardScript = preload("res://siege_prototype/siege_board.gd")

var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	var board: Node2D = BoardScript.new()
	get_root().add_child(board)
	await process_frame
	board.set_edit_mode(true)

	var cannon: Node2D = board.get_structure(&"cannon_1")
	var archer: Node2D = board.get_structure(&"archer_tower_1")
	var archer_center: Vector2 = board.cell_rect(archer.grid_cell).get_center()
	_assert(not board._begin_structure_drag_candidate_at(archer_center), "an unselected building does not steal a camera drag")

	board.select_structure(cannon)
	_assert(board.get_selected_tower_range_cells() == Vector2(0.0, 9.0), "a selected Cannon exposes its exact nine-cell firing radius")
	var cannon_center: Vector2 = board.board_origin + (Vector2(cannon.grid_cell) + Vector2(cannon.footprint) * 0.5) * board.cell_size
	_assert(board._begin_structure_drag_candidate_at(cannon_center), "the selected building can begin a direct drag")
	_assert(board.structure_drag_pointer_offset == Vector2(1.5, 1.5), "tower dragging uses the center of its three-by-three footprint")
	var cannon_origin: Vector2i = cannon.grid_cell
	var invalid_drop_position: Vector2 = board.board_origin + Vector2(0.5, 5.5) * board.cell_size
	board._update_structure_drag(invalid_drop_position)
	_assert(cannon.grid_cell == cannon_origin, "dragging keeps the saved grid layout unchanged until release")
	_assert(not board.structure_drag_drop_valid, "the snapped footprint marks a blocked destination invalid")
	board._finish_structure_drag(invalid_drop_position)
	_assert(cannon.grid_cell == cannon_origin, "an invalid release returns the building to its original cell")

	var simple_blueprint: Array[Dictionary] = [
		{"id": &"wall_test", "kind": &"wall", "level": 1, "cell": Vector2i(20, 20), "footprint": Vector2i.ONE},
		{"id": &"mortar_test", "kind": &"mortar", "level": 1, "cell": Vector2i(30, 30), "footprint": Vector2i(3, 3)},
	]
	board.load_blueprint(simple_blueprint)
	board.select_structure(board.get_structure(&"mortar_test"))
	_assert(board.get_selected_tower_range_cells() == Vector2(4.0, 11.0), "a selected Mortar exposes both its four-cell dead zone and eleven-cell outer radius")
	var wall: Node2D = board.get_structure(&"wall_test")
	board.select_structure(wall)
	_assert(board.get_selected_tower_range_cells() == Vector2.ZERO, "Walls never show a tower range ring")
	_assert(board.pending_build_kind == &"", "selecting a wall does not silently begin a purchase")
	_assert(board.get_wall_extension_cells().size() == 4, "a selected isolated wall exposes all four valid extension directions")

	board.begin_wall_chain_from_existing(Vector2i(20, 20), 4)
	_assert(board._append_wall_chain_cell(Vector2i(21, 20)), "wall drawing starts from an available arrow")
	_assert(board._append_wall_chain_cell(Vector2i(22, 20)), "wall drawing extends through adjacent cells")
	_assert(board._append_wall_chain_cell(Vector2i(22, 21)), "one wall gesture can turn a corner")
	_assert(board.get_pending_wall_count() == 3, "the full unconfirmed wall path is tracked as one batch")
	_assert(board.get_structure_count(&"wall") == 1, "wall previews do not mutate the live layout")
	_assert(board._append_wall_chain_cell(Vector2i(22, 20)), "dragging backward removes the last preview segment")
	_assert(board.get_pending_wall_count() == 2, "wall drawing supports one-cell backtracking")
	_assert(board._append_wall_chain_cell(Vector2i(22, 21)), "the corner can be redrawn after backtracking")
	_assert(board._append_wall_chain_cell(Vector2i(21, 21)), "the batch can use all available wall slots")
	_assert(not board._append_wall_chain_cell(Vector2i(20, 21)), "the wall allowance caps the preview path")
	var added: Array[Node2D] = board.confirm_pending_wall_chain()
	_assert(added.size() == 4, "confirm commits the entire wall chain once")
	_assert(board.get_structure_count(&"wall") == 5, "batch confirmation adds every previewed segment")

	var confirmed_blueprint: Array[Dictionary] = board.capture_current_blueprint()
	var last_wall: Node2D = board.get_selected_structure()
	board.begin_wall_chain_from_existing(last_wall.grid_cell, 3)
	var cancel_cell: Vector2i = last_wall.grid_cell + Vector2i.DOWN
	if not board.can_place_structure(&"wall", cancel_cell):
		cancel_cell = last_wall.grid_cell + Vector2i.RIGHT
	_assert(board._append_wall_chain_cell(cancel_cell), "a second batch can be previewed")
	board.cancel_build()
	_assert(board.capture_current_blueprint() == confirmed_blueprint, "cancel discards the whole wall preview without changing the layout")

	var row_blueprint: Array[Dictionary] = []
	for row_index in 5:
		row_blueprint.append({
			"id": StringName("row_wall_%d" % row_index),
			"kind": &"wall",
			"level": row_index % 2 + 1,
			"cell": Vector2i(18 + row_index, 18),
			"footprint": Vector2i.ONE,
		})
	board.load_blueprint(row_blueprint)
	board.select_structure(board.get_structure(&"row_wall_2"))
	_assert(board.get_selectable_wall_row_count() == 5, "Select Row finds the longest contiguous straight run")
	_assert(board.select_wall_row() and board.get_selected_wall_row_count() == 5, "Select Row selects every wall in that run")
	_assert(board.get_wall_extension_cells().is_empty(), "row selection suppresses single-wall extension arrows")
	var row_drag_start: Vector2 = board.cell_rect(Vector2i(20, 18)).get_center()
	_assert(board._begin_structure_drag_candidate_at(row_drag_start), "pressing any selected row segment starts a grouped drag")
	board._update_structure_drag(row_drag_start + Vector2.DOWN * board.cell_size * 2.0)
	_assert(board.structure_drag_drop_valid, "a clear grouped destination previews as valid")
	_assert(board.get_structure(&"row_wall_0").grid_cell == Vector2i(18, 18), "row drag does not mutate logical cells before release")
	board._finish_structure_drag(row_drag_start + Vector2.DOWN * board.cell_size * 2.0)
	_assert(board.get_structure(&"row_wall_0").grid_cell == Vector2i(18, 20) and board.get_structure(&"row_wall_4").grid_cell == Vector2i(22, 20), "releasing moves the whole selected row together")
	_assert(board.rotate_selected_wall_row(), "Rotate Row succeeds when every rotated cell is clear")
	_assert(board.get_structure(&"row_wall_0").grid_cell == Vector2i(20, 18) and board.get_structure(&"row_wall_4").grid_cell == Vector2i(20, 22), "Rotate Row turns the group ninety degrees around the selected wall")
	_assert(board.get_structure(&"row_wall_1").level == 2, "moving and rotating a row preserves each wall's level")
	_assert(board.try_add_structure(&"cannon", Vector2i(16, 19), 1), "the collision fixture can be placed beside the vertical row")
	board.select_structure(board.get_structure(&"row_wall_2"))
	_assert(board.select_wall_row(), "the moved row remains selectable")
	var before_blocked_rotation: Array[Dictionary] = board.capture_current_blueprint()
	_assert(not board.rotate_selected_wall_row(), "Rotate Row rejects a destination occupied by another building")
	_assert(board.capture_current_blueprint() == before_blocked_rotation, "a rejected rotation leaves every wall unchanged")

	board.clear_selection()
	_assert(board.get_wall_extension_cells().is_empty(), "deselecting a wall removes its extension controls")

	board.queue_free()
	if failure_count > 0:
		quit(1)
		return
	print("SIEGE_UI_CONTROLS_SMOKE_OK")
	quit(0)


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Siege UI controls smoke failed: %s" % description)
	failure_count += 1
