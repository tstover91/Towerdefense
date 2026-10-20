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
	var cannon_center: Vector2 = board.cell_rect(cannon.grid_cell).get_center()
	_assert(board._begin_structure_drag_candidate_at(cannon_center), "the selected building can begin a direct drag")
	var cannon_origin: Vector2i = cannon.grid_cell
	var invalid_drop_position: Vector2 = board.board_origin + Vector2(0.5, 5.5) * board.cell_size
	board._update_structure_drag(invalid_drop_position)
	_assert(cannon.grid_cell == cannon_origin, "dragging keeps the saved grid layout unchanged until release")
	_assert(not board.structure_drag_drop_valid, "the snapped footprint marks a blocked destination invalid")
	board._finish_structure_drag(invalid_drop_position)
	_assert(cannon.grid_cell == cannon_origin, "an invalid release returns the building to its original cell")

	var simple_blueprint: Array[Dictionary] = [
		{"id": &"wall_test", "kind": &"wall", "level": 1, "cell": Vector2i(20, 20), "footprint": Vector2i.ONE},
	]
	board.load_blueprint(simple_blueprint)
	var wall: Node2D = board.get_structure(&"wall_test")
	board.select_structure(wall)
	_assert(board.pending_build_kind == &"", "selecting a wall does not silently begin a purchase")
	_assert(board.get_wall_extension_cells().size() == 4, "a selected isolated wall exposes all four valid extension directions")

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
